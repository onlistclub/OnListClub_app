import 'package:phone_numbers_parser/phone_numbers_parser.dart';

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
