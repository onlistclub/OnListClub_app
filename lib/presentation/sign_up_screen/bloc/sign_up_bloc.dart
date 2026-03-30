import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/sign_up_model.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../core/services/register_service.dart';
import '../../../core/utils/age_calculator.dart';
// phone_numbers_parser non usato nel flusso ripristinato

part 'sign_up_event.dart';
part 'sign_up_state.dart';

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
    final normalized = PhoneUtils.normalize(
      countryIso: event.countryIso,
      nationalNumber: event.nationalNumber,
      completeNumber: event.phone,
    );
    final nnDigits = (event.nationalNumber ?? '').replaceAll(RegExp(r'\D'), '');
    emit(state.copyWith(
      signUpModel: state.signUpModel?.copyWith(
        phone: normalized,
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
        final isAdult = AgeCalculator.isAdult(dob);
        try {
          debugPrint('[SignUpBloc] iso=$iso nn_raw=${model.nationalNumber}');
          final cleaned = nn.replaceAll(RegExp(r'\D'), '');
          final countryId = await RegisterService().resolveCountryIdFromIso(iso);
          debugPrint('[SignUpBloc] country_id=$countryId nn_clean=$cleaned');
          await Supabase.instance.client.from('utenti').upsert({
            'id': user.id,
            'nome': model.firstName,
            'cognome': model.lastName,
            'email': model.email,
            'data_nascita': dob.toIso8601String(),
            'maggiorenne': isAdult,
          });
          await Supabase.instance.client.from('utenti_numeri_telefono').upsert({
            'user_id': user.id,
            'country_id': countryId,
            'telefono': cleaned,
            'is_primary': true,
            'is_verified': false,
          }, onConflict: 'user_id,telefono');
          debugPrint('[SignUpBloc] utenti_numeri_telefono upserted payload: {user_id:${user.id}, country_id:$countryId, telefono:$cleaned}');
          emit(state.copyWith(isLoading: false, isSuccess: true));
        } catch (e) {
          debugPrint('[SignUpBloc] Insert error: $e');
          emit(state.copyWith(isLoading: false, errorMessage: 'Errore salvataggio telefono: $e'));
          return;
        }
        // Check if session is null, which usually implies email confirmation is required
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
}
