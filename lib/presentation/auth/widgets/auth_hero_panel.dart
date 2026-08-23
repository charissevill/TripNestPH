import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/branding/app_logo.dart';

/// The branded left-hand panel shown next to the sign-in/sign-up form once
/// there's genuine desktop-width room (see [WindowSize.expanded]) — shared
/// so Login and Register present the same identity rather than each
/// re-deriving their own.
///
/// `assets/images/bg.png` is composed for a phone: a tall, mostly-blank sky
/// at the top (reserved for the compact layout's status bar/form to sit
/// over) with the real illustration — a signpost, an old church, a beach —
/// packed into the bottom. A wide desktop panel is short relative to that
/// height, so a default-aligned `BoxFit.cover` crop lands squarely in the
/// blank sky and reads as "no picture at all" — bottom-aligning the crop is
/// what actually surfaces the illustration. The scrim is strongest in a
/// band behind the text (readability) and lighter at the very top/bottom
/// edges, so the photo still reads as a photo instead of a flat color.
class AuthHeroPanel extends StatelessWidget {
  const AuthHeroPanel({super.key});

  static const _highlights = [
    (Symbols.auto_awesome_rounded, 'AI-powered itinerary planning, built around your budget'),
    (Symbols.explore_rounded, 'Discover hidden gems across every province'),
    (Symbols.groups_rounded, 'Plan and split trips together with your travel group'),
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/bg.png',
          fit: BoxFit.cover,
          alignment: Alignment.bottomCenter,
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.55, 1.0],
              colors: [
                AppColors.primaryDark.withValues(alpha: 0.42),
                AppColors.primaryDark.withValues(alpha: 0.80),
                AppColors.oceanGradient.last.withValues(alpha: 0.5),
              ],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.huge, vertical: AppSpacing.xxxl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  // The pin mark's own light-blue outline and the tiny
                  // wordmark underneath it both wash out against a similarly
                  // blue photo/scrim — a white backing behind the logo (the
                  // same treatment its own gradient badge fallback already
                  // gets) keeps it legible regardless of what's behind it.
                  // Left slightly translucent (not fully solid) so a hint of
                  // the photo still comes through the card itself.
                  child: const AppLogo(size: 110),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Discover the Philippines,\none destination at a time.',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: Colors.white,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxxl),
                for (final (icon, text) in _highlights) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, color: Colors.white, size: 22),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          text,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
