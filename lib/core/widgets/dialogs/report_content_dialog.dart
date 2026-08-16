import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/content_report_repository.dart';
import '../../../domain/models/content_report.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_exception.dart';

/// Reason-picker for flagging a destination/restaurant/festival listing
/// itself — same shape as `showReportReviewDialog`, different reason
/// taxonomy ([ContentReportReason], not [ReportReason]). Returns the
/// selected reason, or null if the traveler cancelled without picking one.
Future<String?> showReportContentDialog(BuildContext context) {
  String? selected;
  return showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Report this listing'),
        content: RadioGroup<String>(
          groupValue: selected,
          onChanged: (value) => setDialogState(() => selected = value),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: ContentReportReason.all
                .map(
                  (reason) => RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    title: Text(ContentReportReason.label(reason)),
                    value: reason,
                  ),
                )
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

/// Shows [showReportContentDialog], then submits the report if the
/// traveler picked a reason — the full sign-in-check/dialog/submit/snackbar
/// flow in one call, so every Details screen's "Report" action is a single
/// line instead of duplicating this each time.
Future<void> reportContent(
  BuildContext context, {
  required String targetId,
  required ContentTargetType targetType,
  ContentReportRepository? repository,
}) async {
  final auth = context.read<AuthProvider>();
  if (!auth.isSignedIn) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign in to report a listing.')));
    return;
  }
  final reason = await showReportContentDialog(context);
  if (reason == null || !context.mounted) return;
  try {
    await (repository ?? ContentReportRepository()).report(
      targetId: targetId,
      targetType: targetType,
      userId: auth.firebaseUser!.uid,
      reason: reason,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thanks — our team will take a look.')));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppException.from(e).message)));
    }
  }
}
