import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/sign_up_model.dart';
import '../../../core/services/register_service.dart';
import '../../../core/services/analytics_service.dart';
import 'package:intl/intl.dart';

part 'sign_up_event.dart';
part 'sign_up_state.dart';

/// BLoC della schermata di registrazione.
///
/// Gestisce lo stato del form (nome, cognome, email, data di nascita,
/// telefono, paese), valida l'input e al submit chiama `RegisterService`
/// che invoca la RPC `register_user_transaction` per scrivere in modo
/// atomico in `utenti` + `utenti_numeri_telefono`. Il telefono arriva già in
/// formato E.164 dal widget `InternationalPhoneNumberInput`.
class SignUpBloc extends Bloc<SignUpEvent, SignUpState> {
  /// Messaggi dei "paletti" di registrazione. Pubblici perché la UI li usa per
  /// distinguere il caso email-già-registrata (mostra l'azione "Accedi").
  static const String emailTakenMessage =
      'Questa email è già registrata. Accedi invece di registrarti.';
  static const String phoneTakenMessage =
      'Questo numero di telefono è già registrato.';

  SignUpBloc(SignUpState initialState) : super(initialState) {
    on<SignUpInitialEvent>(_onInitialize);
    on<SignUpPrefillEvent>(_onPrefill);
    on<FirstNameChangedEvent>(_onFirstNameChanged);
    on<LastNameChangedEvent>(_onLastNameChanged);
    on<EmailChangedEvent>(_onEmailChanged);
    on<PasswordChangedEvent>(_onPasswordChanged);
    on<ConfirmPasswordChangedEvent>(_onConfirmPasswordChanged);
    on<DobChangedEvent>(_onDobChanged);
    on<PhoneChangedEvent>(_onPhoneChanged);
    on<SubmitSignUpEvent>(_onSubmitSignUp);
  }

  _onInitialize(
    SignUpInitialEvent event,
    Emitter<SignUpState> emit,
  ) async {
    emit(state.copyWith(
      firstNameController: TextEditingController(),
      lastNameController: TextEditingController(),
      emailController: TextEditingController(),
      passwordController: TextEditingController(),
      confirmPasswordController: TextEditingController(),
      dobController: TextEditingController(),
      phoneController: TextEditingController(),
      formKey: GlobalKey<FormState>(),
      isLoading: false,
      isSuccess: false,
      signUpModel: SignUpModel(phoneCountryIso: 'IT'),
    ));
  }

  _onPrefill(
    SignUpPrefillEvent event,
    Emitter<SignUpState> emit,
  ) {
    // Scrive nei controller i dati ricevuti da Google/Apple (così sono già
    // visibili nel form) e li sincronizza nel SignUpModel. Lascia tutto
    // editabile dall'utente.
    if (event.nome != null) state.firstNameController?.text = event.nome!;
    if (event.cognome != null) state.lastNameController?.text = event.cognome!;
    if (event.email != null) state.emailController?.text = event.email!;
    if (event.dataNascita != null) {
      state.dobController?.text =
          DateFormat('dd/MM/yyyy').format(event.dataNascita!);
    }
    // NB: il telefono NON viene scritto nel controller perché OnlistPhoneField
    // gestisce solo cifre nazionali (no prefisso). L'E.164 OAuth è raro nella
    // pratica (Google solo con scope extra, Apple mai): se arriva lo salviamo
    // nel modello e l'utente lo conferma riscrivendo il numero. Quando il
    // widget emette i suoi onChanged, sovrascriverà comunque questa stringa.
    emit(state.copyWith(
      oauthVerified: event.oauthVerified,
      signUpModel: state.signUpModel?.copyWith(
        firstName: event.nome ?? state.signUpModel?.firstName,
        lastName: event.cognome ?? state.signUpModel?.lastName,
        email: event.email ?? state.signUpModel?.email,
        phone: event.telefono ?? state.signUpModel?.phone,
        dob: event.dataNascita ?? state.signUpModel?.dob,
      ),
    ));
  }

