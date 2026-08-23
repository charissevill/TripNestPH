import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../data/repositories/festival_repository.dart';
import 'upcoming_festival_card.dart';
import 'upcoming_trip_card.dart';

/// Places the upcoming-trip and upcoming-festival countdown cards side by
/// side when both have something to show, instead of stacking two
/// full-width banners one after another. Falls back to a single full-width
/// card when only one has something, and renders nothing when neither does.
class HomeHighlightsRow extends StatelessWidget {
  const HomeHighlightsRow({
    super.key,
    required this.uid,
    this.festivalRepository,
  });

  final String? uid;
  final FestivalRepository? festivalRepository;

  @override
  Widget build(BuildContext context) {
    return UpcomingTripData(
      uid: uid,
      builder: (context, trip) {
        return UpcomingFestivalData(
          festivalRepository: festivalRepository,
          builder: (context, festival) {
            if (trip == null && festival == null) {
              return const SizedBox.shrink();
            }

            final Widget child;
            if (trip != null && festival != null) {
              child = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: UpcomingTripCard(trip: trip)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: UpcomingFestivalCard(festival: festival)),
                ],
              );
            } else if (trip != null) {
              child = UpcomingTripCard(trip: trip);
            } else {
              child = UpcomingFestivalCard(festival: festival!);
            }

            return Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: child,
            );
          },
        );
      },
    );
  }
}
