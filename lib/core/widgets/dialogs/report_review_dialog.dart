import 'package:flutter/material.dart';

import '../../../domain/models/review_report.dart';

/// Reason-picker for flagging a review. Returns the selected reason, or
/// null if the traveler cancelled without picking one — a forced choice
/// (no default-selected radio) so a report always carries real signal for
/// the Admin Portal's moderation queue.
Future<String?> showReportReviewDialog(BuildContext context) {
  String? selected;
  return showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Report this review'),
        content: RadioGroup<String>(
          groupValue: selected,
          onChanged: (value) => setDialogState(() => selected = value),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: ReportReason.all
                .map((reason) => RadioListTile<String>(contentPadding: EdgeInsets.zero, title: Text(ReportReason.label(reason)), value: reason))
                .toList(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: selected == null ? null : () => Navigator.of(context).pop(selected),
            child: const Text('Report'),
          ),
        ],
      ),
    ),
  );
}