  _onFirstNameChanged(
    FirstNameChangedEvent event,
    Emitter<SignUpState> emit,
  ) {
    emit(state.copyWith(
      signUpModel: state.signUpModel?.copyWith(firstName: event.firstName),
    ));
  }

  _onLastNameChanged(
    LastNameChangedEvent event,
    Emitter<SignUpState> emit,
  ) {
    emit(state.copyWith(
      signUpModel: state.signUpModel?.copyWith(lastName: event.lastName),
    ));
  }

  _onEmailChanged(
    EmailChangedEvent event,
    Emitter<SignUpState> emit,
  ) {
    emit(state.copyWith(
      signUpModel: state.signUpModel?.copyWith(email: event.email),
    ));
  }

  _onPasswordChanged(
    PasswordChangedEvent event,
    Emitter<SignUpState> emit,
  ) {
    emit(state.copyWith(
      signUpModel: state.signUpModel?.copyWith(password: event.password),
    ));
  }

  _onConfirmPasswordChanged(
    ConfirmPasswordChangedEvent event,
    Emitter<SignUpState> emit,
  ) {
    emit(state.copyWith(
      signUpModel: state.signUpModel?.copyWith(confirmPassword: event.confirmPassword),
    ));
  }

  _onDobChanged(
    DobChangedEvent event,
    Emitter<SignUpState> emit,
  ) {
    final formattedDate = DateFormat('dd/MM/yyyy').format(event.dob);
    state.dobController?.text = formattedDate;
    emit(state.copyWith(
      signUpModel: state.signUpModel?.copyWith(dob: event.dob),
    ));
  }

  _onPhoneChanged(
    PhoneChangedEvent event,
    Emitter<SignUpState> emit,
  ) {
    // Il widget InternationalPhoneNumberInput fornisce già il numero completo in
    // formato E.164 (es. "+393331234567"). Lo salviamo così com'è; nationalNumber
    // serve solo a validare che l'utente abbia digitato delle cifre.
    final e164 = event.phone.replaceAll(' ', '');
    final nnDigits = (event.nationalNumber ?? '').replaceAll(RegExp(r'\D'), '');
    emit(state.copyWith(
      signUpModel: state.signUpModel?.copyWith(
        phone: e164,
        phoneCountryIso: event.countryIso ?? state.signUpModel?.phoneCountryIso,
        nationalNumber: nnDigits,
      ),
    ));
  }

