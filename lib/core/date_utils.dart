// Local calendar-day helpers for Today screen scan and transaction dates.

DateTime normalizeCalendarDate(DateTime d) =>
    DateTime(d.year, d.month, d.day);

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

/// Timestamp for a manual transaction on the viewed calendar day.
DateTime transactionTimestampForDay(DateTime calendarDay) {
  final day = normalizeCalendarDate(calendarDay);
  if (isToday(day)) return DateTime.now();
  return DateTime(day.year, day.month, day.day, 12);
}
