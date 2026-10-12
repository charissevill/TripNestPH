import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// The header shared by the AI Planner and "Create your own itinerary"
/// forms: a small gradient badge, a big headline with its brush underline
/// and flight trail, and a one-line subtitle, all over the app's island
/// artwork — which is painted [bleed] past both sides (and up behind the
/// status bar) so it reaches the screen edges despite sitting inside the
/// form's padded list. The caller's `SafeArea` must leave the top inset
/// alone (`top: false`); this adds it itself.
class PlannerHero extends StatelessWidget {
  const PlannerHero({
    super.key,
    required this.bleed,
    required this.badgeIcon,
    required this.badgeLabel,
    required this.headline,
    required this.subtitle,
    this.onBack,
    this.actionIcon,
    this.onAction,
  });

  final double bleed;
  final IconData badgeIcon;
  final String badgeLabel;
  final String headline;
  final String subtitle;

  /// Shows a round Back button above the badge — for a pushed screen that
  /// swaps its AppBar for this header.
  final VoidCallback? onBack;

  /// The round shortcut button at the top right (e.g. AI chat); hidden
  /// unless both are given.
  final IconData? actionIcon;
  final VoidCallback? onAction;

  Widget _circleButton(ThemeData theme, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: theme.colorScheme.primary),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background = theme.scaffoldBackgroundColor;
    final topInset = MediaQuery.paddingOf(context).top;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: -bleed,
          right: -bleed,
          top: 0,
          bottom: 0,
          child: IgnorePointer(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Opacity(
                  opacity: isDark ? 0.25 : 1,
                  child: Image.asset(
                    'assets/images/bg.png',
                    fit: BoxFit.cover,
                    // The island and shoreline near the artwork's bottom.
                    alignment: const Alignment(0, 0.82),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      stops: const [0.4, 0.9],
                      colors: [
                        background,
                        background.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.6, 1],
                      colors: [background.withValues(alpha: 0), background],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(
            top: topInset + AppSpacing.lg,
            bottom: AppSpacing.xxl,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (onBack != null) ...[
                      _circleButton(theme, Symbols.arrow_back_rounded, onBack!),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: AppColors.gradient([theme.colorScheme.primary, theme.colorScheme.primaryFixedDim]),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            badgeIcon,
                            fill: 1,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              badgeLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 380.ms).moveY(begin: 8, end: 0),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      headline,
                      style: theme.textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Flexible(
                          child: CustomPaint(
                            size: const Size(120, 10),
                            painter: _BrushUnderlinePainter(
                              theme.colorScheme.primary.withValues(alpha: 0.45),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Flexible(
                          child: CustomPaint(
                            size: const Size(64, 26),
                            painter: _FlightPathPainter(theme.colorScheme.primary),
                          ),
                        ),
                        Transform.rotate(
                          angle: 0.6,
                          child: Icon(
                            Symbols.flight_rounded,
                            fill: 1,
                            size: 22,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (actionIcon != null && onAction != null) ...[
                const SizedBox(width: AppSpacing.sm),
                _circleButton(theme, actionIcon!, onAction!),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The soft brush stroke under the hero headline.
class _BrushUnderlinePainter extends CustomPainter {
  const _BrushUnderlinePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(3, size.height * 0.7)
      ..quadraticBezierTo(size.width * 0.5, 0, size.width - 3, size.height * 0.45);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_BrushUnderlinePainter oldDelegate) => oldDelegate.color != color;
}

/// The dashed trail leading up to the hero's little plane.
class _FlightPathPainter extends CustomPainter {
  const _FlightPathPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(0, size.height * 0.85)
      ..cubicTo(
        size.width * 0.35,
        size.height * 1.1,
        size.width * 0.6,
        size.height * 0.75,
        size.width,
        size.height * 0.2,
      );
    for (final metric in path.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 8) {
        canvas.drawPath(metric.extractPath(d, d + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_FlightPathPainter oldDelegate) => oldDelegate.color != color;
}
