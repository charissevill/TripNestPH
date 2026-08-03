import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/dialogs/confirmation_dialog.dart';
import '../../core/widgets/states/empty_state_widget.dart';
import '../../core/widgets/states/loading_widget.dart';
import '../../data/repositories/admin_repository.dart';
import '../../data/repositories/province_repository.dart';
import '../../domain/models/admin_invite.dart';
import '../../domain/models/admin_user.dart';
import '../../domain/models/province.dart';

/// Admin-only: the Admin Portal's own roster, plus staging invites for new
/// accounts. Replaces having to run `tool/create_admin.js` for every new
/// LGU/business-owner account — the invited person still
/// has to sign up for an ordinary TripNest account first (there's no
/// server-side Auth account creation here), but role-granting itself is
/// now fully in-app.
class AdminTeamScreen extends StatefulWidget {
  const AdminTeamScreen({
    super.key,
    required this.currentUid,
    required this.currentAdminName,
  });

  final String currentUid;
  final String currentAdminName;

  @override
  State<AdminTeamScreen> createState() => _AdminTeamScreenState();
}

class _AdminTeamScreenState extends State<AdminTeamScreen> {
  final AdminRepository _repository = AdminRepository();

  Future<void> _invite() async {
    final emailController = TextEditingController();
    final dialogFormKey = GlobalKey<FormState>();
    String role = AdminRole.lgu;
    Province? province;
    final provinces = (await ProvinceRepository().getAll())
      ..sort((a, b) => a.name.compareTo(b.name));
    if (!mounted) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Invite to Admin Portal'),
          content: SingleChildScrollView(
            child: Form(
              key: dialogFormKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: emailController,
                    autofocus: true,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'Must already have a TripNest account',
                      prefixIcon: Icon(Symbols.mail_rounded, size: 20),
                    ),
                    validator: Validators.email,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: const [
                      DropdownMenuItem(
                        value: AdminRole.admin,
                        child: Text('Admin'),
                      ),
                      DropdownMenuItem(
                        value: AdminRole.lgu,
                        child: Text('LGU Officer'),
                      ),
                      DropdownMenuItem(
                        value: AdminRole.businessOwner,
                        child: Text('Business Owner'),
                      ),
                    ],
                    onChanged: (value) => setDialogState(() {
                      role = value ?? role;
                      if (role != AdminRole.lgu) province = null;
                    }),
                  ),
                  // An LGU account is scoped to exactly one province — see
                  // `AdminUser.provinceId`'s doc comment — so this is required
                  // (not optional) whenever that role is picked above.
                  if (role == AdminRole.lgu) ...[
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<Province>(
                      initialValue: province,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Province',
                        hintText: 'Which province will they manage?',
                        prefixIcon: Icon(Symbols.public_rounded, size: 20),
                      ),
                      items: provinces
                          .map(
                            (p) =>
                                DropdownMenuItem(value: p, child: Text(p.name)),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => province = value),
                      validator: (v) => v == null
                          ? 'Pick the province this officer manages'
                          : null,
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (!dialogFormKey.currentState!.validate()) return;
                Navigator.of(context).pop(true);
              },
              child: const Text('Send Invite'),
            ),
          ],
        ),
      ),
    );
    if (result != true || !mounted) return;

    final email = emailController.text.trim();
    final selectedProvince = province;
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Invite $email?',
      message: role == AdminRole.lgu
          ? 'They\'ll be offered the "LGU Officer" role for ${selectedProvince?.name} next time they open the app with that email — only if they already have a TripNest account.'
          : 'They\'ll be offered the "$role" role next time they open the app with that email — only if they already have a TripNest account.',
      confirmLabel: 'Invite',
    );
    if (!confirmed || !mounted) return;
    try {
      await _repository.createInvite(
        email: email,
        role: role,
        invitedByName: widget.currentAdminName,
        provinceId: selectedProvince?.id,
        provinceName: selectedProvince?.name,
      );
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Invite sent.')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppException.from(e).message)));
    }
  }

  Future<void> _revokeInvite(AdminInvite invite) async {
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Revoke this invite?',
      message:
          '${invite.email} will no longer be offered the "${invite.role}" role.',
      confirmLabel: 'Revoke',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    try {
      await _repository.revokeInvite(invite.email);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppException.from(e).message)));
    }
  }

  Future<void> _toggleSuspend(AdminUser admin) async {
    final suspending = admin.isActive;
    final confirmed = await showConfirmationDialog(
      context,
      title: suspending ? 'Suspend this account?' : 'Reactivate this account?',
      message: suspending
          ? '${admin.name.isNotEmpty ? admin.name : admin.email} will immediately lose Admin Portal access.'
          : '${admin.name.isNotEmpty ? admin.name : admin.email} will regain Admin Portal access.',
      confirmLabel: suspending ? 'Suspend' : 'Reactivate',
      isDestructive: suspending,
    );
    if (!confirmed || !mounted) return;
    try {
      await _repository.setStatus(
        admin.uid,
        suspending ? 'suspended' : 'active',
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppException.from(e).message)));
    }
  }

  Future<void> _remove(AdminUser admin) async {
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Remove this admin?',
      message:
          '${admin.name.isNotEmpty ? admin.name : admin.email} will permanently lose Admin Portal access. Their traveler account is unaffected.',
      confirmLabel: 'Remove',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    try {
      await _repository.removeAdmin(admin.uid);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppException.from(e).message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Team'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _invite,
        icon: const Icon(Symbols.person_add_rounded),
        label: const Text('Invite'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.huge,
          ),
          children: [
            StreamBuilder<List<AdminInvite>>(
              stream: _repository.streamInvites(),
              builder: (context, snapshot) {
                final invites = snapshot.data ?? const [];
                if (invites.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pending Invites', style: theme.textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.sm),
                    ...invites.map(
                      (invite) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Symbols.hourglass_top_rounded,
                          color: AppColors.warning,
                        ),
                        title: Text(invite.email),
                        subtitle: Text(
                          'Staged as ${invite.role}'
                          '${invite.provinceName != null ? ' · ${invite.provinceName}' : ''}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Symbols.close_rounded),
                          onPressed: () => _revokeInvite(invite),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                );
              },
            ),
            Text('Team', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            StreamBuilder<List<AdminUser>>(
              stream: _repository.streamAll(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Column(
                    children: List.generate(
                      3,
                      (_) => LoadingWidget.textTile(leadingCircle: true),
                    ),
                  );
                }
                final admins = snapshot.data ?? const [];
                if (admins.isEmpty)
                  return const EmptyStateWidget(
                    icon: Symbols.group_rounded,
                    title: 'No admins yet',
                    message: '',
                  );
                return Column(
                  children: admins.map((admin) {
                    final isSelf = admin.uid == widget.currentUid;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        admin.isActive
                            ? Symbols.account_circle_rounded
                            : Symbols.block_rounded,
                        color: admin.isActive
                            ? Theme.of(context).colorScheme.primary
                            : AppColors.error,
                      ),
                      title: Text(
                        admin.name.isNotEmpty ? admin.name : admin.email,
                      ),
                      subtitle: Text(
                        '${admin.role}'
                        '${admin.provinceName != null ? ' · ${admin.provinceName}' : ''}'
                        '${admin.isActive ? '' : ' · suspended'}',
                      ),
                      trailing: isSelf
                          ? const Text(
                              'You',
                              style: TextStyle(color: AppColors.textTertiary),
                            )
                          : PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'toggle') _toggleSuspend(admin);
                                if (value == 'remove') _remove(admin);
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'toggle',
                                  child: Text(
                                    admin.isActive ? 'Suspend' : 'Reactivate',
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'remove',
                                  child: Text('Remove'),
                                ),
                              ],
                            ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