  _onSubmitSignUp(
    SubmitSignUpEvent event,
    Emitter<SignUpState> emit,
  ) async {
    // Basic validation check
    if (state.formKey?.currentState?.validate() != true) {
      return;
    }
    emit(state.copyWith(isLoading: true, errorMessage: null));

    try {
      final model = state.signUpModel;
      if (model == null) return;

      // ── Branch OAuth (Google/Apple) ───────────────────────────────────────
      // L'utente è già autenticato (signInWithIdToken già avvenuto) e l'email
      // è già verificata dal provider: non rifacciamo signUp, scriviamo solo
      // il profilo via RPC atomica e usciamo. La password non è richiesta.
      if (state.oauthVerified) {
        final client = Supabase.instance.client;
        final user = client.auth.currentUser;
        if (user == null) {
          emit(state.copyWith(
            isLoading: false,
            errorMessage: 'Sessione scaduta, riprova ad accedere.',
          ));
          return;
        }
        if (model.dob == null) {
          emit(state.copyWith(
            isLoading: false,
            errorMessage: 'Inserisci la data di nascita',
          ));
          return;
        }
        try {
          await RegisterService().registerAtomic(
            userId: user.id,
            email: user.email ?? model.email,
            nome: model.firstName,
            cognome: model.lastName,
            dataNascita: model.dob!,
            telefono: model.phone,
            countryIso: model.phoneCountryIso,
          );
          emit(state.copyWith(isLoading: false, isSuccess: true));
        } on PostgrestException catch (e) {
          AnalyticsService.reportError(e, screen: 'sign_up');
          // Telefono già usato da un altro account, ecc.
          final msg = e.message.toLowerCase();
          if (msg.contains('phone') || msg.contains('telefono')) {
            emit(state.copyWith(
                isLoading: false, errorMessage: phoneTakenMessage));
          } else {
            emit(state.copyWith(isLoading: false, errorMessage: e.message));
          }
        } catch (e) {
          emit(state.copyWith(
            isLoading: false,
            errorMessage: 'Registrazione fallita: $e',
          ));
        }
        return;
      }

      // Guard di sicurezza: il form valida già la password (min 8 caratteri),
      // ma il BLoC non si affida solo alla UI. Non esiste un campo di conferma
      // password in questa schermata, quindi qui verifichiamo solo che la
      // password sia presente.
      if (model.password.isEmpty) {
        emit(state.copyWith(
          isLoading: false,
          errorMessage: 'Inserisci una password',
        ));
        return;
      }

      final client = Supabase.instance.client;

      // Paletti: blocca subito se email o telefono risultano già registrati,
      // con messaggio chiaro. La rete di sicurezza finale contro le race
      // condition resta nei vincoli UNIQUE del DB (gestiti nei catch sotto).
      // Fail-open: se la RPC non esiste ancora o fallisce, non blocchiamo la
      // registrazione e lasciamo decidere ai vincoli DB.
      try {
        final avail = await client.rpc(
          'check_registration_availability',
          params: {'p_email': model.email, 'p_phone': model.phone},
        ) as Map<String, dynamic>?;
        if (avail != null) {
          if (avail['email_taken'] == true) {
            emit(state.copyWith(
                isLoading: false, errorMessage: emailTakenMessage));
            return;
          }
          if (avail['phone_taken'] == true) {
            emit(state.copyWith(
                isLoading: false, errorMessage: phoneTakenMessage));
            return;
          }
        }
      } catch (e) {
        debugPrint('[SignUpBloc] check_registration_availability skip: $e');
      }

      final response = await client.auth.signUp(
        email: model.email,
        password: model.password,
        // Pagina di benvenuto sul sito dopo la conferma email: invita l'utente
        // a tornare in app via deep link. URL whitelistato in
        // Supabase Dashboard → Authentication → URL Configuration.
        emailRedirectTo: 'https://www.onlistclub.com/auth/email-confirmed',
        data: {
          'nome': model.firstName,
          'cognome': model.lastName,
          'data_nascita': model.dob?.toIso8601String(),
          'telefono': model.phone,
          'phone_country_iso': model.phoneCountryIso,
        },
      );
      
      if (response.user != null) {
        // Con "Confirm email" attivo, signUp NON apre una sessione: `auth.uid()`
        // è ancora null. Quindi qui NON scriviamo il profilo — la RPC
        // `register_user_transaction` fallirebbe con la guardia di sicurezza
        // ("Forbidden: caller is not the target user", 42501). I dati anagrafici
        // e il telefono viaggiano nei metadata di `auth.users` (campo `data:`
        // sopra) e vengono scritti DOPO la conferma email da
        // `UserProfileManager.ensureProfileExists()`, chiamato dal verificationBloc
        // al primo login con sessione valida.
        emit(state.copyWith(isLoading: false, isSuccess: true));
        // La navigazione alla schermata di verifica è gestita da isSuccess.
      } else {
         // Should throw error if failed usually, but just in case
         emit(state.copyWith(isLoading: false, errorMessage: "Registration failed"));
      }

    } on AuthException catch (e) {
      AnalyticsService.reportError(e, screen: 'sign_up');
      // Supabase può rispondere "User already registered" se l'email esiste già
      // in auth.users: lo mappiamo sul messaggio amichevole con azione "Accedi".
      final msg = e.message.toLowerCase();
      final alreadyRegistered =
          msg.contains('already registered') || msg.contains('already exists');
      emit(state.copyWith(
        isLoading: false,
        errorMessage: alreadyRegistered ? emailTakenMessage : e.message,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Registration failed: $e',
      ));
    }
  }

  @override
  Future<void> close() {
    state.firstNameController?.dispose();
    state.lastNameController?.dispose();
    state.emailController?.dispose();
    state.passwordController?.dispose();
    state.confirmPasswordController?.dispose();
    state.dobController?.dispose();
    state.phoneController?.dispose();
    return super.close();
  }
}
