import 'package:flutter/material.dart';

/// Asks the traveler to pick a date, then a time, for a local reminder —
/// used by "Remind Me" on Festival Details and "Set Trip Reminder" on a
/// saved itinerary. Returns null if either step is cancelled.
Future<DateTime?> pickReminderDateTime(BuildContext context, {DateTime? initialDate}) async {
  final now = DateTime.now();
  final date = await showDatePicker(
    context: context,
    initialDate: initialDate ?? now.add(const Duration(days: 1)),
    firstDate: now,
    lastDate: now.add(const Duration(days: 730)),
  );
  if (date == null || !context.mounted) return null;

  final time = await showTimePicker(
    context: context,
    initialTime: const TimeOfDay(hour: 9, minute: 0),
  );
  if (time == null) return null;

  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}
