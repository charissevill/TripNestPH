import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';

/// A frosted-glass container (blurred backdrop + translucent tint) used for
/// floating panels over hero imagery — e.g. quick-stats on Details screens
/// or accent panels on the AI Planner form.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.borderRadius = AppRadius.lg,
    this.blurSigma = 16,
    this.tintColor,
    this.opacity = 0.16,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double blurSigma;
  final Color? tintColor;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final tint = tintColor ?? Colors.white;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: tint.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
}
