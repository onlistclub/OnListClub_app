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

  /// Chiede l'invio dell'email di conferma. Ritorna `true` se la richiesta è
  /// stata accettata.
  ///
  /// Nota: la function risponde `ok` anche quando il rate limit blocca un
  /// secondo invio ravvicinato — l'email precedente è ancora valida, quindi
  /// per l'utente il risultato è lo stesso.
  static Future<bool> requestDeletion() async {
    try {
      final res = await _client.functions.invoke('request-account-deletion');
      final ok = res.status == 200 && (res.data?['ok'] == true);
      if (!ok) {
        debugPrint('[AccountDeletionService] non ok: '
            'status=${res.status} data=${res.data}');
      }
      return ok;
    } on FunctionException catch (e) {
      debugPrint('[AccountDeletionService] FunctionException: '
          '${e.status} ${e.details}');
      return false;
    } catch (e) {
      debugPrint('[AccountDeletionService] error: $e');
      return false;
    }
  }
}
