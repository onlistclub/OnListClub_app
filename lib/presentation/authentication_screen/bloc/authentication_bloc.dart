import 'dart:io' show Platform;
import 'dart:math';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../models/authentication_model.dart';
import '../../../core/app_export.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/user_profile_manager.dart';
import '../../../../main.dart' show googleWebClientId, googleIosClientId;

part 'authentication_event.dart';
part 'authentication_state.dart';

/// BLoC della schermata di login.
///
/// Orchestra i tre flussi di autenticazione (email/password, Google, Apple)
/// e l'esito post-login: chiama `UserProfileManager.ensureProfileExists()`
/// per garantire la riga in `public.utenti`, poi emette lo state che la UI
/// usa per navigare. Dipende dal client Supabase, da `google_sign_in`,
/// `sign_in_with_apple` e dal `googleWebClientId` letto da `main.dart`.
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
      // GUARD iOS: l'SDK nativo GoogleSignIn richiede un Client ID di tipo iOS.
      // Se manca, `signIn()` solleva un'eccezione nativa fatale PRIMA che questo
      // try/catch possa intercettarla → crash dell'app. Blocchiamo qui con un
      // errore gestito finché GOOGLE_IOS_CLIENT_ID + URL scheme non sono configurati.
      if (Platform.isIOS &&
          (googleIosClientId == null || googleIosClientId!.isEmpty)) {
        debugPrint(
            '[AuthBloc] Google sign-in iOS: iOS Client ID mancante — abort per evitare crash nativo');
        emit(state.copyWith(
          isLoading: false,
          errorMessage:
              'Accesso con Google non ancora disponibile su iOS. Usa email o Apple.',
        ));
        return;
      }

      // serverClientId è il Web Client ID di Google Cloud Console (type 3).
      // È obbligatorio affinché Supabase possa verificare l'idToken ricevuto.
      // clientId (iOS) è richiesto solo su iOS; su Android deve restare null.
      // Configurabili via --dart-define=GOOGLE_WEB_CLIENT_ID / GOOGLE_IOS_CLIENT_ID.
      final googleSignIn = GoogleSignIn(
        clientId: Platform.isIOS ? googleIosClientId : null,
        serverClientId: googleWebClientId,
      );
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        // L'utente ha annullato il popup di selezione account.
        debugPrint('[AuthBloc] Google sign-in annullato dall\'utente');
        emit(state.copyWith(isLoading: false));
        return;
      }
      final auth = await googleUser.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        debugPrint(
            '[AuthBloc] Google sign-in: idToken assente (configurazione Web Client ID errata?)');
        emit(state.copyWith(
          isLoading: false,
          errorMessage:
              'Google login fallito: configurazione client mancante.',
        ));
        return;
      }
      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: auth.accessToken,
      );
      await _handlePostOAuthLogin(emit);
    } on AuthException catch (e) {
      debugPrint('[AuthBloc] Google sign-in - AuthException: ${e.message}');
      emit(state.copyWith(isLoading: false, errorMessage: e.message));
    } catch (e) {
      debugPrint('[AuthBloc] Google sign-in - errore inatteso: $e');
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Google login fallito. Riprova.',
      ));
    }
  }

  _onAppleSignIn(
    AppleSignInEvent event,
    Emitter<AuthenticationState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      // rawNonce viene generato qui e l'hash sha256 viene inviato ad Apple.
      // Supabase verifica server-side che l'hash del rawNonce passato coincida
      // con il nonce dentro l'idToken: questo previene replay attack.
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
        debugPrint('[AuthBloc] Apple sign-in: identityToken assente');
        emit(state.copyWith(
            isLoading: false,
            errorMessage: 'Apple login fallito: token non ricevuto.'));
        return;
      }
      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );
      await _handlePostOAuthLogin(emit);
    } on SignInWithAppleAuthorizationException catch (e) {
      // Codici: canceled, failed, invalidResponse, notHandled, unknown.
      debugPrint(
          '[AuthBloc] Apple sign-in - SignInWithAppleAuthorizationException: code=${e.code} msg=${e.message}');
      if (e.code == AuthorizationErrorCode.canceled) {
        emit(state.copyWith(isLoading: false));
      } else {
        emit(state.copyWith(
          isLoading: false,
          errorMessage: 'Apple login fallito (${e.code.name}).',
        ));
      }
    } on AuthException catch (e) {
      debugPrint('[AuthBloc] Apple sign-in - AuthException: ${e.message}');
      emit(state.copyWith(isLoading: false, errorMessage: e.message));
    } catch (e) {
      debugPrint('[AuthBloc] Apple sign-in - errore inatteso: $e');
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Apple login fallito. Riprova.',
      ));
    }
  }

  @override
  Future<void> close() {
    state.emailController?.dispose();
    state.passwordController?.dispose();
    return super.close();
  }
}
