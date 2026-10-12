import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/services/local_preferences_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_exception.dart';
import '../../core/widgets/dialogs/confirmation_dialog.dart';
import '../../core/widgets/states/empty_state_widget.dart';
import '../../core/widgets/states/loading_widget.dart';
import '../../data/repositories/notification_repository.dart';
import '../../domain/models/app_notification.dart';
import '../../core/routes/back_navigation.dart';
import '../../core/routes/route_paths.dart';

/// Festival announcements, travel tips and featured-destination alerts —
/// the in-app inbox backing push notifications.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final LocalPreferencesService _preferences = LocalPreferencesService();
  final NotificationRepository _repository = NotificationRepository();
  Set<String> _disabledCategories = const {};

  // Held in state rather than created in build(), so a setState here
  // doesn't resubscribe and flash the loading skeleton.
  String? _streamUid;
  Stream<List<AppNotification>>? _stream;

  /// Ids deleted from this screen that [_stream] hasn't dropped yet. A
  /// swiped-away [Dismissible] has to leave the list in that same frame,
  /// before Firestore reports the delete back.
  final Set<String> _removingIds = {};

  @override
  void initState() {
    super.initState();
    _preferences.getDisabledCategories().then((disabled) {
      if (mounted) setState(() => _disabledCategories = disabled);
    });
  }

  Stream<List<AppNotification>> _streamFor(String uid) {
    if (_streamUid != uid) {
      _streamUid = uid;
      _stream = _repository.streamForUser(uid);
    }
    return _stream!;
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

  Future<void> _delete(List<AppNotification> notifications, String uid) async {
    final ids = notifications.map((n) => n.id).toSet();
    setState(() => _removingIds.addAll(ids));
    try {
      await _repository.deleteAll(notifications, uid);
    } catch (e) {
      if (!mounted) return;
      // Put them back — nothing was actually removed.
      setState(() => _removingIds.removeAll(ids));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppException.from(e).message)));
    }
  }

  Future<void> _clearAll(
    List<AppNotification> notifications,
    String uid,
  ) async {
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Clear All Notifications?',
      message:
          'This removes every notification from your inbox. This can\'t be undone.',
      confirmLabel: 'Clear all',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    await _delete(notifications, uid);
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().firebaseUser?.uid;

    return StreamBuilder<List<AppNotification>>(
      stream: uid == null ? null : _streamFor(uid),
      builder: (context, snapshot) {
        final notifications = (snapshot.data ?? const <AppNotification>[])
            .where(
              (n) =>
                  !_disabledCategories.contains(n.category.name) &&
                  !_removingIds.contains(n.id),
            )
            .toList();

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Symbols.arrow_back_rounded),
              onPressed: () => context.popOrGo(RoutePaths.home),
            ),
            title: const Text('Notifications'),
            actions: [
              if (uid != null && notifications.isNotEmpty)
                TextButton(
                  onPressed: () => _clearAll(notifications, uid),
                  child: const Text('Clear all'),
                ),
            ],
          ),
          body: uid == null
              ? const EmptyStateWidget(
                  icon: Symbols.notifications_rounded,
                  title: 'Sign in required',
                  message: 'Sign in to view your notifications.',
                )
              : _buildBody(snapshot, notifications, uid),
        );
      },
    );
  }

  Widget _buildBody(
    AsyncSnapshot<List<AppNotification>> snapshot,
    List<AppNotification> notifications,
    String uid,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return ListView(
        children: List.generate(
          6,
          (_) => LoadingWidget.textTile(leadingCircle: true),
        ),
      );
    }
    if (notifications.isEmpty) {
      return const EmptyStateWidget(
        icon: Symbols.notifications_rounded,
        title: 'You\'re all caught up',
        message: 'Festival announcements and travel tips will show up here.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: notifications.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, i) => _buildTile(notifications[i], uid),
    );
  }

  Widget _buildTile(AppNotification notification, String uid) {
    final theme = Theme.of(context);
    final isRead = notification.isReadBy(uid);
    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _delete([notification], uid),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: const Icon(Symbols.delete_rounded, color: Colors.white),
      ),
      child: InkWell(
        onTap: () => _repository.markAsRead(notification, uid),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: isRead
                ? theme.colorScheme.surface
                : theme.colorScheme.primary.withValues(alpha: 0.06),
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
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
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
                    Text(notification.body, style: theme.textTheme.bodySmall),
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
              IconButton(
                icon: const Icon(Symbols.delete_rounded, size: 20),
                tooltip: 'Delete',
                visualDensity: VisualDensity.compact,
                color: theme.colorScheme.onSurfaceVariant,
                onPressed: () => _delete([notification], uid),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
