import 'package:flutter/material.dart';

import '../../../domain/models/travel_tip.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// A compact advice card used in the Home "Travel Tips" carousel and in the
/// Details/Itinerary "Travel Tips" section. Title/description are clipped
/// to keep every card the same height in the carousel — tapping opens the
/// full, unclipped text in a sheet so nothing actually gets lost.
class TravelTipCard extends StatelessWidget {
  const TravelTipCard({super.key, required this.tip, this.width = 260});

  final TravelTip tip;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => _showTravelTipSheet(context, tip),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        width: width,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 14, offset: const Offset(0, 6)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: tip.accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(tip.icon, color: tip.accentColor, size: 22),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(tip.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              tip.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

void _showTravelTipSheet(BuildContext context, TravelTip tip) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _TravelTipSheet(tip: tip),
  );
}

class _TravelTipSheet extends StatelessWidget {
  const _TravelTipSheet({required this.tip});

  final TravelTip tip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(AppRadius.pill)),
                ),
              ),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: tip.accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(tip.icon, color: tip.accentColor, size: 26),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(tip.title, style: theme.textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.sm),
              Text(tip.description, style: theme.textTheme.bodyMedium?.copyWith(height: 1.6)),
            ],
          ),
        ),
      ),
    );
  }
}
