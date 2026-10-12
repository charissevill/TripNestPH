import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/routes/back_navigation.dart';
import '../../core/routes/route_paths.dart';
import '../../core/services/itinerary_offline_service.dart';
import '../../core/services/local_preferences_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_exception.dart';
import '../../core/widgets/banners/offline_banner.dart';
import '../../core/widgets/dialogs/confirmation_dialog.dart';
import '../../core/widgets/states/empty_state_widget.dart';
import '../../core/widgets/states/loading_widget.dart';
import '../../data/repositories/expense_repository.dart';
import '../../data/repositories/itinerary_repository.dart';
import '../../domain/models/expense.dart';
import '../../domain/models/packing_item.dart';
import '../../domain/models/saved_itinerary.dart';
import 'trip_calendar_screen.dart';

/// Every trip the signed-in traveler has saved from the trip planner, plus
/// any trip a friend has shared with them — "View Saved Trips" from the
/// Profile screen.
class SavedItinerariesScreen extends StatefulWidget {
  const SavedItinerariesScreen({super.key});

  @override
  State<SavedItinerariesScreen> createState() => _SavedItinerariesScreenState();
}

class _SavedItinerariesScreenState extends State<SavedItinerariesScreen> {
  final LocalPreferencesService _preferencesService = LocalPreferencesService();
  final ItineraryOfflineService _offlineService = ItineraryOfflineService();

  Set<String> _offlineIds = {};
  final Set<String> _downloadingIds = {};

  @override
  void initState() {
    super.initState();
    _loadOfflineIds();
  }

  Future<void> _loadOfflineIds() async {
    final ids = await _preferencesService.getOfflineItineraryIds();
    if (mounted) setState(() => _offlineIds = ids);
  }

