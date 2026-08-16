import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../utils/listing_filters.dart';

/// The "Province X · Rating 4+ · Clear all" row shown under a search bar
/// once [showSearchFilterSheet] filters are active — shared by Search and
/// Explore so removing one filter behaves identically in both places.
class ActiveFilterChips extends StatelessWidget {
  const ActiveFilterChips({
    super.key,
    required this.provinceName,
    required this.minRating,
    required this.onRemoveProvince,
    required this.onRemoveMinRating,
    required this.onClearAll,
    this.priceTier,
    this.onRemovePriceTier,
    this.maxDistanceKm,
    this.onRemoveDistance,
    this.accessibilityTag,
    this.onRemoveAccessibilityTag,
  });

  final String? provinceName;
  final double? minRating;
  final VoidCallback onRemoveProvince;
  final VoidCallback onRemoveMinRating;
  final VoidCallback onClearAll;
  final PriceTier? priceTier;
  final VoidCallback? onRemovePriceTier;
  final double? maxDistanceKm;
  final VoidCallback? onRemoveDistance;
  final String? accessibilityTag;
  final VoidCallback? onRemoveAccessibilityTag;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        if (provinceName != null)
          Chip(label: Text(provinceName!), deleteIcon: const Icon(Symbols.close_rounded, size: 16), onDeleted: onRemoveProvince),
        if (minRating != null)
          Chip(label: Text('${minRating!.toStringAsFixed(1)}+ ★'), deleteIcon: const Icon(Symbols.close_rounded, size: 16), onDeleted: onRemoveMinRating),
        if (priceTier != null)
          Chip(label: Text(priceTier!.label), deleteIcon: const Icon(Symbols.close_rounded, size: 16), onDeleted: onRemovePriceTier),
        if (maxDistanceKm != null)
          Chip(
            label: Text('Within ${maxDistanceKm!.toStringAsFixed(0)} km'),
            deleteIcon: const Icon(Symbols.close_rounded, size: 16),
            onDeleted: onRemoveDistance,
          ),
        if (accessibilityTag != null)
          Chip(label: Text(accessibilityTag!), deleteIcon: const Icon(Symbols.close_rounded, size: 16), onDeleted: onRemoveAccessibilityTag),
        ActionChip(label: const Text('Clear all'), onPressed: onClearAll),
      ],
    );
  }
}
