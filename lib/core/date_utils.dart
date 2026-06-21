// Local calendar-day helpers for Today screen scan and transaction dates.

/// Parse API ISO timestamps (UTC `Z`) into device local time for display.
DateTime parseApiDateTime(dynamic raw) {
  if (raw == null) return DateTime.now();
  final parsed = DateTime.tryParse(raw.toString());
  if (parsed == null) return DateTime.now();
  return parsed.isUtc ? parsed.toLocal() : parsed;
}

DateTime normalizeCalendarDate(DateTime d) => DateTime(d.year, d.month, d.day);

bool isSameCalendarDay(DateTime a, DateTime b) {
  final na = normalizeCalendarDate(a);
  final nb = normalizeCalendarDate(b);
  return na.year == nb.year && na.month == nb.month && na.day == nb.day;
}

bool isToday(DateTime date) => isSameCalendarDay(date, DateTime.now());

bool isPastDate(DateTime date) {
  final today = normalizeCalendarDate(DateTime.now());
  final d = normalizeCalendarDate(date);
  return d.isBefore(today);
}

bool isFutureDate(DateTime date) {
  final today = normalizeCalendarDate(DateTime.now());
  final d = normalizeCalendarDate(date);
  return d.isAfter(today);
}

/// UTC ISO range for API transaction queries (calendar day in local TZ).
String startUtc(DateTime d) =>
    DateTime(d.year, d.month, d.day).toUtc().toIso8601String();

String endUtc(DateTime d) =>
    DateTime(d.year, d.month, d.day, 23, 59, 59, 999).toUtc().toIso8601String();

/// Timestamp for a manual transaction on the viewed calendar day.
DateTime transactionTimestampForDay(DateTime calendarDay) {
  final day = normalizeCalendarDate(calendarDay);
  if (isToday(day)) return DateTime.now();
  return DateTime(day.year, day.month, day.day, 12);
}

/// Calendar date key for scanned-day API (YYYY-MM-DD).
String dateKey(DateTime d) {
  final n = normalizeCalendarDate(d);
  return '${n.year.toString().padLeft(4, '0')}-'
      '${n.month.toString().padLeft(2, '0')}-'
      '${n.day.toString().padLeft(2, '0')}';
}
