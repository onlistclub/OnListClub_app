import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Registrazione utente: insert atomico su `utenti` + `utenti_numeri_telefono` via RPC.
///
/// Chiama la funzione Postgres `register_user_transaction` per garantire che
/// utente e telefono siano scritti nella stessa transazione (no orfani in caso
/// di errore). La RPC è `SECURITY DEFINER`, verifica `auth.uid()`, calcola il
/// flag `maggiorenne` e risolve il paese da ISO: alla UI basta passare il numero
/// già in formato E.164 (fornito dal widget) e il codice ISO del paese.
class RegisterService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<Map<String, dynamic>?> registerAtomic({
    required String userId,
    required String email,
    required String nome,
    required String cognome,
    required DateTime dataNascita,
    required String telefono,
    String? countryIso,
  }) async {
    if (nome.trim().isEmpty || cognome.trim().isEmpty) {
      throw ArgumentError('Nome e cognome sono obbligatori');
    }
    final e164 = telefono.replaceAll(' ', '');
    if (e164.length < 7) {
      throw ArgumentError('Telefono non valido');
    }
    try {
      final result = await _client.rpc('register_user_transaction', params: {
        'p_id_utente': userId,
        'p_nome': nome,
        'p_cognome': cognome,
        'p_email': email,
        'p_data_nascita': dataNascita.toIso8601String().substring(0, 10),
        'p_telefono': e164,
        'p_country_iso': countryIso,
      }) as Map<String, dynamic>?;

      debugPrint('[RegisterService] RPC register_user_transaction result: $result');
      return result;
    } on PostgrestException catch (e) {
      debugPrint('[RegisterService] RPC error: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('[RegisterService] Unexpected error: $e');
      rethrow;
    }
  }
}
