// ignore: implementation_imports
import 'package:intl_phone_number_input/src/models/country_list.dart'
    show Countries;

/// Rappresentazione minimale di un paese per il selettore prefisso.
///
/// Dati derivati da [Countries.countryList] del pacchetto
/// `intl_phone_number_input` (mantiene una lista unica, già completa di
/// traduzioni italiane). La bandiera è un'emoji generata da ISO2, così
/// non dipendiamo dagli asset PNG del pacchetto.
class PhoneCountry {
  const PhoneCountry({
    required this.iso,
    required this.dial,
    required this.name,
    required this.flagEmoji,
  });

  /// ISO2 maiuscolo (es. "IT").
  final String iso;

  /// Dial code completo con "+" (es. "+39").
  final String dial;

  /// Nome localizzato in italiano (fallback inglese).
  final String name;

  /// Emoji bandiera nazionale (es. 🇮🇹).
  final String flagEmoji;

  /// Lista completa dei paesi, ordinata alfabeticamente per nome italiano.
  /// Calcolata una volta sola (lazy cache).
  static List<PhoneCountry>? _cached;
  static List<PhoneCountry> all() {
    final cached = _cached;
    if (cached != null) return cached;
    final list = <PhoneCountry>[];
    for (final raw in Countries.countryList) {
      final iso = (raw['alpha_2_code'] as String?)?.toUpperCase();
      final dial = raw['dial_code'] as String?;
      if (iso == null || iso.length != 2 || dial == null || dial.isEmpty) {
        continue;
      }
      final translations = raw['nameTranslations'] as Map<String, dynamic>?;
      final nameIt = translations?['it'] as String?;
      final nameEn = raw['en_short_name'] as String?;
      list.add(PhoneCountry(
        iso: iso,
        dial: dial,
        name: nameIt ?? nameEn ?? iso,
        flagEmoji: _emojiFromIso(iso),
      ));
    }
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _cached = list;
    return list;
  }

  /// Trova un paese per ISO2 (case-insensitive). Restituisce `null` se non esiste.
  static PhoneCountry? byIso(String? iso) {
    if (iso == null || iso.length != 2) return null;
    final up = iso.toUpperCase();
    for (final c in all()) {
      if (c.iso == up) return c;
    }
    return null;
  }

  /// Converte un codice ISO2 (es. "IT") nell'emoji bandiera corrispondente.
  /// Funziona combinando i due Regional Indicator Symbols.
  static String _emojiFromIso(String iso) {
    if (iso.length != 2) return '';
    final base = 0x1F1E6 - 'A'.codeUnitAt(0);
    final cp1 = base + iso.codeUnitAt(0);
    final cp2 = base + iso.codeUnitAt(1);
    return String.fromCharCodes([cp1, cp2]);
  }
}
