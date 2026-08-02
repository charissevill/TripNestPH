import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../widgets/dialogs/confirmation_dialog.dart';

/// Confirms before signing out — shared by every screen with a sign-out
/// action (Profile, Verify Email) so the prompt and behavior never drift
/// between them. Returns whether the traveler actually signed out, so a
/// caller that needs to navigate afterward (Verify Email isn't inside the
/// auth-redirect shell the way Profile is) knows whether to.
Future<bool> confirmSignOut(BuildContext context) async {
  final confirmed = await showConfirmationDialog(
    context,
    title: 'Log out?',
    message: 'You can sign back in anytime with the same account.',
    confirmLabel: 'Log Out',
    isDestructive: true,
  );
  if (!confirmed || !context.mounted) return false;
  await context.read<AuthProvider>().signOut();
  return true;
}
