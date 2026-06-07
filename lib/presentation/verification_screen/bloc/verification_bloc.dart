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
/// Mantiene il timer di countdown per il pulsante "Invia di nuovo" e
/// controlla periodicamente se la sessione Supabase ha un `email_confirmed_at`
/// valorizzato (segno che l'utente ha cliccato il link nell'email). Quando la
/// verifica passa, chiama `UserProfileManager` per finalizzare il profilo.
///
/// Nota: il nome `verificationBloc` (minuscolo) è un anti-pattern Dart —
/// dovrebbe essere `VerificationBloc`. Non rinominato qui per non rompere
/// le import esistenti; refactor da pianificare.
class verificationBloc extends Bloc<verificationEvent, verificationState> {
  Timer? _timer;

  verificationBloc(verificationState initialState) : super(initialState) {
    on<verificationInitialEvent>(_onInitialize);
    on<CheckVerificationEvent>(_onCheckVerification);
    on<ResendEmailEvent>(_onResendEmail);
    on<TimerTickEvent>(_onTimerTick);
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

    _startTimer(event.registrationTime);
  }

  void _startTimer(DateTime registrationTime) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (isClosed) {
        timer.cancel();
        return;
      }
      final now = DateTime.now();
      final deadline = registrationTime.add(const Duration(hours: 4));
      final remaining = deadline.difference(now);

      if (remaining.isNegative) {
        timer.cancel();
        add(const TimerTickEvent(Duration.zero));
      } else {
        add(TimerTickEvent(remaining));
      }
    });
  }

  void _onTimerTick(TimerTickEvent event, Emitter<verificationState> emit) {
    if (event.remainingTime == Duration.zero) {
      emit(state.copyWith(remainingTime: Duration.zero, isExpired: true));
      debugPrint('[verificationBloc] Timer expired. Token invalidated.');
    } else {
      emit(state.copyWith(remainingTime: event.remainingTime));
    }
  }

  Future<void> _onResendEmail(
    ResendEmailEvent event,
    Emitter<verificationState> emit,
  ) async {
    if (state.isExpired) return;
    if (state.email == null) return;

    emit(state.copyWith(isLoading: true, errorMessage: null, emailResentMessage: null));

    try {
      final client = Supabase.instance.client;
      // Note: Resend only works if not already verified. 
      // Rate limits apply (usually once per minute).
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

  Future<void> _onCheckVerification(
    CheckVerificationEvent event,
    Emitter<verificationState> emit,
  ) async {
    if (state.isExpired) {
       debugPrint('[verificationBloc] Attempted login after expiration.');
       return; 
    }

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

      // Attempt login to check verification status
      final response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null && response.session != null) {
        debugPrint('[verificationBloc] Verification successful. User logged in.');
        
        // Ensure profile exists in public.users table (post-verification check)
        await UserProfileManager().ensureProfileExists();

        emit(state.copyWith(isLoading: false, isVerified: true));
      } else {
        // This block might not be reached if signIn throws on unverified email
        // depending on Supabase config.
         debugPrint('[verificationBloc] Login success but no session? Unusual.');
         emit(state.copyWith(isLoading: false, isVerified: true));
      }

    } on AuthException catch (e) {
      debugPrint('[verificationBloc] Login failed: ${e.message}');
      if (e.message.toLowerCase().contains('email not confirmed') || 
          e.message.toLowerCase().contains('login failed')) { // Generic message sometimes
        emit(state.copyWith(
          isLoading: false,
          errorMessage: "Verifica prima l'email", // Specific message for UI
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
