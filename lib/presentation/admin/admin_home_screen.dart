import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/routes/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/states/empty_state_widget.dart';
import '../../core/widgets/states/loading_widget.dart';
import '../../data/repositories/admin_repository.dart';
import '../../domain/models/admin_user.dart';

/// The Admin Portal's landing screen — built into this same traveler app
/// (not a separate project), reachable only via the "Admin Portal" tile on
/// Profile, which itself only renders for a signed-in user with an active
/// `admin_users` doc. This screen re-checks that live via [AdminRepository]
/// rather than trusting the caller, so a mid-session suspension or role
/// change (see `firestore.rules`'s "enforced live" comments) takes effect
/// immediately even if someone is already sitting on this screen.
class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().firebaseUser?.uid;
    if (uid == null) {
      return const Scaffold(
        body: SafeArea(
          child: EmptyStateWidget(
            icon: Symbols.lock_rounded,
            title: 'Sign in required',
            message: 'Sign in to continue.',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Admin Portal'),
      ),
      body: StreamBuilder<AdminUser?>(
        stream: AdminRepository().streamSelf(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return LoadingWidget.block(height: 300);
          }
          final admin = snapshot.data;
          if (admin == null || !admin.isActive) {
            return const SafeArea(
              child: EmptyStateWidget(
                icon: Symbols.block_rounded,
                title: 'No access',
                message:
                    'This account doesn\'t have an active Admin Portal role.',
              ),
            );
          }

          final canManageContent =
              admin.role == AdminRole.admin || admin.role == AdminRole.lgu;
          final isAdmin = admin.role == AdminRole.admin;
          final tiles = <Widget>[
            if (canManageContent) ...[
              _AdminModuleTile(
                icon: Symbols.public_rounded,
                label: 'Provinces',
                subtitle:
                    'Write overview, culture, tips, hotlines and budget guidance',
                onTap: () => context.push(RoutePaths.adminProvinces),
              ),
              _AdminModuleTile(
                icon: Symbols.edit_note_rounded,
                label: 'Bulk Fill Province Content',
                subtitle:
                    'Fill overview/culture/budget for many provinces from a CSV',
                onTap: () => context.push(RoutePaths.adminBulkProvinceContent),
              ),
              _AdminModuleTile(
                icon: Symbols.place_rounded,
                label: 'Tourist Spots',
                subtitle: 'Add, edit or remove destinations shown to travelers',
                onTap: () => context.push(RoutePaths.adminTouristSpots),
              ),
              _AdminModuleTile(
                icon: Symbols.upload_file_rounded,
                label: 'Bulk Import',
                subtitle: 'Create many tourist spots at once from a CSV file',
                onTap: () => context.push(RoutePaths.adminBulkImport),
              ),
              _AdminModuleTile(
                icon: Symbols.celebration_rounded,
                label: 'Festivals',
                subtitle: 'Add, edit or remove festivals shown to travelers',
                onTap: () => context.push(RoutePaths.adminFestivals),
              ),
            ],
            if (admin.role == AdminRole.businessOwner)
              _AdminModuleTile(
                icon: Symbols.storefront_rounded,
                label: 'My Business',
                subtitle:
                    'Submit or edit your business listing for admin approval',
                onTap: () => context.push(RoutePaths.myBusiness),
              ),
            if (canManageContent)
              _AdminModuleTile(
                icon: Symbols.analytics_rounded,
                label: 'Analytics',
                subtitle: isAdmin
                    ? 'Traveler, content, business and engagement stats'
                    : 'Content and engagement stats for ${admin.provinceName ?? 'your province'}',
                onTap: () => context.push(RoutePaths.adminAnalytics),
              ),
            if (isAdmin)
              _AdminModuleTile(
                icon: Symbols.person_search_rounded,
                label: 'Travelers',
                subtitle: 'Search and suspend/reactivate traveler accounts',
                onTap: () => context.push(RoutePaths.adminUsers),
              ),
            if (isAdmin)
              _AdminModuleTile(
                icon: Symbols.storefront_rounded,
                label: 'Businesses',
                subtitle:
                    'Approve, reject or suspend business owner submissions',
                onTap: () => context.push(RoutePaths.adminBusinesses),
              ),
            if (isAdmin)
              _AdminModuleTile(
                icon: Symbols.flag_rounded,
                label: 'Reported Reviews',
                subtitle: 'Moderate reviews travelers have flagged',
                onTap: () => context.push(RoutePaths.adminReportedReviews),
              ),
            if (canManageContent)
              _AdminModuleTile(
                icon: Symbols.campaign_rounded,
                label: 'Send Announcement',
                subtitle: 'Broadcast a notification to every traveler',
                onTap: () => context.push(RoutePaths.adminBroadcast),
              ),
            if (isAdmin)
              _AdminModuleTile(
                icon: Symbols.group_rounded,
                label: 'Team',
                subtitle: 'Invite or manage Admin Portal accounts',
                onTap: () => context.push(
                  RoutePaths.adminTeam,
                  extra: {
                    'uid': uid,
                    'name': admin.name.isNotEmpty ? admin.name : admin.email,
                  },
                ),
              ),
          ];

          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Text(
                  'Signed in as ${admin.name.isNotEmpty ? admin.name : admin.email}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  admin.provinceName != null
                      ? 'Role: ${admin.role} · Managing ${admin.provinceName}'
                      : 'Role: ${admin.role}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                if (tiles.isEmpty)
                  EmptyStateWidget(
                    icon: Symbols.construction_rounded,
                    title: 'Nothing here yet',
                    message:
                        'The ${admin.role} workflow hasn\'t been built in this Admin Portal yet.',
                  )
                else
                  for (var i = 0; i < tiles.length; i++) ...[
                    tiles[i],
                    if (i != tiles.length - 1)
                      const SizedBox(height: AppSpacing.sm),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AdminModuleTile extends StatelessWidget {
  const _AdminModuleTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(subtitle, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            const Icon(
              Symbols.chevron_right_rounded,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
