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
Future<String> resolveCountryIdFromIso(String isoCode) async {
  final iso = isoCode.trim().toUpperCase();

  final row = await _client
      .from('paesi')
      .select('id, iso_code')
      .eq('iso_code', iso)
      .maybeSingle();

  // Debug
  // ignore: avoid_print
  print('[resolveCountryIdFromIso] iso=$iso row=$row');

  final id = row?['id'];
  if (id == null) throw StateError('Paese non trovato per ISO $iso');
  return id as String;
}


  Future<void> insertImmediate({
    required String userId,
    required String email,
    required String nome,
    required String cognome,
    required DateTime dataNascita,
    required bool maggiorenne,
    required String isoCode,
    required String nationalNumber,
  }) async {
    if (nationalNumber.isEmpty || nationalNumber.length < 6) {
      throw ArgumentError('Numero di telefono troppo corto');
    }
    final countryId = await resolveCountryIdFromIso(isoCode);
    await _client.from('utenti').upsert({
      'id': userId,
      'nome': nome,
      'cognome': cognome,
      'email': email,
      'data_nascita': dataNascita.toIso8601String(),
      'maggiorenne': maggiorenne,
    });
    await _client.from('utenti_numeri_telefono').upsert({
      'user_id': userId,
      'country_id': countryId,
      'telefono': nationalNumber,
      'is_primary': true,
      'is_verified': false,
    }, onConflict: 'user_id,telefono');
  }
}
