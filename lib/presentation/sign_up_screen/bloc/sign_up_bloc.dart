import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/sign_up_model.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../core/services/register_service.dart';
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
      signUpModel: SignUpModel(),
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
    emit(state.copyWith(
      signUpModel: state.signUpModel?.copyWith(
        phone: normalized,
        phoneCountryIso: event.countryIso,
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
        // Persistenza su tabelle pubbliche avverrà post-verifica al primo login (ripristino modello precedente)
        // Qui navighiamo alla schermata di verifica
        // Check if session is null, which usually implies email confirmation is required
        if (response.session == null) {
             emit(state.copyWith(
               isLoading: false, 
               isSuccess: true // Trigger navigation
             ));
        } else {
             emit(state.copyWith(isLoading: false, isSuccess: true));
        }
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
