import 'package:intl/intl.dart';

class DateFormatter {
  static final DateFormat _long = DateFormat('d MMM yyyy', 'it_IT');
  static final DateFormat _short = DateFormat('dd/MM/yyyy');

  static String formatLong(DateTime d) => _long.format(d);

  static String formatShort(DateTime d) => _short.format(d);
}
