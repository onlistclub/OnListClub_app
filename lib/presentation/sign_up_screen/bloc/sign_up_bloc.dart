import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/sign_up_model.dart';
import 'package:intl/intl.dart';
import '../../../core/services/register_service.dart';

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
  SignUpBloc(SignUpState initialState) : super(initialState) {
    on<SignUpInitialEvent>(_onInitialize);
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

      final response = await client.auth.signUp(
        email: model.email,
        password: model.password,
        data: {
          'nome': model.firstName,
          'cognome': model.lastName,
          'data_nascita': model.dob?.toIso8601String(),
          'telefono': model.phone,
          'phone_country_iso': model.phoneCountryIso,
        },
      );
      
      if (response.user != null) {
        final user = response.user!;
        final iso = model.phoneCountryIso ?? 'IT';
        final nn = model.nationalNumber;
        final dob = model.dob;
        if (nn.isEmpty || dob == null) {
          emit(state.copyWith(isLoading: false, errorMessage: 'Dati telefono/paese mancanti'));
          return;
        }
        try {
          // Scrittura atomica di utente + telefono (E.164) in un'unica transazione
          // via RPC SECURITY DEFINER: niente righe orfane e maggiorenne calcolato
          // lato DB.
          await RegisterService().registerAtomic(
            userId: user.id,
            email: model.email,
            nome: model.firstName,
            cognome: model.lastName,
            dataNascita: dob,
            telefono: model.phone,
            countryIso: iso,
          );
          emit(state.copyWith(isLoading: false, isSuccess: true));
        } catch (e) {
          debugPrint('[SignUpBloc] registerAtomic error: $e');
          emit(state.copyWith(isLoading: false, errorMessage: 'Errore salvataggio telefono: $e'));
          return;
        }
        // La navigazione è gestita da isSuccess
      } else {
         // Should throw error if failed usually, but just in case
         emit(state.copyWith(isLoading: false, errorMessage: "Registration failed"));
      }

    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: e is AuthException ? e.message : 'Registration failed: $e',
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
