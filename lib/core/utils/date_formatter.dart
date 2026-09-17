import 'package:intl/intl.dart';

/// Formattazione date condivisa.
///
/// Espone `formatLong` (es. `12 mag 2026`, locale `it_IT`), `formatDayMonth`
/// (`27 giu`, senza anno) e `formatShort` (`dd/MM/yyyy`). Dipende da
/// `intl.DateFormat`. Da usare al posto di `DateFormat(...)` istanziato volta
/// per volta.
class DateFormatter {
  static final DateFormat _long = DateFormat('d MMM yyyy', 'it_IT');
  static final DateFormat _dayMonth = DateFormat('d MMM', 'it_IT');
  static final DateFormat _dayMonthFull = DateFormat('d MMMM', 'it_IT');
  static final DateFormat _dayMonthFullYear = DateFormat('d MMMM yyyy', 'it_IT');
  static final DateFormat _short = DateFormat('dd/MM/yyyy');

  static String formatLong(DateTime d) => _long.format(d);

  /// Giorno + mese abbreviato senza anno (es. `27 giu`).
  static String formatDayMonth(DateTime d) => _dayMonth.format(d);

  /// Giorno + mese esteso capitalizzato (es. `17 Luglio`), formato del design
  /// "(NUOVO) - Riepilogo Ticket". Con [withYear] aggiunge l'anno in coda.
  static String formatDayMonthFull(DateTime d, {bool withYear = false}) {
    final s = (withYear ? _dayMonthFullYear : _dayMonthFull).format(d);
    // intl it_IT dà il mese minuscolo ("17 luglio") → capitalizza.
    final i = s.indexOf(' ') + 1;
    return s.substring(0, i) + s[i].toUpperCase() + s.substring(i + 1);
  }

  static String formatShort(DateTime d) => _short.format(d);

  static const _giorniBrevi = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];
  static const _mesiBrevi = [
    'Gen', 'Feb', 'Mar', 'Apr', 'Mag', 'Giu',
    'Lug', 'Ago', 'Set', 'Ott', 'Nov', 'Dic',
  ];

  /// Giorno della settimana, giorno e mese abbreviati (es. `Dom 19 Apr`),
  /// formato delle card serata/club del design.
  static String formatBreve(DateTime d) =>
      '${_giorniBrevi[d.weekday - 1]} ${d.day} ${_mesiBrevi[d.month - 1]}';
}
