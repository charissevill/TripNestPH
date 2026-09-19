import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/auth_provider.dart';
import '../../data/repositories/admin_repository.dart';
import '../../domain/models/admin_user.dart';
import '../business/my_business_screen.dart';
import '../saved/saved_screen.dart';

/// The 4th shell-branch tab's content — [SavedScreen] for every account
/// except an active `businessOwner`, who sees [MyBusinessScreen] instead
/// (see [mainNavTabsFor]'s doc comment for why that swap exists). Keeping
/// this one branch/route and swapping its *content* by role, rather than
/// giving `businessOwner` a differently-shaped [StatefulShellRoute],
/// avoids restructuring the whole shell for what's currently a single-tab
/// difference.
class SavedOrMyBusinessTab extends StatelessWidget {
  const SavedOrMyBusinessTab({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().firebaseUser?.uid;
    return StreamBuilder<AdminUser?>(
      stream: uid == null
          ? Stream.value(null)
          : AdminRepository().streamSelf(uid),
      builder: (context, snapshot) {
        final isBusinessOwner =
            snapshot.data?.role == AdminRole.businessOwner &&
            (snapshot.data?.isActive ?? false);
        if (isBusinessOwner)
          return MyBusinessScreen(uid: uid!, showBackButton: false);
        return const SavedScreen();
      },
    );
  }
}
