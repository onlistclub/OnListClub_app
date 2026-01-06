import 'package:flutter/material.dart';
import '../models/authentication_model.dart';
import '../../../core/app_export.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/user_profile_manager.dart';

part 'authentication_event.dart';
part 'authentication_state.dart';

class AuthenticationBloc
    extends Bloc<AuthenticationEvent, AuthenticationState> {
  AuthenticationBloc(AuthenticationState initialState) : super(initialState) {
    on<AuthenticationInitialEvent>(_onInitialize);
    on<EmailChangedEvent>(_onEmailChanged);
    on<PasswordChangedEvent>(_onPasswordChanged);
    on<LoginButtonPressedEvent>(_onLoginButtonPressed);
    on<RegisterButtonPressedEvent>(_onRegisterButtonPressed);
  }

  _onInitialize(
    AuthenticationInitialEvent event,
    Emitter<AuthenticationState> emit,
  ) async {
    emit(state.copyWith(
      emailController: TextEditingController(),
      passwordController: TextEditingController(),
      formKey: GlobalKey<FormState>(),
      isLoading: false,
    ));
  }

  _onEmailChanged(
    EmailChangedEvent event,
    Emitter<AuthenticationState> emit,
  ) async {
    emit(state.copyWith(
      authenticationModel: state.authenticationModel?.copyWith(
        email: event.email,
      ),
    ));
  }

  _onPasswordChanged(
    PasswordChangedEvent event,
    Emitter<AuthenticationState> emit,
  ) async {
    emit(state.copyWith(
      authenticationModel: state.authenticationModel?.copyWith(
        password: event.password,
      ),
    ));
  }

  _onLoginButtonPressed(
    LoginButtonPressedEvent event,
    Emitter<AuthenticationState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));

    try {
      final email = state.authenticationModel?.email ?? '';
      final password = state.authenticationModel?.password ?? '';
      final client = Supabase.instance.client;

      await client.auth.signInWithPassword(email: email, password: password);

      // Ensure profile exists in public.users table (post-verification check)
      await UserProfileManager().ensureProfileExists();

      emit(state.copyWith(isLoading: false, isLoginSuccess: true));

      state.emailController?.clear();
      state.passwordController?.clear();
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: e is AuthException ? e.message : 'Login fallito! Riprova di nuovo.',
      ));
    }
  }

  _onRegisterButtonPressed(
    RegisterButtonPressedEvent event,
    Emitter<AuthenticationState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));

    try {
      final email = state.authenticationModel?.email ?? '';
      final password = state.authenticationModel?.password ?? '';
      final client = Supabase.instance.client;

      await client.auth.signUp(email: email, password: password);

      emit(state.copyWith(isLoading: false, isRegisterSuccess: true));

      state.emailController?.clear();
      state.passwordController?.clear();
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: e is AuthException ? e.message : 'Registration failed. Please try again.',
      ));
    }
  }
}
