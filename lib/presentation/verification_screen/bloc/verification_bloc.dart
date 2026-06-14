import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../../../core/services/user_profile_manager.dart';

part 'verification_event.dart';
part 'verification_state.dart';

/// BLoC della schermata di verifica email.
///
/// Con "Confirm email" attivo, dopo la registrazione la sessione Supabase è
/// `null` finché l'utente non clicca il link nell'email. Il link si apre nel
/// browser e conferma lato server: senza un deep-link di ritorno l'app non
/// riceve alcun evento, quindi NON ci si può affidare a `onAuthStateChange`.
/// L'unico modo lato client di accorgersi della conferma è ritentare
/// periodicamente `signInWithPassword`: finché non confermata torna
/// "Email not confirmed"; appena confermata restituisce la sessione e si
/// prosegue automaticamente alla schermata successiva.
///
/// Il polling (ogni 3s) è SILENZIOSO: niente spinner né dialog, così l'utente
/// vede solo l'istruzione "controlla la tua email". Il bottone "Ho confermato"
/// resta come fallback manuale, con feedback.
///
/// La scadenza/validità del link è configurata su Supabase Dashboard, NON qui.
///
/// Nota: il nome `verificationBloc` (minuscolo) è un anti-pattern Dart —
/// dovrebbe essere `VerificationBloc`. Non rinominato qui per non rompere
/// le import esistenti; refactor da pianificare.
class verificationBloc extends Bloc<verificationEvent, verificationState> {
  Timer? _timer;

  /// Intervallo di polling. ~3s come richiesto; alzabile (4-5s) se si
  /// incontrano rate limit sull'endpoint /token.
  static const Duration _pollInterval = Duration(seconds: 3);

  verificationBloc(verificationState initialState) : super(initialState) {
    on<verificationInitialEvent>(_onInitialize);
    on<PollVerificationEvent>(_onPollVerification);
    on<CheckVerificationEvent>(_onCheckVerification);
    on<ResendEmailEvent>(_onResendEmail);
  }

  Future<void> _onInitialize(
    verificationInitialEvent event,
    Emitter<verificationState> emit,
  ) async {
    emit(state.copyWith(
      registrationTime: event.registrationTime,
      email: event.email,
      password: event.password,
    ));

    _startPolling();
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(_pollInterval, (timer) {
      if (isClosed) {
        timer.cancel();
        return;
      }
      add(PollVerificationEvent());
    });
  }

  /// Polling silenzioso: nessun effetto su `isLoading`, nessun dialog di errore.
  /// Avanza solo quando la conferma è effettivamente avvenuta.
  Future<void> _onPollVerification(
    PollVerificationEvent event,
    Emitter<verificationState> emit,
  ) async {
    if (state.isVerified) return;
    final email = state.email;
    final password = state.password;
    if (email == null || password == null) return;

    try {
      final client = Supabase.instance.client;
      final response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.session != null) {
        _timer?.cancel();
        debugPrint('[verificationBloc] Email confermata (polling). Accesso ok.');
        try {
          await UserProfileManager().ensureProfileExists();
        } catch (e) {
          debugPrint('[verificationBloc] ensureProfileExists error: $e');
        }
        emit(state.copyWith(isVerified: true));
      }
    } on AuthException catch (e) {
      // Tipicamente "Email not confirmed": resta in attesa, nessun errore in UI.
      debugPrint('[verificationBloc] poll (in attesa): ${e.message}');
    } catch (e) {
      debugPrint('[verificationBloc] poll error: $e');
    }
  }

  Future<void> _onResendEmail(
    ResendEmailEvent event,
    Emitter<verificationState> emit,
  ) async {
    if (state.email == null) return;

    emit(state.copyWith(isLoading: true, errorMessage: null, emailResentMessage: null));

    try {
      final client = Supabase.instance.client;
      // Nota: il resend funziona solo se non ancora verificata.
      // Si applicano rate limit (di norma una volta al minuto).
      await client.auth.resend(
        type: OtpType.signup,
        email: state.email,
      );

      emit(state.copyWith(
        isLoading: false,
        emailResentMessage: "Email inviata con successo! Controlla la tua casella.",
      ));
    } on AuthException catch (e) {
      debugPrint('[verificationBloc] Resend failed: ${e.message}');
      emit(state.copyWith(
        isLoading: false,
        errorMessage: "Errore invio email: ${e.message}",
      ));
    } catch (e) {
      debugPrint('[verificationBloc] Resend error: $e');
      emit(state.copyWith(
        isLoading: false,
        errorMessage: "Si è verificato un errore imprevisto.",
      ));
    }
  }

  /// Controllo manuale (bottone): con feedback. Utile come fallback se il
  /// polling non ha ancora intercettato la conferma.
  Future<void> _onCheckVerification(
    CheckVerificationEvent event,
    Emitter<verificationState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, errorMessage: null));

    try {
      final client = Supabase.instance.client;
      final email = state.email;
      final password = state.password;

      debugPrint('[verificationBloc] Verifying email for: $email');

      if (email == null || password == null) {
        emit(state.copyWith(
            isLoading: false, errorMessage: "Credenziali mancanti."));
        return;
      }

      final response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null && response.session != null) {
        _timer?.cancel();
        debugPrint('[verificationBloc] Verification successful. User logged in.');

        await UserProfileManager().ensureProfileExists();

        emit(state.copyWith(isLoading: false, isVerified: true));
      } else {
        debugPrint('[verificationBloc] Login success but no session? Unusual.');
        emit(state.copyWith(isLoading: false, isVerified: true));
      }
    } on AuthException catch (e) {
      debugPrint('[verificationBloc] Login failed: ${e.message}');
      if (e.message.toLowerCase().contains('email not confirmed') ||
          e.message.toLowerCase().contains('login failed')) {
        emit(state.copyWith(
          isLoading: false,
          errorMessage: "Verifica prima l'email",
        ));
      } else {
        emit(state.copyWith(
          isLoading: false,
          errorMessage: e.message,
        ));
      }
    } catch (e) {
      debugPrint('[verificationBloc] Unexpected error: $e');
      emit(state.copyWith(
        isLoading: false,
        errorMessage: "Errore durante la verifica: $e",
      ));
    }
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
