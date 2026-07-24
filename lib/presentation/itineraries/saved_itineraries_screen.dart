import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/routes/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_exception.dart';
import '../../core/widgets/banners/offline_banner.dart';
import '../../core/widgets/dialogs/confirmation_dialog.dart';
import '../../core/widgets/states/empty_state_widget.dart';
import '../../data/repositories/itinerary_repository.dart';
import '../../domain/models/saved_itinerary.dart';

/// Every trip the signed-in traveler has saved from the trip planner, plus
/// any trip a friend has shared with them — "View Saved Trips" from the
/// Profile screen.
class SavedItinerariesScreen extends StatelessWidget {
  const SavedItinerariesScreen({super.key});

  Future<void> _confirmDelete(BuildContext context, ItineraryRepository repository, SavedItinerary trip) async {
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Remove this trip?',
      message: '"${trip.title}" will be permanently removed from your saved trips.',
      confirmLabel: 'Remove',
      isDestructive: true,
    );
    if (confirmed) await repository.delete(trip.id);
  }

  Future<void> _duplicateTrip(BuildContext context, ItineraryRepository repository, SavedItinerary trip, String uid) async {
    try {
      await repository.duplicate(trip.id, uid);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"${trip.title}" duplicated.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppException.from(e).message)));
      }
    }
  }

  Future<void> _confirmLeave(BuildContext context, ItineraryRepository repository, SavedItinerary trip, String uid) async {
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Leave this trip?',
      message: 'You\'ll lose access to "${trip.title}" unless someone invites you again.',
      confirmLabel: 'Leave',
      isDestructive: true,
    );
    if (confirmed) await repository.leaveTrip(itineraryId: trip.id, userId: uid);
  }

  Future<void> _joinTrip(BuildContext context, ItineraryRepository repository, String uid) async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join a Shared Trip'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Trip code', hintText: 'Paste the code your friend shared'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(controller.text.trim()), child: const Text('Join')),
        ],
      ),
    );
    if (code == null || code.isEmpty || !context.mounted) return;

    try {
      final trip = await repository.getById(code);
      if (trip == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No trip found with that code.')));
        }
        return;
      }
      if (trip.userId == uid || trip.collaboratorIds.contains(uid)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You already have access to this trip.')));
        }
        return;
      }
      await repository.joinAsCollaborator(itineraryId: code, userId: uid);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Joined "${trip.title}".')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppException.from(e).message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().firebaseUser?.uid;
    final repository = ItineraryRepository();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Symbols.arrow_back_rounded), onPressed: () => context.pop()),
        title: const Text('Saved Trips'),
        actions: [
          if (uid != null) ...[
            IconButton(
              icon: const Icon(Symbols.calendar_month_rounded),
              tooltip: 'Trip calendar',
              onPressed: () => context.push(RoutePaths.tripCalendar),
            ),
            IconButton(
              icon: const Icon(Symbols.group_add_rounded),
              tooltip: 'Join a shared trip',
              onPressed: () => _joinTrip(context, repository, uid),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: uid == null
                ? const EmptyStateWidget(icon: Symbols.map_rounded, title: 'Sign in required', message: 'Sign in to view your saved trips.')
                : StreamBuilder<List<SavedItinerary>>(
                    stream: repository.streamForUser(uid),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final trips = snapshot.data ?? const [];
                      if (trips.isEmpty) {
                        return const EmptyStateWidget(
                          icon: Symbols.map_rounded,
                          title: 'No saved trips yet',
                          message: 'Generate an itinerary from the AI Planner and save it to see it here.',
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        itemCount: trips.length,
                        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
                        itemBuilder: (context, i) {
                          final trip = trips[i];
                          final isOwner = trip.userId == uid;
                          return _SavedItineraryTile(
                            trip: trip,
                            isOwner: isOwner,
                            onTap: () => context.push(
                              RoutePaths.generatedItinerary,
                              extra: {'itinerary': trip.itinerary, 'savedId': trip.id},
                            ),
                            onDelete: isOwner ? () => _confirmDelete(context, repository, trip) : null,
                            onDuplicate: isOwner ? () => _duplicateTrip(context, repository, trip, uid) : null,
                            onLeave: isOwner ? null : () => _confirmLeave(context, repository, trip, uid),
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
    required this.onTap,
    this.onDelete,
    this.onDuplicate,
    this.onLeave,
  });

  final SavedItinerary trip;
  final bool isOwner;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onDuplicate;
  final VoidCallback? onLeave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 6)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              alignment: Alignment.center,
              child: Icon(isOwner ? Symbols.map_rounded : Symbols.group_rounded, color: AppColors.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(trip.title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    isOwner
                        ? '${trip.itinerary.destinationName} · ${trip.itinerary.totalDays} days'
                        : '${trip.itinerary.destinationName} · Shared with you',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (isOwner)
              PopupMenuButton<VoidCallback?>(
                icon: const Icon(Symbols.more_vert_rounded, color: AppColors.textSecondary),
                onSelected: (action) => action?.call(),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: onDuplicate,
                    child: const Row(
                      children: [
                        Icon(Symbols.content_copy_rounded, size: 18, color: AppColors.textSecondary),
                        SizedBox(width: AppSpacing.sm),
                        Text('Duplicate'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: onDelete,
                    child: const Row(
                      children: [
                        Icon(Symbols.delete_outline_rounded, size: 18, color: AppColors.error),
                        SizedBox(width: AppSpacing.sm),
                        Text('Remove', style: TextStyle(color: AppColors.error)),
                      ],
                    ),
                  ),
                ],
              )
            else
              IconButton(
                icon: const Icon(Symbols.logout_rounded, color: AppColors.error),
                onPressed: onLeave,
              ),
          ],
        ),
      ),
    );
  }
}
