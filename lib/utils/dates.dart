import 'package:intl/intl.dart';

final DateFormat _weekday = DateFormat('EEEE', 'de_DE');
final DateFormat _dayMonth = DateFormat('d. MMM', 'de_DE');
final DateFormat _shortDate = DateFormat('dd.MM.yyyy', 'de_DE');

String weekdayName(DateTime d) => _weekday.format(d);
String dayMonth(DateTime d) => _dayMonth.format(d);
String shortDate(DateTime d) => _shortDate.format(d);

/// The Monday of the week that [from] falls in (or the coming Monday when
/// [upcoming] is set and today is past Monday).
DateTime mondayOf(DateTime from, {bool upcoming = false}) {
  final d = DateTime(from.year, from.month, from.day);
  final monday = d.subtract(Duration(days: d.weekday - DateTime.monday));
  if (upcoming && !monday.isAfter(d) && d.weekday != DateTime.monday) {
    return monday.add(const Duration(days: 7));
  }
  return monday;
}

String weekRangeLabel(DateTime start, int days) {
  final end = start.add(Duration(days: days - 1));
  return '${_dayMonth.format(start)} – ${_dayMonth.format(end)}';
}
