import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Esito di [AppleIdentityService.linkApple].
enum AppleLinkResult {
  linked,

  /// L'utente ha chiuso il foglio di Apple: nessun messaggio da mostrare.
  canceled,

  /// Quell'Apple ID è già l'identità di un ALTRO account OnListClub (tipico:
  /// primo accesso con "Nascondi la mia email", che ha creato un account a sé).
  alreadyUsed,

  /// "Allow manual linking" spento in Supabase (Authentication → Settings).
  linkingDisabled,
  failed,
}

/// Apple come secondo metodo d'accesso dello STESSO account.
///
/// Perché serve: se l'utente si è registrato con email e password e poi entra
/// con Apple scegliendo "Nascondi la mia email", Apple passa un indirizzo
/// @privaterelay.appleid.com e Supabase crea un secondo account, vuoto.
/// Collegando Apple dal profilo mentre si è già dentro, l'identità Apple
/// finisce sull'account esistente e il login con Apple ci riporta lì.
///
/// Il collegamento usa `linkIdentityWithIdToken`, che richiede "Allow manual
/// linking" attivo nel progetto Supabase.
class AppleIdentityService {
  AppleIdentityService._();

  static SupabaseClient get _client => Supabase.instance.client;

  /// Nonce grezzo per la richiesta ad Apple: ad Apple va lo sha256
  /// ([sha256Of]), a Supabase il valore grezzo. Supabase verifica che l'hash
  /// coincida con quello dentro l'idToken (protezione dai replay).
  static String generateNonce([int length = 32]) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return List.generate(length, (_) => chars[random.nextInt(chars.length)])
        .join();
  }

  static String sha256Of(String input) =>
      sha256.convert(utf8.encode(input)).toString();

  /// True se l'utente corrente ha già Apple fra le identità. Legge dalla
  /// sessione locale: nessuna chiamata di rete.
  static bool isAppleLinked() {
    final identities = _client.auth.currentUser?.identities ?? const [];
    return identities.any((i) => i.provider == 'apple');
  }

  /// Apre il foglio di Apple e aggiunge l'identità all'account loggato.
  static Future<AppleLinkResult> linkApple() async {
    try {
      final rawNonce = generateNonce();
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email],
        nonce: sha256Of(rawNonce),
      );
      final idToken = credential.identityToken;
      if (idToken == null) return AppleLinkResult.failed;

      await _client.auth.linkIdentityWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );
      // La risposta del link non sempre riporta le identità aggiornate:
      // rileggiamo l'utente così [isAppleLinked] vede subito Apple.
      await _client.auth.refreshSession();
      return AppleLinkResult.linked;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return AppleLinkResult.canceled;
      }
      debugPrint('[AppleIdentity] Apple: code=${e.code} msg=${e.message}');
      return AppleLinkResult.failed;
    } on AuthException catch (e) {
      debugPrint('[AppleIdentity] Supabase: code=${e.code} msg=${e.message}');
      switch (e.code) {
        case 'identity_already_exists':
          return AppleLinkResult.alreadyUsed;
        case 'manual_linking_disabled':
          return AppleLinkResult.linkingDisabled;
      }
      return AppleLinkResult.failed;
    } catch (e) {
      debugPrint('[AppleIdentity] errore inatteso: $e');
      return AppleLinkResult.failed;
    }
  }
}
