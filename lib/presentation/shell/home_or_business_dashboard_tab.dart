import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/auth_provider.dart';
import '../../data/repositories/admin_repository.dart';
import '../../domain/models/admin_user.dart';
import '../business/business_dashboard_screen.dart';
import '../home/home_screen.dart';

/// The 1st shell-branch tab's content — [HomeScreen] for every account
/// except an active `businessOwner`, who sees [BusinessDashboardScreen]
/// instead (see [BusinessDashboardScreen]'s doc comment for why). Same
/// role-swap pattern as `SavedOrMyBusinessTab`'s 4th-tab swap.
class HomeOrBusinessDashboardTab extends StatelessWidget {
  const HomeOrBusinessDashboardTab({super.key});

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
        if (isBusinessOwner) return BusinessDashboardScreen(uid: uid!);
        return const HomeScreen();
      },
    );
  }
}
