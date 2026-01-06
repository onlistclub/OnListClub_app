import 'package:supabase_flutter/supabase_flutter.dart';

class PhoneService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<String?> resolveCountryIdByIso(String iso) async {
    final row = await _client
        .from('countries')
        .select('id')
        .or('iso.eq.${iso.toUpperCase()},code.eq.${iso.toUpperCase()}')
        .maybeSingle();
    return row?['id'] as String?;
  }

  Future<String?> composeE164ByCountryId({
    required String countryId,
    required String nationalNumberDigits,
  }) async {
    final row = await _client
        .from('countries')
        .select('dial_code')
        .eq('id', countryId)
        .maybeSingle();
    if (row == null) return null;
    final dial = row['dial_code'].toString();
    return '+$dial$nationalNumberDigits';
  }

  Future<String?> composeE164ByIso({
    required String countryIso,
    required String nationalNumberDigits,
  }) async {
    final row = await _client
        .from('countries')
        .select('dial_code')
        .or('iso.eq.${countryIso.toUpperCase()},code.eq.${countryIso.toUpperCase()}')
        .maybeSingle();
    if (row == null) return null;
    final dial = row['dial_code'].toString();
    return '+$dial$nationalNumberDigits';
  }
}
