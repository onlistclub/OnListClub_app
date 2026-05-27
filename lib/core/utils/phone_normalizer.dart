import 'package:phone_numbers_parser/phone_numbers_parser.dart';

/// Normalizzazione di un numero di telefono in formato E.164.
///
/// Espone `normalizeToE164(input, iso)`. Restituisce null se il numero non è
/// parsabile. Dipende da `phone_numbers_parser`. Usato in registrazione e in
/// edit profilo prima dello scrivere su Supabase.
class PhoneNormalizer {
  static String? normalizeToE164(String input, IsoCode isoCountry) {
    try {
      final parser = PhoneNumber.parse(input, callerCountry: isoCountry);
      final e164 = parser.international;
      // Ensure no spaces and leading '+'
      final cleaned = e164.replaceAll(' ', '');
      if (!cleaned.startsWith('+')) return '+$cleaned';
      return cleaned;
    } catch (_) {
      return null;
    }
  }
}
