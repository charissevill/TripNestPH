import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/routes/back_navigation.dart';
import '../../core/routes/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/calendar_grid.dart';
import '../../core/widgets/states/empty_state_widget.dart';
import '../../core/widgets/states/loading_widget.dart';
import '../../data/repositories/itinerary_repository.dart';
import '../../domain/models/saved_itinerary.dart';

/// A month-grid view of every saved trip that has a travel date set —
/// owned trips and ones shared with the traveler — so they can see at a
/// glance where they'll be on any given day.
///
/// Saved Trips opens this as a dialog ([showTripCalendarDialog]); the
/// full-screen form is what the `/trip-calendar` route itself still shows.
class TripCalendarScreen extends StatelessWidget {
  const TripCalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back_rounded),
          onPressed: () => context.popOrGo(RoutePaths.savedItineraries),
        ),
        title: const Text('Trip Calendar'),
      ),
      body: const TripCalendarView(),
    );
  }
}

/// The trip calendar as a dialog over the current screen. Picking a trip
/// closes it and opens that trip from [context] — the screen underneath —
/// since the dialog's own context is gone by then.
Future<void> showTripCalendarDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    // Root navigator so it also covers the shell's floating AI Chat button.
    useRootNavigator: true,
    builder: (dialogContext) => Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.xs,
                0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Trip Calendar',
                      style: Theme.of(dialogContext).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: MaterialLocalizations.of(
                      dialogContext,
                    ).closeButtonTooltip,
                    icon: const Icon(Symbols.close_rounded),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: TripCalendarView(
                shrinkWrap: true,
                onOpenTrip: (trip) {
                  Navigator.of(dialogContext).pop();
                  if (!context.mounted) return;
                  context.push(
                    RoutePaths.generatedItinerary,
                    extra: {'itinerary': trip.itinerary, 'savedId': trip.id},
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// The calendar itself — month switcher, grid, and the "no dated trips"
/// hint — without any page chrome around it.
class TripCalendarView extends StatefulWidget {
  const TripCalendarView({super.key, this.shrinkWrap = false, this.onOpenTrip});

  /// True inside a dialog, so it's only as tall as the month it shows.
  final bool shrinkWrap;

  /// What picking a trip does; by default it's pushed onto this view's own
  /// navigator.
  final void Function(SavedItinerary trip)? onOpenTrip;

  @override
  State<TripCalendarView> createState() => _TripCalendarViewState();
}

class _TripCalendarViewState extends State<TripCalendarView> {
  late DateTime _visibleMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );

  void _changeMonth(int delta) {
    setState(
      () => _visibleMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month + delta,
      ),
    );
  }

  void _openDay(BuildContext context, List<SavedItinerary> trips) {
    if (trips.length == 1) {
      _openTrip(context, trips.first);
      return;
    }
    showModalBottomSheet(
      context: context,
      // Pushed on the ROOT navigator, not the current tab's nested one —
      // the floating AI Chat FAB lives on MainShellScreen's own Scaffold,
      // a sibling of the tab's navigator, so a nested-navigator sheet
      // doesn't cover it and it visibly floats on top of the sheet.
      useRootNavigator: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: trips
              .map(
                (trip) => ListTile(
                  leading: Icon(
                    Symbols.map_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(trip.title),
                  subtitle: Text(trip.itinerary.destinationName),
                  onTap: () {
                    Navigator.of(context).pop();
                    _openTrip(context, trip);
                  },
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  void _openTrip(BuildContext context, SavedItinerary trip) {
    final onOpenTrip = widget.onOpenTrip;
    if (onOpenTrip != null) return onOpenTrip(trip);
    context.push(
      RoutePaths.generatedItinerary,
      extra: {'itinerary': trip.itinerary, 'savedId': trip.id},
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final uid = context.watch<AuthProvider>().firebaseUser?.uid;
    final repository = ItineraryRepository();
    final today = CalendarGrid.dateOnly(DateTime.now());

    return Material(
      type: MaterialType.transparency,
      child: uid == null
          ? const EmptyStateWidget(
              icon: Symbols.calendar_month_rounded,
              title: 'Sign in required',
              message: 'Sign in to view your trip calendar.',
            )
          : StreamBuilder<List<SavedItinerary>>(
              stream: repository.streamForUser(uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return LoadingWidget.block();
                }
                final trips = snapshot.data ?? const [];
                final dateMap = CalendarGrid.buildDateMap(
                  trips,
                  (t) => t.startDate,
                  (t) => t.endDate,
                );
                final cells = CalendarGrid.cellsForMonth(_visibleMonth);
                final hasAnyDates = trips.any((t) => t.startDate != null);

                return ListView(
                  shrinkWrap: widget.shrinkWrap,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Symbols.chevron_left_rounded),
                          onPressed: () => _changeMonth(-1),
                        ),
                        Text(
                          DateFormat('MMMM y').format(_visibleMonth),
                          style: theme.textTheme.titleLarge,
                        ),
                        IconButton(
                          icon: const Icon(Symbols.chevron_right_rounded),
                          onPressed: () => _changeMonth(1),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: const ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                          .map(
                            (d) => Expanded(
                              child: Center(
                                child: Text(
                                  d,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    GridView.count(
                      crossAxisCount: 7,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: cells.map((date) {
                        if (date == null) return const SizedBox.shrink();
                        final tripsOnDay = dateMap[date] ?? const [];
                        final isToday = date == today;
                        final hasTrip = tripsOnDay.isNotEmpty;
                        return Padding(
                          padding: const EdgeInsets.all(2),
                          child: InkWell(
                            onTap: hasTrip
                                ? () => _openDay(context, tripsOnDay)
                                : null,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            child: Container(
                              decoration: BoxDecoration(
                                color: hasTrip
                                    ? theme.colorScheme.primary.withValues(
                                        alpha: 0.15,
                                      )
                                    : null,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                                border: isToday
                                    ? Border.all(
                                        color: theme.colorScheme.primary,
                                        width: 1.5,
                                      )
                                    : null,
                              ),
                              alignment: Alignment.center,
                              // Scales down on a narrow screen / large text so the
                              // day number + trip dot never overflow the square cell.
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${date.day}',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: hasTrip
                                          ? theme.colorScheme.primary
                                          : AppColors.textPrimary,
                                      fontWeight: hasTrip
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                    ),
                                  ),
                                  if (hasTrip)
                                    Container(
                                      margin: const EdgeInsets.only(top: 2),
                                      width: 5,
                                      height: 5,
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    if (!hasAnyDates) ...[
                      const SizedBox(height: AppSpacing.xxl),
                      Center(
                        child: Column(
                          children: [
                            const Icon(
                              Symbols.calendar_month_rounded,
                              size: 40,
                              color: AppColors.textTertiary,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'No trips with dates yet',
                              style: theme.textTheme.titleMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Set travel dates from any saved trip to see it here.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.textTertiary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
    );
  }
}
