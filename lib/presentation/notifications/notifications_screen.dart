import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/services/local_preferences_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/states/empty_state_widget.dart';
import '../../core/widgets/states/loading_widget.dart';
import '../../data/repositories/notification_repository.dart';
import '../../domain/models/app_notification.dart';

/// Festival announcements, travel tips and featured-destination alerts —
/// the in-app inbox backing push notifications.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final LocalPreferencesService _preferences = LocalPreferencesService();
  Set<String> _disabledCategories = const {};

  @override
  void initState() {
    super.initState();
    _preferences.getDisabledCategories().then((disabled) {
      if (mounted) setState(() => _disabledCategories = disabled);
    });
  }

  IconData _iconFor(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.festival:
        return Symbols.celebration_rounded;
      case NotificationCategory.travelTip:
        return Symbols.lightbulb_rounded;
      case NotificationCategory.featuredDestination:
        return Symbols.travel_explore_rounded;
      case NotificationCategory.general:
        return Symbols.notifications_rounded;
      case NotificationCategory.maintenanceNotice:
        return Symbols.build_rounded;
      case NotificationCategory.emergencyAlert:
        return Symbols.emergency_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final uid = context.watch<AuthProvider>().firebaseUser?.uid;
    final repository = NotificationRepository();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Notifications'),
      ),
      body: uid == null
          ? const EmptyStateWidget(
              icon: Symbols.notifications_rounded,
              title: 'Sign in required',
              message: 'Sign in to view your notifications.',
            )
          : StreamBuilder<List<AppNotification>>(
              stream: repository.streamForUser(uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return ListView(
                    children: List.generate(
                      6,
                      (_) => LoadingWidget.textTile(leadingCircle: true),
                    ),
                  );
                }
                final notifications = (snapshot.data ?? const [])
                    .where(
                      (n) => !_disabledCategories.contains(n.category.name),
                    )
                    .toList();
                if (notifications.isEmpty) {
                  return const EmptyStateWidget(
                    icon: Symbols.notifications_rounded,
                    title: 'You\'re all caught up',
                    message:
                        'Festival announcements and travel tips will show up here.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: notifications.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) {
                    final notification = notifications[i];
                    final isRead = notification.isReadBy(uid);
                    return InkWell(
                      onTap: () => repository.markAsRead(notification, uid),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: isRead
                              ? theme.colorScheme.surface
                              : theme.colorScheme.primary.withValues(
                                  alpha: 0.06,
                                ),
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.12,
                                ),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                _iconFor(notification.category),
                                color: theme.colorScheme.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    notification.title,
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    notification.body,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            if (!isRead)
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(top: 4),
                                decoration: const BoxDecoration(
                                  color: AppColors.error,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
