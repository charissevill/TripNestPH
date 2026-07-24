import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// The TripNest PH brand mark, loaded from assets/images/logo.png. Falls
/// back to the drawn ocean-gradient badge if that file hasn't been added
/// yet, so the app never crashes on a missing asset mid-development.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Image.asset(
        'assets/images/logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: AppColors.gradient(AppColors.oceanGradient),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Icon(Symbols.travel_explore_rounded, color: Colors.white, size: size / 2),
        ),
      ),
    );
  }
}
