import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Avvio della cancellazione account.
///
/// L'app non cancella niente da sé: chiede alla Edge Function
/// `request-account-deletion` di spedire all'utente un'email con un link
/// monouso. La cancellazione vera avviene sul sito
/// (https://www.onlistclub.com/auth/delete-account), dove serve la password —
/// o, per chi è entrato con Apple/Google e una password non ce l'ha, la frase
/// di conferma.
///
/// Perché passare da un'email invece di cancellare al tocco: l'operazione è
/// irreversibile, e il possesso della casella di posta è la prova che a
/// chiederlo sia davvero il titolare (stessa logica del reset password).
/// `functions.invoke` allega il JWT: la function ricava l'utente da lì e
/// ignora qualsiasi identità passata nel body.
class AccountDeletionService {
  static SupabaseClient get _client => Supabase.instance.client;

  /// Chiede l'invio dell'email di conferma.
  ///
  /// Ritorna `(ok, error)`: `ok` true se la richiesta è stata accettata; in caso
  /// di fallimento `error` è il codice dello stadio che ha fallito, così l'app
  /// può dire ALL'UTENTE cosa non ha funzionato invece di un generico "riprova":
  ///   - `unauthorized` → JWT mancante/scaduto
  ///   - `no_email`     → l'account non ha un'email a cui mandare il link
  ///   - `db_error`     → insert in `richieste_cancellazione` fallito
  ///                      (tabella mancante? migration non applicata?)
  ///   - `email_error`  → la `send-email` è fallita (Brevo: api key/mittente…)
  ///   - `http_<n>` / null → altro
  /// Il dettaglio Brevo (missing_api_key / brevo_error) resta nei log della
  /// Edge Function: qui arriva al massimo `email_error`.
  ///
  /// Nota: la function risponde `ok` anche quando il rate limit blocca un
  /// secondo invio ravvicinato — l'email precedente è ancora valida.
  static Future<({bool ok, String? error})> requestDeletion() async {
    String? errorOf(dynamic data) =>
        (data is Map && data['error'] != null) ? data['error'].toString() : null;
    try {
      final res = await _client.functions.invoke('request-account-deletion');
      if (res.status == 200 && (res.data?['ok'] == true)) {
        return (ok: true, error: null);
      }
      debugPrint('[AccountDeletionService] non ok: '
          'status=${res.status} data=${res.data}');
      return (ok: false, error: errorOf(res.data) ?? 'http_${res.status}');
    } on FunctionException catch (e) {
      debugPrint('[AccountDeletionService] FunctionException: '
          '${e.status} ${e.details}');
      return (ok: false, error: errorOf(e.details) ?? 'http_${e.status}');
    } catch (e) {
      debugPrint('[AccountDeletionService] error: $e');
      return (ok: false, error: null);
    }
  }
}
