import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_exception.dart';
import '../../core/widgets/dialogs/confirmation_dialog.dart';
import '../../core/widgets/states/empty_state_widget.dart';
import '../../data/repositories/business_repository.dart';
import '../../domain/models/business.dart';

/// Admin-only approval queue for `businessOwner` self-service listings —
/// approve, reject (with a reason the owner sees), suspend an already
/// -approved listing, or remove one outright.
class AdminBusinessListScreen extends StatefulWidget {
  const AdminBusinessListScreen({super.key});

  @override
  State<AdminBusinessListScreen> createState() => _AdminBusinessListScreenState();
}

class _AdminBusinessListScreenState extends State<AdminBusinessListScreen> {
  final BusinessRepository _repository = BusinessRepository();

  Future<void> _approve(Business business) async {
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Approve this listing?',
      message: '"${business.name}" will become visible to travelers on its province page.',
      confirmLabel: 'Approve',
    );
    if (!confirmed || !mounted) return;
    await _run(() => _repository.setStatus(business.id, status: 'approved'));
  }

  Future<void> _reject(Business business) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject this listing?'),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Tell the owner what to fix...', alignLabelWithHint: true),
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
    if (reason == null || reason.isEmpty || !mounted) return;
    await _run(() => _repository.setStatus(business.id, status: 'rejected', rejectionReason: reason));
  }

  Future<void> _suspend(Business business) async {
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Suspend this listing?',
      message: '"${business.name}" will be hidden from travelers until reactivated.',
      confirmLabel: 'Suspend',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    await _run(() => _repository.setStatus(business.id, status: 'suspended'));
  }

  Future<void> _reactivate(Business business) async {
    await _run(() => _repository.setStatus(business.id, status: 'approved'));
  }

  Future<void> _delete(Business business) async {
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Delete this listing?',
      message: '"${business.name}" will be permanently removed.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    await _run(() => _repository.delete(business.id));
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppException.from(e).message)));
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return AppColors.success;
      case 'rejected':
      case 'suspended':
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Businesses')),
      body: SafeArea(
        child: StreamBuilder<List<Business>>(
          stream: _repository.streamAllForAdmin(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final businesses = snapshot.data ?? const [];
            if (businesses.isEmpty) {
              return const EmptyStateWidget(icon: Symbols.storefront_rounded, title: 'No business listings yet', message: 'Submissions from business owner accounts will show up here.');
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.huge),
              itemCount: businesses.length,
              itemBuilder: (context, i) {
                final business = businesses[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(business.name, style: Theme.of(context).textTheme.titleMedium)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: _statusColor(business.status).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.sm)),
                              child: Text(business.status, style: TextStyle(color: _statusColor(business.status), fontSize: 12, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                        Text('${BusinessCategory.label(business.category)} · ${business.provinceName}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary)),
                        const SizedBox(height: 4),
                        Text(business.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                        if (business.isRejected && business.rejectionReason.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text('Reason: ${business.rejectionReason}', style: const TextStyle(color: AppColors.error, fontSize: 12)),
                        ],
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.sm,
                          children: [
                            if (business.isPending) ...[
                              FilledButton(onPressed: () => _approve(business), child: const Text('Approve')),
                              OutlinedButton(onPressed: () => _reject(business), child: const Text('Reject')),
                            ],
                            if (business.isApproved)
                              OutlinedButton(onPressed: () => _suspend(business), child: const Text('Suspend')),
                            if (business.isSuspended)
                              FilledButton(onPressed: () => _reactivate(business), child: const Text('Reactivate')),
                            IconButton(icon: const Icon(Symbols.delete_outline_rounded, color: AppColors.error), onPressed: () => _delete(business)),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
