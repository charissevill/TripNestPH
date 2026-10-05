import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/routes/back_navigation.dart';
import '../../core/routes/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_exception.dart';
import '../../core/widgets/dialogs/confirmation_dialog.dart';
import '../../core/widgets/states/empty_state_widget.dart';
import '../../core/widgets/states/loading_widget.dart';
import '../../data/repositories/business_owner_application_repository.dart';
import '../../domain/models/business.dart';
import '../../domain/models/business_owner_application.dart';

/// Admin-only queue for [BusinessOwnerApplication]s — approving one stages
/// an `admin_invites` entry for the applicant (see the repository's
/// `approve` doc comment), it never grants `businessOwner` directly.
class AdminBusinessOwnerApplicationsScreen extends StatefulWidget {
  const AdminBusinessOwnerApplicationsScreen({super.key});

  @override
  State<AdminBusinessOwnerApplicationsScreen> createState() =>
      _AdminBusinessOwnerApplicationsScreenState();
}

class _AdminBusinessOwnerApplicationsScreenState extends State<AdminBusinessOwnerApplicationsScreen> {
  final _repository = BusinessOwnerApplicationRepository();

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppException.from(e).message)));
      }
    }
  }

  Future<void> _approve(BusinessOwnerApplication application) async {
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Approve this application?',
      message:
          '${application.applicantName} will be invited to accept Business Owner access — they still need to accept it on their Profile screen.',
      confirmLabel: 'Approve',
    );
    if (!confirmed || !mounted) return;
    final adminName = context.read<AuthProvider>().currentUser?.name ?? '';
    await _run(() => _repository.approve(application, adminName: adminName));
  }

  Future<String?> _promptReason() async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        // Scrolls on a short viewport (landscape, keyboard open) instead of overflowing.
        scrollable: true,
        title: const Text('Reject this application?'),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Tell the applicant why...',
            alignLabelWithHint: true,
            prefixIcon: Icon(Symbols.edit_note_rounded, size: 20),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              final text = reasonController.text.trim();
              if (text.isEmpty) return;
              Navigator.of(context).pop(text);
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    return (reason == null || reason.isEmpty) ? null : reason;
  }

  Future<void> _reject(BusinessOwnerApplication application) async {
    final reason = await _promptReason();
    if (reason == null || !mounted) return;
    await _run(() => _repository.reject(application.id, reason));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Explicit rather than the implied arrow, which vanished whenever
        // the desktop sidebar opened this screen with `go` — every other
        // admin section keeps its Back button there.
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back_rounded),
          onPressed: () => context.popOrGo(RoutePaths.adminHome),
        ),
        title: const Text('Business Applications'),
      ),
      body: SafeArea(
        child: StreamBuilder<List<BusinessOwnerApplication>>(
          stream: _repository.streamPendingForAdmin(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return LoadingWidget.block(height: 300);
            }
            final applications = snapshot.data ?? const [];
            if (applications.isEmpty) {
              return const EmptyStateWidget(
                icon: Symbols.storefront_rounded,
                title: 'No pending applications',
                message: 'New Business Owner applications will show up here.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: applications.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, i) => _ApplicationCard(
                application: applications[i],
                onApprove: () => _approve(applications[i]),
                onReject: () => _reject(applications[i]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({required this.application, required this.onApprove, required this.onReject});

  final BusinessOwnerApplication application;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(application.businessName, style: theme.textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(BusinessCategory.label(application.category), style: theme.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.sm),
          Text('${application.applicantName} · ${application.applicantEmail}', style: theme.textTheme.bodySmall),
          if (application.phone.isNotEmpty) Text(application.phone, style: theme.textTheme.bodySmall),
          if (application.description.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(application.description, style: theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton(onPressed: onApprove, child: const Text('Approve')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
