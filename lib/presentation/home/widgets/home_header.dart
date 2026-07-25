import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// Personalized greeting row shown at the top of Home: time-aware salutation,
/// user's name, notification bell and avatar.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.userName,
    required this.avatarUrl,
    required this.onAvatarTap,
    required this.onBellTap,
    this.hasUnreadNotifications = false,
  });

  final String userName;
  final String avatarUrl;
  final VoidCallback onAvatarTap;
  final VoidCallback onBellTap;
  final bool hasUnreadNotifications;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$_greeting,', style: theme.textTheme.bodyMedium),
              Text('$userName 👋', style: theme.textTheme.headlineLarge),
            ],
          ),
        ),
        _IconBadgeButton(icon: Symbols.notifications_rounded, onTap: onBellTap, showBadge: hasUnreadNotifications),
        const SizedBox(width: AppSpacing.sm),
        GestureDetector(
          onTap: onAvatarTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: theme.colorScheme.primary, width: 2),
            ),
            padding: const EdgeInsets.all(2),
            child: ClipOval(
              child: avatarUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: avatarUrl,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => const _AvatarFallback(),
                    )
                  : const _AvatarFallback(),
            ),
          ),
        ),
      ],
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback();

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      color: primary.withValues(alpha: 0.1),
      child: Icon(Symbols.person_rounded, color: primary, size: 22),
    );
  }
}

class _IconBadgeButton extends StatelessWidget {
  const _IconBadgeButton({required this.icon, required this.onTap, this.showBadge = false});

  final IconData icon;
  final VoidCallback onTap;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Stack(
          children: [
            Center(child: Icon(icon, size: 22, color: AppColors.textPrimary)),
            if (showBadge)
              Positioned(
                top: 10,
                right: 11,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
