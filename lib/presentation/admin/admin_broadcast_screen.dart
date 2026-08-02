import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/buttons/animated_button.dart';
import '../../core/widgets/dialogs/confirmation_dialog.dart';
import '../../core/widgets/dialogs/discard_changes_scope.dart';
import '../../data/repositories/notification_repository.dart';
import '../../domain/models/app_notification.dart';

/// Compose an in-app announcement, delivered instantly to every traveler's
/// notification bell. The write also triggers a real OS-level push via the
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

  @override
  void initState() {
    super.initState();
    for (final c in [_titleController, _bodyController]) {
      c.addListener(() => setState(() => _dirty = true));
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
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Send this announcement?',
      message:
          'It goes out to every traveler right away and can\'t be recalled.',
      confirmLabel: 'Send',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _sending = true);
    try {
      await _repository.createBroadcast(
        title: title,
        body: body,
        category: _category,
      );
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
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Symbols.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
          title: const Text('Announcement'),
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
                TextFormField(
                  controller: _titleController,
                  maxLength: 100,
                  decoration: const InputDecoration(labelText: 'Title'),
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
                  ),
                  validator: (v) => Validators.required(v, label: 'Message'),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<NotificationCategory>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: NotificationCategory.values
                      .map(
                        (c) => DropdownMenuItem(value: c, child: Text(c.label)),
                      )
                      .toList(),
                  onChanged: (value) => setState(() {
                    _category = value ?? _category;
                    _dirty = true;
                  }),
                ),
                const SizedBox(height: AppSpacing.xxl),
                AnimatedButton(
                  label: 'Send to Every Traveler',
                  isLoading: _sending,
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
