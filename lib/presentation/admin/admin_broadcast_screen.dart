import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/buttons/animated_button.dart';
import '../../core/widgets/dialogs/confirmation_dialog.dart';
import '../../core/widgets/dialogs/discard_changes_scope.dart';
import '../../data/repositories/admin_repository.dart';
import '../../data/repositories/notification_repository.dart';
import '../../domain/models/admin_user.dart';
import '../../domain/models/app_notification.dart';
import 'widgets/admin_page_header.dart';

/// Compose an in-app announcement. From an admin it's delivered instantly
/// to every traveler's notification bell; from an LGU account it only goes
/// to travelers with a saved trip or a favorite in that LGU's province (see
/// `NotificationRepository.createProvinceAnnouncement`).
/// An admin's write also triggers a real OS-level push via the
/// `sendPushOnNotificationCreated` Cloud Function (confirmed firing with a
/// direct Cloud Run log check — see `functions/index.js`); if push delivery
/// were ever to fail, this still reaches every traveler next time they open
/// the app or the notification bell.
class AdminBroadcastScreen extends StatefulWidget {
  const AdminBroadcastScreen({super.key});

  @override
  State<AdminBroadcastScreen> createState() => _AdminBroadcastScreenState();
}

class _AdminBroadcastScreenState extends State<AdminBroadcastScreen> {
  final NotificationRepository _repository = NotificationRepository();
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  NotificationCategory _category = NotificationCategory.general;
  bool _sending = false;
  bool _dirty = false;

  /// Re-fetched live rather than trusted from the caller, same reasoning as
  /// `AdminProvinceListScreen._admin`. Null until it loads — sending waits
  /// for it, since it decides who the announcement goes to.
  AdminUser? _admin;

  /// The one province an LGU account announces to; null for an admin, whose
  /// announcements go nationwide.
  String? get _provinceId =>
      _admin?.role == AdminRole.lgu ? _admin?.provinceId : null;

  String get _provinceName => _admin?.provinceName ?? 'your province';

  @override
  void initState() {
    super.initState();
    for (final c in [_titleController, _bodyController]) {
      c.addListener(() => setState(() => _dirty = true));
    }
    _loadAdmin();
  }

  Future<void> _loadAdmin() async {
    final uid = context.read<AuthProvider>().firebaseUser?.uid;
    if (uid == null) return;
    try {
      final admin = await AdminRepository().getById(uid);
      if (mounted) setState(() => _admin = admin);
    } catch (_) {
      // Stays null: the Send button keeps waiting rather than guessing an
      // audience.
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    final admin = _admin;
    if (admin == null) return;
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    final provinceId = _provinceId;
    if (admin.role == AdminRole.lgu && provinceId == null) return;
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Send this announcement?',
      message: provinceId != null
          ? 'It goes out right away to travelers with a saved trip or a favorite in $_provinceName, and can\'t be recalled.'
          : 'It goes out to every traveler right away and can\'t be recalled.',
      confirmLabel: 'Send',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _sending = true);
    try {
      if (provinceId != null) {
        await _repository.createProvinceAnnouncement(
          provinceId: provinceId,
          provinceName: admin.provinceName ?? '',
          createdBy: admin.uid,
          title: title,
          body: body,
          category: _category,
        );
      } else {
        await _repository.createBroadcast(
          title: title,
          body: body,
          category: _category,
        );
      }
      if (mounted) {
        _dirty = false;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Announcement sent.')));
        context.pop();
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppException.from(e).message)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DiscardChangesScope(
      isDirty: _dirty,
      child: Scaffold(
        appBar: adminPageHeader(
          context,
          title: 'Announcement',
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.huge,
              ),
              children: [
                if (_provinceId != null) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Symbols.info_rounded, size: 18),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          'Only travelers with a saved trip or a favorite in $_provinceName receive this.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                TextFormField(
                  controller: _titleController,
                  maxLength: 100,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    prefixIcon: Icon(Symbols.title_rounded, size: 20),
                  ),
                  validator: (v) => Validators.required(v, label: 'Title'),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _bodyController,
                  maxLines: 4,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Symbols.message_rounded, size: 20),
                  ),
                  validator: (v) => Validators.required(v, label: 'Message'),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<NotificationCategory>(
                  initialValue: _category,
                  // Fills the field so a long category name truncates instead
                  // of overflowing on a narrow screen.
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: NotificationCategory.values
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text(c.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() {
                    _category = value ?? _category;
                    _dirty = true;
                  }),
                ),
                const SizedBox(height: AppSpacing.xxl),
                AnimatedButton(
                  label: _provinceId != null
                      ? 'Send to $_provinceName Travelers'
                      : 'Send to Every Traveler',
                  isLoading: _sending || _admin == null,
                  onPressed: _send,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
