import 'package:intl/intl.dart';

/// Formattazione date condivisa.
///
/// Espone `formatLong` (es. `12 mag 2026`, locale `it_IT`) e `formatShort`
/// (`dd/MM/yyyy`). Dipende da `intl.DateFormat`. Da usare al posto di
/// `DateFormat(...)` istanziato volta per volta.
class DateFormatter {
  static final DateFormat _long = DateFormat('d MMM yyyy', 'it_IT');
  static final DateFormat _short = DateFormat('dd/MM/yyyy');

  static String formatLong(DateTime d) => _long.format(d);

  static String formatShort(DateTime d) => _short.format(d);
}
