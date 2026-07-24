import 'package:flutter_test/flutter_test.dart';

import 'package:tripnest_ph/core/utils/calendar_grid.dart';

void main() {
  group('cellsForMonth()', () {
    test('pads leading blanks so day 1 lands in the correct Sun-first column', () {
      // August 1, 2026 is a Saturday — 6 leading blank cells (Sun..Fri).
      final cells = CalendarGrid.cellsForMonth(DateTime(2026, 8));

      expect(cells.take(6), everyElement(isNull));
      expect(cells[6], DateTime(2026, 8, 1));
      expect(cells.last, DateTime(2026, 8, 31));
    });

    test('handles a month that starts on Sunday with zero leading blanks', () {
      // November 1, 2026 is a Sunday.
      final cells = CalendarGrid.cellsForMonth(DateTime(2026, 11));

      expect(cells.first, DateTime(2026, 11, 1));
    });

    test('produces exactly 29 days for February in a leap year', () {
      final cells = CalendarGrid.cellsForMonth(DateTime(2028, 2));
      final days = cells.whereType<DateTime>().toList();

      expect(days.length, 29);
      expect(days.last, DateTime(2028, 2, 29));
    });

    test('produces exactly 28 days for February in a non-leap year', () {
      final cells = CalendarGrid.cellsForMonth(DateTime(2026, 2));
      final days = cells.whereType<DateTime>().toList();

      expect(days.length, 28);
    });
  });

  group('buildDateMap()', () {
    test('expands a multi-day range so every day in it maps back to the item', () {
      final map = CalendarGrid.buildDateMap<String>(
        ['trip-1'],
        (_) => DateTime(2026, 8, 3),
        (_) => DateTime(2026, 8, 5),
      );

      expect(map[DateTime(2026, 8, 3)], ['trip-1']);
      expect(map[DateTime(2026, 8, 4)], ['trip-1']);
      expect(map[DateTime(2026, 8, 5)], ['trip-1']);
      expect(map.containsKey(DateTime(2026, 8, 6)), isFalse);
    });

    test('a single-day trip only maps to that one day', () {
      final map = CalendarGrid.buildDateMap<String>(
        ['day-trip'],
        (_) => DateTime(2026, 8, 3),
        (_) => DateTime(2026, 8, 3),
      );

      expect(map.keys, [DateTime(2026, 8, 3)]);
    });

    test('overlapping trips both appear in the same day\'s list', () {
      final map = CalendarGrid.buildDateMap<String>(
        ['trip-a', 'trip-b'],
        (t) => t == 'trip-a' ? DateTime(2026, 8, 1) : DateTime(2026, 8, 4),
        (t) => t == 'trip-a' ? DateTime(2026, 8, 5) : DateTime(2026, 8, 8),
      );

      expect(map[DateTime(2026, 8, 4)], containsAll(['trip-a', 'trip-b']));
    });

    test('items with a null start or end are skipped entirely', () {
      final map = CalendarGrid.buildDateMap<String>(
        ['no-dates'],
        (_) => null,
        (_) => null,
      );

      expect(map, isEmpty);
    });
  });
}
