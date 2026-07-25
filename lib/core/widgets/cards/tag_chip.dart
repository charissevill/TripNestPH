import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';

/// The small solid-color pill used for "Hidden Gem", "Popular", "Upcoming"
/// and similar status tags floating over card images.
class TagChip extends StatelessWidget {
  const TagChip({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 5),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
      ),
    );
  }
}
