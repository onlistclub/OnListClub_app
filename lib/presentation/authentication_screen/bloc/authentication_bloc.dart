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
import '../../../core/services/register_service.dart';
import '../../../core/services/analytics_service.dart';
// La config Google (client/server ID) è applicata una volta in main.dart via
// GoogleSignIn.instance.initialize(): qui basta chiamare authenticate().

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

    // Se il profilo è già completo (utente che si ri-logga), nulla da fare.
    final profileComplete = await UserProfileManager().isProfileComplete();
    if (profileComplete) {
      emit(state.copyWith(isLoading: false, isLoginSuccess: true));
      return;
    }

    // Estraiamo TUTTI i campi disponibili dai metadata dell'identità OAuth.
    // Google passa quasi sempre nome/cognome/email; telefono e data di nascita
    // arrivano solo con scope People API extra (non garantiti). Apple non
    // passa mai telefono né data di nascita.
    final metadata = user.userMetadata ?? {};
    String? nome = metadata['given_name'] as String? ??
        metadata['first_name'] as String?;
    String? cognome = metadata['family_name'] as String? ??
        metadata['last_name'] as String?;
    if (nome == null || cognome == null) {
      final fullName = metadata['full_name'] as String? ??
          metadata['name'] as String?;
      if (fullName != null && fullName.contains(' ')) {
        final parts = fullName.split(' ');
        nome ??= parts.first;
        cognome ??= parts.sublist(1).join(' ');
      } else {
        nome ??= fullName;
      }
    }
    final telefono = (metadata['phone'] as String?) ??
        (metadata['phone_number'] as String?) ??
        user.phone;
    final birthdayStr = metadata['birthday'] as String? ??
        metadata['birthdate'] as String? ??
        metadata['data_nascita'] as String?;
    final dataNascita = birthdayStr != null
        ? DateTime.tryParse(birthdayStr)
        : null;

    final hasAll = (nome != null && nome.trim().isNotEmpty) &&
        (cognome != null && cognome.trim().isNotEmpty) &&
        (telefono != null && telefono.trim().isNotEmpty) &&
        dataNascita != null;

    if (hasAll) {
      // Caso ideale (raro con Google/Apple): scriviamo subito il profilo via
      // RPC atomica e proseguiamo come login normale (location/city).
      try {
        await RegisterService().registerAtomic(
          userId: user.id,
          email: user.email ?? '',
          // Niente `!`: dentro questo ramo `hasAll` ha già promosso i tre
          // campi a non-null, e l'analyzer segnalava le asserzioni come inutili.
          nome: nome,
          cognome: cognome,
          dataNascita: dataNascita,
          telefono: telefono,
          countryIso: null,
        );
        emit(state.copyWith(isLoading: false, isLoginSuccess: true));
      } catch (e) {
        debugPrint('[AuthBloc] OAuth auto-register fallito: $e');
        // Fallback: vai al form di registrazione con i dati pre-compilati.
        emit(state.copyWith(
          isLoading: false,
          needsProfileCompletion: true,
          oauthNome: nome,
          oauthCognome: cognome,
          oauthEmail: user.email,
          oauthTelefono: telefono,
          oauthDataNascita: dataNascita,
        ));
      }
      return;
    }

    // Manca qualcosa: vai al form di registrazione coi campi noti pre-riempiti.
    // L'email viene anche dall'identità OAuth ed è già verificata, quindi al
    // submit NON mostriamo la schermata di verifica.
    emit(state.copyWith(
      isLoading: false,
      needsProfileCompletion: true,
      oauthNome: nome,
      oauthCognome: cognome,
      oauthEmail: user.email,
      oauthTelefono: telefono,
      oauthDataNascita: dataNascita,
    ));
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

      await client.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: 'https://www.onlistclub.com/auth/email-confirmed',
      );

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
      final googleSignIn = GoogleSignIn.instance;
      // L'inizializzazione (client/server ID) avviene una volta in main.dart.
      // authenticate() apre il foglio nativo di selezione account.
      if (!googleSignIn.supportsAuthenticate()) {
        debugPrint(
            '[AuthBloc] Google sign-in: authenticate() non supportato su questa piattaforma');
        emit(state.copyWith(
          isLoading: false,
          errorMessage:
              'Accesso con Google non disponibile su questa piattaforma.',
        ));
        return;
      }

      final account =
          await googleSignIn.authenticate(scopeHint: const ['email', 'profile']);
      // Nella 7.x `authentication` espone solo l'idToken (niente accessToken).
      // A Supabase basta l'idToken: non passando più alcun nonce, l'idToken
      // nativo non genera il mismatch che bloccava il login su iOS.
      final idToken = account.authentication.idToken;
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
      );
      await _handlePostOAuthLogin(emit);
    } on GoogleSignInException catch (e) {
      // canceled = l'utente ha chiuso il foglio: nessun errore da mostrare.
      if (e.code == GoogleSignInExceptionCode.canceled) {
        debugPrint('[AuthBloc] Google sign-in annullato dall\'utente');
        emit(state.copyWith(isLoading: false));
        return;
      }
      debugPrint(
          '[AuthBloc] Google sign-in - GoogleSignInException: code=${e.code.name} desc=${e.description}');
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Google login fallito (${e.code.name}).',
      ));
    } on AuthException catch (e) {
      AnalyticsService.reportError(e, screen: 'authentication');
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
      AnalyticsService.reportError(e, screen: 'authentication');
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
