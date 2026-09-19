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

  final picked = DateTime(date.year, date.month, date.day, time.hour, time.minute);
  // The date picker allows today, so an earlier time today would otherwise
  // be scheduled in the past and still report "Reminder set".
  if (!picked.isAfter(DateTime.now())) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a time in the future.')),
      );
    }
    return null;
  }
  return picked;
}
