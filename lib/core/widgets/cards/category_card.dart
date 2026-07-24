import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../domain/models/category.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// A circular category tile (image thumbnail + icon badge + label) used in
/// the Home categories row and the Explore category filter grid.
class CategoryCard extends StatelessWidget {
  const CategoryCard({
    super.key,
    required this.category,
    required this.onTap,
    this.isSelected = false,
    this.size = 72,
  });

  final TravelCategory category;
  final VoidCallback onTap;
  final bool isSelected;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: isSelected ? AppColors.primary : Colors.transparent, width: 2.4),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            padding: const EdgeInsets.all(3),
            child: ClipOval(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(imageUrl: category.imageUrl, fit: BoxFit.cover),
                  Container(color: Colors.black.withValues(alpha: 0.22)),
                  Center(child: Icon(category.icon, color: Colors.white, size: size * 0.36)),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            category.label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: isSelected ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
