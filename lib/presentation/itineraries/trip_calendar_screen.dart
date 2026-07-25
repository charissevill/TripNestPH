import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/providers/auth_provider.dart';
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
class TripCalendarScreen extends StatefulWidget {
  const TripCalendarScreen({super.key});

  @override
  State<TripCalendarScreen> createState() => _TripCalendarScreenState();
}

class _TripCalendarScreenState extends State<TripCalendarScreen> {
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

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Trip Calendar'),
      ),
      body: uid == null
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
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
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
