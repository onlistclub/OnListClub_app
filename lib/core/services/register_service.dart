import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/age_calculator.dart';
import '../utils/phone_utils.dart';

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
    final normalizedPhone = PhoneUtils.normalize(
      countryIso: countryIso,
      completeNumber: telefono,
    );
    if (normalizedPhone.length < 7) {
      throw ArgumentError('Telefono non valido');
    }
    final isAdult = AgeCalculator.isAdult(dataNascita);
    try {
      final result = await _client.rpc('register_user_transaction', params: {
        'p_user_id': userId,
        'p_nome': nome,
        'p_cognome': cognome,
        'p_email': email,
        'p_data_nascita': dataNascita.toIso8601String().substring(0, 10),
        'p_telefono': normalizedPhone,
        'p_country_iso': countryIso,
      }) as Map<String, dynamic>?;

      debugPrint('[RegisterService] RPC register_user_transaction result: $result, isAdult: $isAdult');
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
