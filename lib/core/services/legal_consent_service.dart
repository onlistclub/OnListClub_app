import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../legal/legal_versions.dart';

/// Registra e verifica il consenso dell'utente ai documenti legali (privacy
/// policy e termini).
///
/// ── CONTRATTO CON IL DB ──────────────────────────────────────────────────────
/// Ogni accettazione è una NUOVA riga in `public.user_consents` (mai un
/// update): lo storico serve per dimostrare al Garante che l'utente ha
/// effettivamente accettato la versione vigente al momento della sua
/// registrazione. La colonna `source` distingue signup, re-prompt e canale
/// (app / gestionale / sito).
///
/// Vedi la migration `017_user_consents.sql` per lo schema completo, incluse
/// le policy RLS (ogni utente vede solo le proprie righe).
class LegalConsentService {
  LegalConsentService._();

  /// Esito del controllo pre-home: dice all'UI se serve una schermata di
  /// ri-accettazione e per quali documenti.
  static const String docPrivacy = 'privacy';
  static const String docTerms = 'terms';

  /// Registra il consenso dell'utente ai due documenti (privacy + termini).
  ///
  /// Chiamata:
  ///  - alla fine di [SignUpBloc._onSubmitSignUp] (source = `app_signup`);
  ///  - alla fine della schermata di ri-accettazione (source = `app_reprompt`).
  ///
  /// Fire-and-forget: qualsiasi errore viene silenziato e loggato. In caso di
  /// rete assente la registrazione può fallire, ma è un compromesso accettabile
  /// (l'utente ha comunque interagito con il checkbox in-app; la prova
  /// documentale ideale — la riga in DB — arriverà al primo insert riuscito
  /// quando l'utente rifarà il login).
  static Future<void> recordConsent({
    required String userId,
    required String source,
    Map<String, dynamic> extraMetadata = const {},
  }) async {
    try {
      final client = Supabase.instance.client;
      await client.from('user_consents').insert([
        {
          'user_id': userId,
          'document_type': docPrivacy,
          'document_version': kPrivacyVersion,
          'source': source,
          'metadata': extraMetadata,
        },
        {
          'user_id': userId,
          'document_type': docTerms,
          'document_version': kTermsVersion,
          'source': source,
          'metadata': extraMetadata,
        },
      ]);
    } catch (e) {
      debugPrint('[LegalConsent] insert fallito ($source): $e');
    }
  }

  /// Verifica se l'utente ha già accettato le versioni correnti.
  ///
  /// Ritorna [LegalReacceptanceStatus] con:
  ///  - `needsReacceptance`: true se almeno uno dei due documenti è cambiato
  ///     rispetto all'ultima accettazione dell'utente.
  ///  - `firstTime`: true se l'utente non ha MAI una riga in user_consents
  ///     (utenti registrati prima della migration 017). Va gestito come
  ///     ri-accettazione, ma la copy della schermata può essere più morbida.
  ///
  /// In caso di errore (rete assente, tabella non ancora creata) restituisce
  /// [LegalReacceptanceStatus.ok] — non blocchiamo l'app per un problema
  /// diagnostico: l'utente verrà ri-prompted al prossimo avvio riuscito.
  static Future<LegalReacceptanceStatus> checkReacceptance(String userId) async {
    try {
      final client = Supabase.instance.client;
      final rows = await client
          .from('user_consents')
          .select('document_type, document_version, accepted_at')
          .eq('user_id', userId)
          .order('accepted_at', ascending: false);

      final list = (rows as List).cast<Map<String, dynamic>>();
      if (list.isEmpty) {
        return const LegalReacceptanceStatus(
          needsReacceptance: true,
          firstTime: true,
          needsPrivacy: true,
          needsTerms: true,
        );
      }

      // Tiene la versione più recente per ogni documento (list è già ordinato
      // per accepted_at DESC, quindi il primo hit è quello valido).
      String? lastPrivacy;
      String? lastTerms;
      for (final r in list) {
        final t = r['document_type'] as String?;
        final v = r['document_version'] as String?;
        if (t == docPrivacy) lastPrivacy ??= v;
        if (t == docTerms) lastTerms ??= v;
        if (lastPrivacy != null && lastTerms != null) break;
      }

      final needsPrivacy = lastPrivacy != kPrivacyVersion;
      final needsTerms = lastTerms != kTermsVersion;

      return LegalReacceptanceStatus(
        needsReacceptance: needsPrivacy || needsTerms,
        firstTime: false,
        needsPrivacy: needsPrivacy,
        needsTerms: needsTerms,
      );
    } catch (e) {
      debugPrint('[LegalConsent] check fallito: $e');
      return LegalReacceptanceStatus.ok;
    }
  }
}

class LegalReacceptanceStatus {
  final bool needsReacceptance;
  final bool firstTime;
  final bool needsPrivacy;
  final bool needsTerms;

  const LegalReacceptanceStatus({
    required this.needsReacceptance,
    required this.firstTime,
    required this.needsPrivacy,
    required this.needsTerms,
  });

  static const LegalReacceptanceStatus ok = LegalReacceptanceStatus(
    needsReacceptance: false,
    firstTime: false,
    needsPrivacy: false,
    needsTerms: false,
  );
}
