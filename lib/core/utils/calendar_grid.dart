/// Pure date-grid math for [TripCalendarScreen] — split out from the widget
/// so the weekday-offset and date-range logic (classic off-by-one territory)
/// gets real unit test coverage without needing a widget/Firebase harness.
class CalendarGrid {
  CalendarGrid._();

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// One cell per day of [month], padded with leading `null`s so day 1
  /// lands in the correct Sun-first column (index 0 = Sunday).
  static List<DateTime?> cellsForMonth(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // DateTime.weekday is Mon=1..Sun=7; %7 maps Sunday to 0.
    final leadingBlanks = firstDay.weekday % 7;
    return [
      for (var i = 0; i < leadingBlanks; i++) null,
      for (var d = 1; d <= daysInMonth; d++) DateTime(month.year, month.month, d),
    ];
  }

  /// Expands every item with a [start, end] range (inclusive) into a
  /// day -> items map, so a calendar cell can look up what's happening
  /// on that date in O(1).
  static Map<DateTime, List<T>> buildDateMap<T>(
    List<T> items,
    DateTime? Function(T item) start,
    DateTime? Function(T item) end,
  ) {
    final map = <DateTime, List<T>>{};
    for (final item in items) {
      final itemStart = start(item);
      final itemEnd = end(item);
      if (itemStart == null || itemEnd == null) continue;
      var day = dateOnly(itemStart);
      final last = dateOnly(itemEnd);
      if (last.isBefore(day)) continue;
      while (!day.isAfter(last)) {
        map.putIfAbsent(day, () => []).add(item);
        day = day.add(const Duration(days: 1));
      }
    }
    return map;
  }
}
