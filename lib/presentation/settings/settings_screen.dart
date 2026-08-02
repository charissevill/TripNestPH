import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_strings.dart';
import '../../core/providers/accent_color_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/theme_mode_provider.dart';
import '../../core/providers/typography_provider.dart';
import '../../core/routes/route_paths.dart';
import '../../core/services/local_preferences_service.dart';
import '../../core/services/location_service.dart';
import '../../core/theme/accent_colors.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/typography_options.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/dialogs/confirmation_dialog.dart';
import '../../core/widgets/dialogs/credential_dialog.dart';
import '../../data/repositories/user_repository.dart';
import '../../domain/models/app_notification.dart';

const List<NotificationCategory> _toggleableCategories = [
  NotificationCategory.festival,
  NotificationCategory.featuredDestination,
  NotificationCategory.travelTip,
  NotificationCategory.general,
];

/// App preferences: dark mode, notifications, location, privacy and about.
/// Dark mode, notifications and location persist locally across restarts.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final LocalPreferencesService _preferences = LocalPreferencesService();
  final LocationService _locationService = LocationService();
  final UserRepository _userRepository = UserRepository();
  bool _notificationsEnabled = true;
  bool _locationEnabled = true;
  bool _clearingHistory = false;
  Set<String> _disabledCategories = {};

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final notifications = await _preferences.getNotificationsEnabled();
    final locationEnabled = await _preferences.getLocationFeatureEnabled();
    final disabledCategories = await _preferences.getDisabledCategories();
    if (!mounted) return;
    setState(() {
      _notificationsEnabled = notifications;
      _locationEnabled = locationEnabled;
      _disabledCategories = disabledCategories;
    });
  }

  Future<void> _pickThemePreset(BuildContext context, AccentColorProvider provider) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      // Without this, a modal sheet is pre-capped at 9/16 of the screen
      // height regardless of content — too tight for 7 rows of swatches +
      // two-line descriptions, which is what caused the bottom overflow.
      isScrollControlled: true,
      builder: (context) => Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
        child: SafeArea(
          child: ConstrainedBox(
            // Bounds the whole sheet (header + list together) to a real
            // max height, so the Column below sizes to content when it
            // fits and the list scrolls internally when it doesn't —
            // rather than bounding just the list to a number computed
            // without accounting for the header or the sheet's own cap.
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.outline,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                  ),
                  Text('Theme', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: AppSpacing.sm),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: themePresets.length,
                      separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.divider),
                      itemBuilder: (context, i) {
                        final option = themePresets[i];
                        final selected = option.name == provider.preset.name;
                        final theme = Theme.of(context);
                        return InkWell(
                          onTap: () {
                            provider.setPreset(option);
                            Navigator.of(context).pop();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                            child: Row(
                              children: [
                                // The 4-shade scale (darkest -> lightest),
                                // shown as a strip so the traveler can
                                // actually see the palette, not just its
                                // main accent.
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: option.previewShades
                                      .map(
                                        (shade) => Container(
                                          width: 18,
                                          height: 36,
                                          margin: const EdgeInsets.only(right: 2),
                                          decoration: BoxDecoration(
                                            color: shade,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        option.name,
                                        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                                      ),
                                      Text(
                                        option.description,
                                        style: theme.textTheme.bodySmall,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                if (selected)
                                  Icon(Symbols.check_circle_rounded, color: theme.colorScheme.primary)
                                else
                                  const Icon(Symbols.chevron_right_rounded, color: AppColors.textTertiary),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickFontFamily(BuildContext context, TypographyProvider provider) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outline,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
              Text('Font Style', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.md),
              ...fontFamilyOptions.map((option) {
                final selected = option.familyName == provider.fontFamily;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: () {
                    provider.setFontFamily(option.familyName);
                    Navigator.of(context).pop();
                  },
                  title: Text(option.name, style: GoogleFonts.getFont(option.familyName, fontSize: 16)),
                  trailing: selected ? Icon(Symbols.check_rounded, color: Theme.of(context).colorScheme.primary) : null,
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickFontSize(BuildContext context, TypographyProvider provider) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outline,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
              Text('Text Size', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.md),
              ...fontSizeOptions.map((option) {
                final selected = option.scale == provider.fontScale;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: () {
                    provider.setFontScale(option.scale);
                    Navigator.of(context).pop();
                  },
                  title: Text('The quick brown fox', style: TextStyle(fontSize: 16 * option.scale)),
                  subtitle: Text(option.name),
                  trailing: selected ? Icon(Symbols.check_rounded, color: Theme.of(context).colorScheme.primary) : null,
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _setCategoryEnabled(NotificationCategory category, bool enabled) {
    setState(() {
      enabled ? _disabledCategories.remove(category.name) : _disabledCategories.add(category.name);
    });
    _preferences.setCategoryEnabled(category.name, enabled);
  }

  Future<void> _setLocationEnabled(bool value) async {
    setState(() => _locationEnabled = value);
    await _preferences.setLocationFeatureEnabled(value);
    if (!value) return;

    // Turning it back on should feel responsive — check right away rather
    // than waiting for the traveler to revisit Home.
    final result = await _locationService.resolveCurrentPosition();
    if (!mounted) return;
    if (result.status == LocationAccessStatus.permissionDeniedForever || result.status == LocationAccessStatus.serviceDisabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Location access is off at the system level. Enable it in your device settings.'),
          action: SnackBarAction(
            label: 'Open Settings',
            onPressed: result.status == LocationAccessStatus.serviceDisabled
                ? _locationService.openLocationSettings
                : _locationService.openAppSettings,
          ),
        ),
      );
    }
  }

  Future<void> _changePassword() async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => CredentialDialog(
        title: 'Change Password',
        fields: [
          CredentialField(
            label: 'Current Password',
            controller: currentPasswordController,
            obscure: true,
            icon: Symbols.lock_rounded,
            validator: (v) => (v == null || v.isEmpty) ? 'Current password is required' : null,
          ),
          CredentialField(
            label: 'New Password',
            controller: newPasswordController,
            obscure: true,
            icon: Symbols.lock_rounded,
            validator: Validators.password,
          ),
        ],
        onConfirm: () => context.read<AuthProvider>().changePassword(
              newPassword: newPasswordController.text,
              currentPassword: currentPasswordController.text,
            ),
      ),
    );
    if (!mounted) return;
    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated.')));
    }
  }

  Future<void> _clearRecentlyViewed() async {
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Clear Recently Viewed?',
      message: 'This removes your recently viewed destinations history. It doesn\'t affect your favorites or reviews.',
      confirmLabel: 'Clear',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    final uid = context.read<AuthProvider>().firebaseUser?.uid;
    if (uid == null) return;
    setState(() => _clearingHistory = true);
    try {
      await _userRepository.clearRecentlyViewed(uid);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recently viewed history cleared.')));
    } finally {
      if (mounted) setState(() => _clearingHistory = false);
    }
  }

  Future<void> _deleteAccount() async {
    final warned = await showConfirmationDialog(
      context,
      title: 'Delete your account?',
      message:
          'This permanently deletes your profile, favorites, saved itineraries, and reviews. This can\'t be undone.',
      confirmLabel: 'Continue',
      isDestructive: true,
    );
    if (!warned || !mounted) return;

    final passwordController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => CredentialDialog(
        title: 'Confirm Your Password',
        fields: [
          CredentialField(
            label: 'Current Password',
            controller: passwordController,
            obscure: true,
            icon: Symbols.lock_rounded,
            validator: (v) => (v == null || v.isEmpty) ? 'Current password is required' : null,
          ),
        ],
        confirmLabel: 'Delete Account',
        isDestructive: true,
        onConfirm: () => context.read<AuthProvider>().deleteAccount(currentPassword: passwordController.text),
      ),
    );
    if (result != true && mounted) {
      final error = context.read<AuthProvider>().errorMessage;
      if (error != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = context.watch<ThemeModeProvider>();
    final accentColorProvider = context.watch<AccentColorProvider>();
    final typographyProvider = context.watch<TypographyProvider>();
    final currentFontFamily = fontFamilyOptions.firstWhere((o) => o.familyName == typographyProvider.fontFamily);
    final currentFontSize = fontSizeOptions.firstWhere((o) => o.scale == typographyProvider.fontScale);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Symbols.arrow_back_rounded), onPressed: () => context.pop()),
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.huge),
        children: [
          _SettingsSectionLabel('Appearance'),
          _SettingsGroup(
            children: [
              _SwitchRow(
                icon: Symbols.dark_mode_rounded,
                label: 'Dark Mode',
                subtitle: 'Switch between light and dark theme',
                value: themeProvider.isDark,
                onChanged: themeProvider.setDark,
              ),
              const Divider(height: 1, color: AppColors.divider),
              _NavigationRow(
                icon: Symbols.palette_rounded,
                label: 'Theme',
                onTap: () => _pickThemePreset(context, accentColorProvider),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      accentColorProvider.preset.name,
                      style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textTertiary),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(color: accentColorProvider.preset.primary, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    const Icon(Symbols.chevron_right_rounded, color: AppColors.textTertiary),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              _NavigationRow(
                icon: Symbols.font_download_rounded,
                label: 'Font Style',
                onTap: () => _pickFontFamily(context, typographyProvider),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(currentFontFamily.name, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textTertiary)),
                    const SizedBox(width: AppSpacing.xs),
                    const Icon(Symbols.chevron_right_rounded, color: AppColors.textTertiary),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              _NavigationRow(
                icon: Symbols.format_size_rounded,
                label: 'Text Size',
                onTap: () => _pickFontSize(context, typographyProvider),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(currentFontSize.name, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textTertiary)),
                    const SizedBox(width: AppSpacing.xs),
                    const Icon(Symbols.chevron_right_rounded, color: AppColors.textTertiary),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          _SettingsSectionLabel('Preferences'),
          _SettingsGroup(
            children: [
              _SwitchRow(
                icon: Symbols.notifications_rounded,
                label: 'Notifications',
                subtitle: 'Trip reminders, festival alerts and offers',
                value: _notificationsEnabled,
                onChanged: (v) {
                  setState(() => _notificationsEnabled = v);
                  _preferences.setNotificationsEnabled(v);
                },
              ),
              const Divider(height: 1, color: AppColors.divider),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Opacity(
                  opacity: _notificationsEnabled ? 1 : 0.4,
                  child: IgnorePointer(
                    ignoring: !_notificationsEnabled,
                    child: Column(
                      children: [
                        for (final category in _toggleableCategories)
                          _CategorySwitchRow(
                            label: category.label,
                            value: !_disabledCategories.contains(category.name),
                            onChanged: (v) => _setCategoryEnabled(category, v),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: AppSpacing.sm),
                          child: Text(
                            'Emergency alerts and maintenance notices can\'t be turned off.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              _SwitchRow(
                icon: Symbols.my_location_rounded,
                label: 'Location Services',
                subtitle: 'Show nearby tourist spots based on your location',
                value: _locationEnabled,
                onChanged: _setLocationEnabled,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          _SettingsSectionLabel('Account'),
          _SettingsGroup(
            children: [
              _NavigationRow(
                icon: Symbols.lock_reset_rounded,
                label: 'Change Password',
                onTap: _changePassword,
              ),
              const Divider(height: 1, color: AppColors.divider),
              _NavigationRow(
                icon: Symbols.history_rounded,
                label: 'Clear Recently Viewed',
                onTap: _clearingHistory ? () {} : _clearRecentlyViewed,
                trailing: _clearingHistory
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : null,
              ),
              const Divider(height: 1, color: AppColors.divider),
              _NavigationRow(
                icon: Symbols.delete_forever_rounded,
                label: 'Delete Account',
                onTap: _deleteAccount,
                isDestructive: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          _SettingsSectionLabel('Legal & Support'),
          _SettingsGroup(
            children: [
              _NavigationRow(
                icon: Symbols.help_rounded,
                label: 'FAQ',
                onTap: () => context.push(RoutePaths.faq),
              ),
              const Divider(height: 1, color: AppColors.divider),
              _NavigationRow(
                icon: Symbols.privacy_tip_rounded,
                label: 'Privacy Policy',
                onTap: () => context.push(RoutePaths.legalInfo('privacy')),
              ),
              const Divider(height: 1, color: AppColors.divider),
              _NavigationRow(
                icon: Symbols.description_rounded,
                label: 'Terms of Service',
                onTap: () => context.push(RoutePaths.legalInfo('terms')),
              ),
              const Divider(height: 1, color: AppColors.divider),
              _NavigationRow(
                icon: Symbols.info_rounded,
                label: 'About TripNest PH',
                onTap: () => context.push(RoutePaths.legalInfo('about')),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          Center(
            child: InkWell(
              onTap: () => context.push(RoutePaths.whatsNew),
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                child: Text(
                  '${AppStrings.appName} · v1.0.0 · What\'s New',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSectionLabel extends StatelessWidget {
  const _SettingsSectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm, left: AppSpacing.xs),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 0.6),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 22),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodyLarge),
                Text(subtitle, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged, activeThumbColor: theme.colorScheme.primary),
        ],
      ),
    );
  }
}

/// A compact label + switch row for the per-category notification toggles —
/// like [_SwitchRow] but without an icon/subtitle, since these are nested
/// one level deeper under the main Notifications switch.
class _CategorySwitchRow extends StatelessWidget {
  const _CategorySwitchRow({required this.label, required this.value, required this.onChanged});

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
          Switch(value: value, onChanged: onChanged, activeThumbColor: Theme.of(context).colorScheme.primary),
        ],
      ),
    );
  }
}

class _NavigationRow extends StatelessWidget {
  const _NavigationRow({required this.icon, required this.label, required this.onTap, this.isDestructive = false, this.trailing});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isDestructive ? AppColors.error : theme.colorScheme.primary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(label, style: theme.textTheme.bodyLarge?.copyWith(color: isDestructive ? AppColors.error : null))),
            if (trailing != null)
              Padding(padding: const EdgeInsets.only(right: AppSpacing.sm), child: trailing!)
            else
              const Icon(Symbols.chevron_right_rounded, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
