import 'package:supabase_flutter/supabase_flutter.dart';

class PhoneService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<String?> resolveCountryIdByIso(String iso) async {
    final row = await _client
        .from('paesi')
        .select('id')
        .eq('iso_code', iso.toUpperCase())
        .maybeSingle();
    return row?['id'] as String?;
  }

  Future<String?> composeE164ByCountryId({
    required String countryId,
    required String nationalNumberDigits,
  }) async {
    final row = await _client
        .from('paesi')
        .select('numero_prefisso')
        .eq('id', countryId)
        .maybeSingle();
    if (row == null) return null;
    final dial = row['numero_prefisso'].toString();
    return '+$dial$nationalNumberDigits';
  }

  Future<String?> composeE164ByIso({
    required String countryIso,
    required String nationalNumberDigits,
  }) async {
    final row = await _client
        .from('paesi')
        .select('numero_prefisso')
        .eq('iso_code', countryIso.toUpperCase())
        .maybeSingle();
    if (row == null) return null;
    final dial = row['numero_prefisso'].toString();
    return '+$dial$nationalNumberDigits';
  }
}
