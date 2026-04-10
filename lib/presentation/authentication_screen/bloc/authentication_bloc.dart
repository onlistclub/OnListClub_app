import 'dart:math';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../models/authentication_model.dart';
import '../../../core/app_export.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/user_profile_manager.dart';
import '../../../../main.dart' show googleWebClientId;

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
    on<GoogleSignInEvent>(_onGoogleSignIn);
    on<AppleSignInEvent>(_onAppleSignIn);
  }

  String _generateNonce([int length = 32]) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _handlePostOAuthLogin(Emitter<AuthenticationState> emit) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      emit(state.copyWith(isLoading: false, errorMessage: 'Login fallito'));
      return;
    }

    // NON chiamiamo ensureProfileExists() qui: nel flusso OAuth la riga in
    // public.utenti viene creata solo DOPO che l'utente completa il form.
    final profileComplete = await UserProfileManager().isProfileComplete();
    if (profileComplete) {
      // Profilo già completo: accedi direttamente
      emit(state.copyWith(isLoading: false, isLoginSuccess: true));
    } else {
      // Prima volta con OAuth (o profilo incompleto): pre-compila nome/cognome/email
      final metadata = user.userMetadata ?? {};
      final fullName = metadata['full_name'] as String? ?? metadata['name'] as String?;
      String? nome;
      String? cognome;
      if (fullName != null && fullName.contains(' ')) {
        final parts = fullName.split(' ');
        nome = parts.first;
        cognome = parts.sublist(1).join(' ');
      } else {
        nome = fullName;
      }
      emit(state.copyWith(
        isLoading: false,
        needsProfileCompletion: true,
        oauthNome: nome,
        oauthCognome: cognome,
        oauthEmail: user.email,
      ));
    }
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

  _onGoogleSignIn(
    GoogleSignInEvent event,
    Emitter<AuthenticationState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      // serverClientId è il Web Client ID di Google Cloud Console (type 3).
      // È obbligatorio affinché Supabase possa verificare l'idToken ricevuto.
      // Configurare GOOGLE_WEB_CLIENT_ID in env.json seguendo docs/oauth_google_setup.md.
      final googleSignIn = GoogleSignIn(
        serverClientId: googleWebClientId,
      );
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        // L'utente ha annullato il popup di selezione account
        emit(state.copyWith(isLoading: false));
        return;
      }
      final auth = await googleUser.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        emit(state.copyWith(
          isLoading: false,
          errorMessage: 'Google login fallito: idToken assente. Verificare Web Client ID in env.json.',
        ));
        return;
      }
      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: auth.accessToken,
      );
      await _handlePostOAuthLogin(emit);
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: e is AuthException ? e.message : 'Google login fallito',
      ));
    }
  }

  _onAppleSignIn(
    AppleSignInEvent event,
    Emitter<AuthenticationState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      final rawNonce = _generateNonce();
      final hashedNonce = _sha256ofString(rawNonce);
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );
      final idToken = credential.identityToken;
      if (idToken == null) {
        emit(state.copyWith(isLoading: false, errorMessage: 'Apple login fallito'));
        return;
      }
      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );
      await _handlePostOAuthLogin(emit);
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: e is AuthException ? e.message : 'Apple login fallito',
      ));
    }
  }
}
