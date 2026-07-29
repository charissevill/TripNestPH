import 'package:flutter/material.dart';

import 'confirmation_dialog.dart';

/// Wraps a form screen's `Scaffold` so the system back button/gesture asks
/// for confirmation instead of silently discarding typed-but-unsaved
/// changes — the same "how do I get my data back" complaint
/// `generated_itinerary_screen.dart`'s own unsaved-itinerary guard already
/// exists to prevent, generalized for any form with a simple dirty flag.
class DiscardChangesScope extends StatelessWidget {
  const DiscardChangesScope({super.key, required this.isDirty, required this.child});

  final bool isDirty;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !isDirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final confirmed = await showConfirmationDialog(
          context,
          title: 'Discard changes?',
          message: 'You have unsaved changes that will be lost.',
          confirmLabel: 'Discard',
          isDestructive: true,
        );
        if (confirmed && context.mounted) Navigator.of(context).pop();
      },
      child: child,
    );
  }
}
