/// Date helpers. All dates in the app are calendar days without a time part.
library;

/// Drops the time part (local calendar day).
DateTime dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

/// [days] calendar days before [day]. Uses the DateTime constructor instead of
/// `subtract(Duration(days: n))` so that daylight-saving changes cannot shift the date.
DateTime daysBefore(DateTime day, int days) => DateTime(day.year, day.month, day.day - days);

String _two(int v) => v.toString().padLeft(2, '0');

/// `dd.MM.yyyy` — the format used by the BNM feed and shown to the user.
String formatDay(DateTime day) => '${_two(day.day)}.${_two(day.month)}.${day.year}';

/// `dd.MM` — short label for chart axes.
String formatDayShort(DateTime day) => '${_two(day.day)}.${_two(day.month)}';

/// `yyyy-MM-dd` — stable key for the local cache.
String dayKey(DateTime day) => '${day.year}-${_two(day.month)}-${_two(day.day)}';

/// Parses `dd.MM.yyyy`; returns null for anything else.
DateTime? parseDay(String? text) {
  final match = RegExp(r'^(\d{2})\.(\d{2})\.(\d{4})$').firstMatch(text?.trim() ?? '');
  if (match == null) return null;
  final d = int.parse(match.group(1)!);
  final m = int.parse(match.group(2)!);
  final y = int.parse(match.group(3)!);
  final result = DateTime(y, m, d);
  // Reject impossible dates such as 31.02.2026 (DateTime would roll them over).
  if (result.day != d || result.month != m || result.year != y) return null;
  return result;
}
