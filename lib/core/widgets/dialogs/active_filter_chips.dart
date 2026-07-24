import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

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
  });

  final String? provinceName;
  final double? minRating;
  final VoidCallback onRemoveProvince;
  final VoidCallback onRemoveMinRating;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        if (provinceName != null)
          Chip(label: Text(provinceName!), deleteIcon: const Icon(Symbols.close_rounded, size: 16), onDeleted: onRemoveProvince),
        if (minRating != null)
          Chip(label: Text('${minRating!.toStringAsFixed(1)}+ ★'), deleteIcon: const Icon(Symbols.close_rounded, size: 16), onDeleted: onRemoveMinRating),
        ActionChip(label: const Text('Clear all'), onPressed: onClearAll),
      ],
    );
  }
}
