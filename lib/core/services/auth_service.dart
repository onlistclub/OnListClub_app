/// Servizio centralizzato per la gestione dell'autenticazione Supabase.
///
/// Responsabilità:
///   * Ascoltare `onAuthStateChange` e reagire a logout / sessione persa
///     reindirizzando automaticamente alla schermata di autenticazione.
///   * Esporre helper sincroni (`isLoggedIn`, `currentSession`) per
///     l'UI/splash.
///   * Centralizzare il `signOut` così che il listener gestisca la
///     navigazione (non serve farla manualmente dai punti di chiamata).
///
/// La sicurezza vera (hashing password, JWT, refresh) resta a carico di
/// Supabase. Qui c'è solo coordinamento lato client.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../routes/app_routes.dart';
import 'navigator_service.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  StreamSubscription<AuthState>? _authSub;
  bool _initialized = false;

  /// Da chiamare una sola volta in `main()` dopo `Supabase.initialize`.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) {
        final event = data.event;
        debugPrint('[AuthService] auth event: ${event.name}');

        // Logout esplicito o sessione persa: riportiamo l'utente alla
        // schermata di autenticazione, ovunque si trovi nell'app.
        if (event == AuthChangeEvent.signedOut) {
          NavigatorService.pushNamedAndRemoveUntil(
            AppRoutes.authenticationScreen,
          );
        }
        // signedIn / tokenRefreshed / userUpdated: la navigazione
        // post-login è gestita dai bloc delle schermate.
      },
      onError: (Object e) {
        debugPrint('[AuthService] auth stream error: $e');
      },
    );
  }

  /// Sessione attualmente salvata in storage sicuro (Keychain/EncryptedSP).
  Session? get currentSession =>
      Supabase.instance.client.auth.currentSession;

  /// True se esiste una sessione valida (token presente e non scaduto).
  bool get isLoggedIn {
    final s = currentSession;
    if (s == null) return false;
    return !s.isExpired;
  }

  /// Logout esplicito. La navigazione viene gestita dal listener.
  Future<void> signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      debugPrint('[AuthService] signOut error: $e');
      // Anche in caso d'errore, forziamo il ritorno al login: lo stato
      // locale potrebbe essere inconsistente.
      NavigatorService.pushNamedAndRemoveUntil(
        AppRoutes.authenticationScreen,
      );
    }
  }

  /// Cleanup del listener (in pratica non viene mai chiamato perché
  /// l'istanza vive quanto il processo, ma è utile per i test).
  Future<void> dispose() async {
    await _authSub?.cancel();
    _authSub = null;
    _initialized = false;
  }
}
