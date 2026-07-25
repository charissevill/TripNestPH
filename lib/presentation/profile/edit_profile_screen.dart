import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/buttons/animated_button.dart';
import '../../core/widgets/dialogs/credential_dialog.dart';
import '../../core/widgets/media/avatar_preview.dart';
import '../../data/mock/mock_categories.dart';

const List<String> _travelPreferenceOptions = [
  'Beaches',
  'Mountains',
  'Food',
  'Hidden Gems',
  'Festivals',
  'Hiking',
  'Culture & Heritage',
  'Nature',
  'Nightlife',
];

/// Lets the signed-in traveler update their name, photo, travel
/// preferences, favorite categories, email and password.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final StorageService _storageService = StorageService();
  final ImagePicker _picker = ImagePicker();
  late final TextEditingController _nameController;
  late Set<String> _preferences;
  late Set<String> _categories;
  bool _saving = false;
  bool _uploadingPhoto = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    _nameController = TextEditingController(text: user?.name ?? '');
    _preferences = {...(user?.travelPreferences ?? const [])};
    _categories = {...(user?.favoriteCategories ?? const [])};
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 800,
    );
    if (picked == null || !mounted) return;
    final auth = context.read<AuthProvider>();
    final uid = auth.firebaseUser?.uid;
    if (uid == null) return;

    setState(() => _uploadingPhoto = true);
    try {
      final url = await _storageService.uploadFile(
        folder: FirestorePaths.storageProfilePhotos,
        ownerId: uid,
        file: File(picked.path),
      );
      await auth.updatePhotoUrl(url);
    } catch (e) {
      if (mounted) setState(() => _error = AppException.from(e).message);
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final auth = context.read<AuthProvider>();
    final ok = await auth.updateName(_nameController.text.trim());
    if (ok) {
      await auth.updateTravelPreferences(_preferences.toList());
      await auth.updateFavoriteCategories(_categories.toList());
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      context.pop();
    } else {
      setState(() => _error = auth.errorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Edit Profile'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.huge,
          ),
          children: [
            Center(
              child: Stack(
                children: [
                  AvatarPreview(
                    photoUrl: user?.photoUrl,
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      padding: const EdgeInsets.all(3),
                      child: ClipOval(
                        child: user?.photoUrl.isNotEmpty == true
                            ? CachedNetworkImage(
                                imageUrl: user!.photoUrl,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.12,
                                ),
                                child: Icon(
                                  Symbols.person_rounded,
                                  size: 48,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: InkWell(
                      onTap: _uploadingPhoto ? null : _pickPhoto,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: _uploadingPhoto
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Symbols.photo_camera_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            TextFormField(
              controller: _nameController,
              validator: Validators.name,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                floatingLabelBehavior: FloatingLabelBehavior.auto,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Travel Preferences', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: _travelPreferenceOptions
                  .map(
                    (p) => _SelectableChip(
                      label: p,
                      selected: _preferences.contains(p),
                      onTap: () => setState(
                        () => _preferences.contains(p)
                            ? _preferences.remove(p)
                            : _preferences.add(p),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Favorite Categories', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: mockCategories
                  .map(
                    (c) => _SelectableChip(
                      label: c.label,
                      selected: _categories.contains(c.id),
                      onTap: () => setState(
                        () => _categories.contains(c.id)
                            ? _categories.remove(c.id)
                            : _categories.add(c.id),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Security', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            _SecurityRow(
              icon: Symbols.mail_rounded,
              label: 'Update Email',
              onTap: _showChangeEmailDialog,
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(_error!, style: const TextStyle(color: AppColors.error)),
            ],
            const SizedBox(height: AppSpacing.xxl),
            AnimatedButton(
              label: 'Save Changes',
              isLoading: _saving,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showChangeEmailDialog() async {
    final currentEmail = context.read<AuthProvider>().currentUser?.email;
    final newEmailController = TextEditingController();
    final passwordController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => CredentialDialog(
        title: 'Update Email',
        fields: [
          CredentialField(
            label: 'New Email',
            controller: newEmailController,
            obscure: false,
            validator: (v) {
              final emailError = Validators.email(v);
              if (emailError != null) return emailError;
              if (v!.trim().toLowerCase() == currentEmail?.toLowerCase()) {
                return 'This is already your current email';
              }
              return null;
            },
          ),
          CredentialField(
            label: 'Current Password',
            controller: passwordController,
            obscure: true,
            validator: (v) => (v == null || v.isEmpty)
                ? 'Current password is required'
                : null,
          ),
        ],
        onConfirm: () => context.read<AuthProvider>().changeEmail(
          newEmail: newEmailController.text.trim(),
          currentPassword: passwordController.text,
        ),
      ),
    );
    if (!mounted) return;
    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Check your new email to confirm the change.'),
        ),
      );
    }
  }
}

class _SecurityRow extends StatelessWidget {
  const _SecurityRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 22),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
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

class _SelectableChip extends StatelessWidget {
  const _SelectableChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: selected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