  Future<void> _saveOffline(SavedItinerary trip) async {
    setState(() => _downloadingIds.add(trip.id));
    try {
      await _offlineService.makeAvailableOffline(
        context: context,
        itineraryId: trip.id,
        itinerary: trip.itinerary,
      );
      if (!mounted) return;
      setState(() => _offlineIds = {..._offlineIds, trip.id});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${trip.title}" is now available offline.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppException.from(e).message)));
      }
    } finally {
      if (mounted) setState(() => _downloadingIds.remove(trip.id));
    }
  }

  Future<void> _confirmDelete(
    ItineraryRepository repository,
    SavedItinerary trip,
  ) async {
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Remove this trip?',
      message:
          '"${trip.title}" will be permanently removed from your saved trips.',
      confirmLabel: 'Remove',
      isDestructive: true,
    );
    if (confirmed) await repository.delete(trip.id);
  }

  Future<void> _duplicateTrip(
    ItineraryRepository repository,
    SavedItinerary trip,
    String uid,
  ) async {
    try {
      final ownerName = context.read<AuthProvider>().currentUser?.name ?? '';
      await repository.duplicate(trip.id, uid, ownerName: ownerName);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('"${trip.title}" duplicated.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppException.from(e).message)));
      }
    }
  }

  Future<void> _confirmLeave(
    ItineraryRepository repository,
    SavedItinerary trip,
    String uid,
  ) async {
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Leave this trip?',
      message:
          'You\'ll lose access to "${trip.title}" unless someone invites you again.',
      confirmLabel: 'Leave',
      isDestructive: true,
    );
    if (confirmed)
      await repository.leaveTrip(itineraryId: trip.id, userId: uid);
  }

  Future<void> _joinTrip(ItineraryRepository repository, String uid) async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        // Scrolls on a short viewport (landscape, keyboard open) instead of overflowing.
        scrollable: true,
        title: const Text('Join a Shared Trip'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Trip code',
            hintText: 'Paste the code your friend shared',
            prefixIcon: Icon(Symbols.key_rounded, size: 20),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Join'),
          ),
        ],
      ),
    );
    if (code == null || code.isEmpty || !mounted) return;

    try {
      final trip = await repository.getById(code);
      if (trip == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No trip found with that code.')),
          );
        }
        return;
      }
      if (trip.userId == uid || trip.collaboratorIds.contains(uid)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You already have access to this trip.'),
            ),
          );
        }
        return;
      }
      if (!mounted) return;
      final userName = context.read<AuthProvider>().currentUser?.name ?? '';
      await repository.joinAsCollaborator(
        itineraryId: code,
        userId: uid,
        userName: userName,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Joined "${trip.title}".')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppException.from(e).message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().firebaseUser?.uid;
    final repository = ItineraryRepository();

    return Scaffold(
      body: Column(
        children: [
          _SavedTripsHeader(
            onBack: () => context.popOrGo(RoutePaths.profile),
            onCalendar: uid == null
                ? null
                : () => showTripCalendarDialog(context),
            onJoin: uid == null ? null : () => _joinTrip(repository, uid),
          ),
          const OfflineBanner(),
          Expanded(
            child: uid == null
                ? const EmptyStateWidget(
                    icon: Symbols.map_rounded,
                    title: 'Sign in required',
                    message: 'Sign in to view your saved trips.',
                  )
                : StreamBuilder<List<SavedItinerary>>(
                    stream: repository.streamForUser(uid),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return ListView(
                          padding: EdgeInsets.zero,
                          children: List.generate(
                            4,
                            (_) => LoadingWidget.listRow(),
                          ),
                        );
                      }
                      final trips = snapshot.data ?? const [];
                      if (trips.isEmpty) {
                        return const EmptyStateWidget(
                          icon: Symbols.map_rounded,
                          title: 'No saved trips yet',
                          message:
                              'Generate an itinerary from the AI Planner and save it to see it here.',
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          AppSpacing.xs,
                          AppSpacing.md,
                          AppSpacing.xl,
                        ),
                        itemCount: trips.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.md),
                        itemBuilder: (context, i) {
                          final trip = trips[i];
                          final isOwner = trip.userId == uid;
                          return _SavedItineraryTile(
                            trip: trip,
                            isOwner: isOwner,
                            isAvailableOffline: _offlineIds.contains(trip.id),
                            isDownloading: _downloadingIds.contains(trip.id),
                            onTap: () => context.push(
                              RoutePaths.generatedItinerary,
                              extra: {
                                'itinerary': trip.itinerary,
                                'savedId': trip.id,
                              },
                            ),
                            onDelete: isOwner
                                ? () => _confirmDelete(repository, trip)
                                : null,
                            onDuplicate: isOwner
                                ? () => _duplicateTrip(repository, trip, uid)
                                : null,
                            onSaveOffline:
                                isOwner && !_offlineIds.contains(trip.id)
                                ? () => _saveOffline(trip)
                                : null,
                            onLeave: isOwner
                                ? null
                                : () => _confirmLeave(repository, trip, uid),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SavedItineraryTile extends StatelessWidget {
  const _SavedItineraryTile({
    required this.trip,
    required this.isOwner,
    required this.isAvailableOffline,
    required this.isDownloading,
    required this.onTap,
    this.onDelete,
    this.onDuplicate,
    this.onSaveOffline,
    this.onLeave,
  });

  final SavedItinerary trip;
  final bool isOwner;
  final bool isAvailableOffline;
  final bool isDownloading;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onDuplicate;
  final VoidCallback? onSaveOffline;
  final VoidCallback? onLeave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = trip.itinerary.totalDays;
    final hasPills =
        trip.itinerary.totalBudget > 0 ||
        trip.packingItems.isNotEmpty ||
        isAvailableOffline;
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: LayoutBuilder(
              builder: (context, constraints) => IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TripCover(
                      trip: trip,
                      isOwner: isOwner,
                      // Narrow phones give the text column the room instead.
                      width: constraints.maxWidth < 320 ? 84 : 112,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            trip.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          _TripInfoRow(
                            icon: Symbols.location_on_rounded,
                            label: trip.itinerary.destinationName,
                          ),
                          const SizedBox(height: 2),
                          _TripInfoRow(
                            icon: Symbols.calendar_month_rounded,
                            label: days == 1 ? '1 day' : '$days days',
                          ),
                          if (hasPills) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Wrap(
                              spacing: AppSpacing.xs,
                              runSpacing: 6,
                              children: [
                                if (trip.itinerary.totalBudget > 0)
                                  _BudgetProgressPill(trip: trip),
                                if (trip.packingItems.isNotEmpty)
                                  _PackingProgressPill(
                                    items: trip.packingItems,
                                  ),
                                if (isAvailableOffline)
                                  _MetricPill(
                                    icon: Symbols.offline_pin_rounded,
                                    label: 'Offline',
                                    color: theme.colorScheme.primary,
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        _buildTopAction(theme),
                        const SizedBox(height: AppSpacing.xxs),
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.1,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Symbols.chevron_right_rounded,
                            size: 22,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The control above the chevron: a download spinner, the owner's
  /// overflow menu, or "leave" for a trip someone else shared.
  Widget _buildTopAction(ThemeData theme) {
    if (isDownloading) {
      return const SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (!isOwner) {
      return IconButton(
        icon: const Icon(Symbols.logout_rounded, color: AppColors.error),
        tooltip: 'Leave trip',
        onPressed: onLeave,
      );
    }
    return PopupMenuButton<VoidCallback?>(
                icon: const Icon(
                  Symbols.more_vert_rounded,
                  color: AppColors.textSecondary,
                ),
                onSelected: (action) => action?.call(),
                itemBuilder: (context) => [
                  if (onSaveOffline != null)
                    PopupMenuItem(
                      value: onSaveOffline,
                      child: Row(
                        children: [
                          Icon(
                            Symbols.download_for_offline_rounded,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          const Text('Save for Offline'),
                        ],
                      ),
                    ),
                  PopupMenuItem(
                    value: onDuplicate,
                    child: const Row(
                      children: [
                        Icon(
                          Symbols.content_copy_rounded,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                        SizedBox(width: AppSpacing.sm),
                        Text('Duplicate'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: onDelete,
                    child: const Row(
                      children: [
                        Icon(
                          Symbols.delete_outline_rounded,
                          size: 18,
                          color: AppColors.error,
                        ),
                        SizedBox(width: AppSpacing.sm),
                        Text(
                          'Remove',
                          style: TextStyle(color: AppColors.error),
                        ),
                      ],
                    ),
                  ),
                ],
    );
  }
}

/// The "Saved Trips" title block that stands in for an app bar: the same
/// travel artwork the sign-in screens use, faded into the page so the title
/// stays legible, with the calendar and join actions as round buttons.
class _SavedTripsHeader extends StatelessWidget {
  const _SavedTripsHeader({required this.onBack, this.onCalendar, this.onJoin});

  final VoidCallback onBack;
  final VoidCallback? onCalendar;
  final VoidCallback? onJoin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background = theme.scaffoldBackgroundColor;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: isDark ? 0.25 : 1,
              child: Image.asset(
                'assets/images/bg.png',
                fit: BoxFit.cover,
                // The band of sky just above the artwork's shoreline.
                alignment: const Alignment(0, 0.5),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    background.withValues(alpha: 0.9),
                    background.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.6, 1],
                  colors: [background.withValues(alpha: 0), background],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.xxs,
              MediaQuery.paddingOf(context).top + AppSpacing.xs,
              AppSpacing.md,
              AppSpacing.xl,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  icon: const Icon(Symbols.arrow_back_rounded),
                  tooltip: 'Back',
                  onPressed: onBack,
                ),
                const SizedBox(width: AppSpacing.xxs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Saved Trips',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Your dream trips, all in one place',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xxs),
                          Icon(
                            Symbols.favorite_rounded,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (onCalendar != null) ...[
                  const SizedBox(width: AppSpacing.xs),
                  _HeaderRoundButton(
                    icon: Symbols.calendar_month_rounded,
                    tooltip: 'Trip calendar',
                    onPressed: onCalendar!,
                  ),
                ],
                if (onJoin != null) ...[
                  const SizedBox(width: AppSpacing.xs),
                  _HeaderRoundButton(
                    icon: Symbols.group_add_rounded,
                    tooltip: 'Join a shared trip',
                    onPressed: onJoin!,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderRoundButton extends StatelessWidget {
  const _HeaderRoundButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.25),
      child: IconButton(
        icon: Icon(icon, color: theme.colorScheme.primary),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}

/// The trip's cover photo, as tall as its card, with a badge over the corner
/// for the two states worth spotting while scrolling: finished, and shared
/// by someone else.
class _TripCover extends StatelessWidget {
  const _TripCover({
    required this.trip,
    required this.isOwner,
    required this.width,
  });

  final SavedItinerary trip;
  final bool isOwner;
  final double width;

  @override
  Widget build(BuildContext context) {
    final coverUrl = trip.itinerary.coverImageUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: width),
        child: SizedBox(
          width: width,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (coverUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: coverUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      _TripThumbFallback(isOwner: isOwner),
                  errorWidget: (context, url, error) =>
                      _TripThumbFallback(isOwner: isOwner),
                )
              else
                _TripThumbFallback(isOwner: isOwner),
              if (trip.isCompleted || !isOwner)
                Positioned(
                  top: 6,
                  left: 6,
                  right: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (trip.isCompleted)
                        const _CoverBadge(
                          icon: Symbols.check_circle_rounded,
                          label: 'Completed',
                        ),
                      if (trip.isCompleted && !isOwner)
                        const SizedBox(height: AppSpacing.xxs),
                      if (!isOwner)
                        const _CoverBadge(
                          icon: Symbols.group_rounded,
                          label: 'Shared',
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoverBadge extends StatelessWidget {
  const _CoverBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xE61F2937),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textOnDark),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textOnDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One icon-and-text line under a trip's title (where it is, how long).
class _TripInfoRow extends StatelessWidget {
  const _TripInfoRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: AppSpacing.xxs),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

/// Shown in place of the destination's cover photo when a trip has none
/// (an older itinerary saved before `coverImageUrl` was captured) or the
/// image fails to load — same map/group icon the tile always used before.
class _TripThumbFallback extends StatelessWidget {
  const _TripThumbFallback({required this.isOwner});

  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.primary.withValues(alpha: 0.1),
      alignment: Alignment.center,
      child: Icon(
        isOwner ? Symbols.map_rounded : Symbols.group_rounded,
        color: theme.colorScheme.primary,
      ),
    );
  }
}

/// Shared pill chrome for the small metric badges on a trip tile — a tinted
/// rounded label, same shape whether it's showing budget or packing
/// progress so the two read as one family at a glance.
class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Actual spend against [SavedItinerary.itinerary]'s AI-estimated budget —
/// streamed live so logging an expense elsewhere updates this the moment it
/// happens, same reasoning as the Budget Tracker it summarizes.
class _BudgetProgressPill extends StatelessWidget {
  const _BudgetProgressPill({required this.trip});

  final SavedItinerary trip;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Expense>>(
      stream: ExpenseRepository().streamForItinerary(trip.id),
      builder: (context, snapshot) {
        final expenses = snapshot.data;
        if (expenses == null) return const SizedBox.shrink();
        final spent = expenses.fold<double>(0, (sum, e) => sum + e.amount);
        final overBudget = spent > trip.itinerary.totalBudget;
        return _MetricPill(
          icon: Symbols.account_balance_wallet_rounded,
          label:
              '₱${spent.toStringAsFixed(0)} / ₱${trip.itinerary.totalBudget.toStringAsFixed(0)}',
          color: overBudget ? AppColors.error : AppColors.primaryDark,
        );
      },
    );
  }
}

/// How much of the packing checklist is checked off — [SavedItinerary.
/// packingItems] is already part of the trip doc this tile was built from,
/// so no extra fetch is needed here, unlike the budget pill.
class _PackingProgressPill extends StatelessWidget {
  const _PackingProgressPill({required this.items});

  final List<PackingItem> items;

  @override
  Widget build(BuildContext context) {
    final checked = items.where((i) => i.checked).length;
    final allPacked = checked == items.length;
    return _MetricPill(
      icon: allPacked
          ? Symbols.check_circle_rounded
          : Symbols.inventory_2_rounded,
      label: '$checked/${items.length} packed',
      color: AppColors.secondaryDark,
    );
  }
}
