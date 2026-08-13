import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import '../text/stroked_text.dart';

/// Premium CTA button with a subtle press-down scale animation and an
/// optional gradient fill. Used for every primary action across the app
/// (Generate Itinerary, Save, Book, Get Started, etc.).
class AnimatedButton extends StatefulWidget {
  const AnimatedButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.leading,
    this.gradientColors,
    this.height = 56,
    this.expand = true,
    this.isLoading = false,
    this.filled = true,
    this.labelColor,
    this.strokeLabel = false,
    this.strokeColor = Colors.black,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// A custom leading widget (e.g. a multicolor brand logo) shown instead of
  /// [icon], rendered as-is without the tint applied to [icon].
  final Widget? leading;
  final List<Color>? gradientColors;
  final double height;
  final bool expand;
  final bool isLoading;

  /// When false, renders as an outlined secondary button instead of a filled one.
  final bool filled;

  /// Overrides the automatic filled/unfilled label+icon color — for an
  /// unfilled button placed directly over a busy photo/illustration
  /// background, where the usual primary-color label has no surface of its
  /// own to contrast against. Null everywhere else, so every other call
  /// site keeps its normal color.
  final Color? labelColor;

  /// Outlines the label with [StrokedText] instead of a plain fill — for
  /// the same busy-background case as [labelColor], when a flat color
  /// alone still loses definition against a light or cluttered patch.
  final bool strokeLabel;

  /// Stroke color used when [strokeLabel] is true.
  final Color strokeColor;

  @override
  State<AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<AnimatedButton>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disabled = widget.onPressed == null || widget.isLoading;
    final defaultGradientColors = [
      theme.colorScheme.primary,
      theme.colorScheme.primaryFixedDim,
    ];
    final gradient = widget.filled
        ? LinearGradient(colors: widget.gradientColors ?? defaultGradientColors)
        : null;

    Widget content = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      height: widget.height,
      width: widget.expand ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: disabled ? null : gradient,
        color: disabled
            ? theme.colorScheme.outline
            : (widget.filled ? null : Colors.transparent),
        border: widget.filled
            ? null
            : Border.all(color: theme.colorScheme.outline, width: 1.4),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: (!widget.filled || disabled)
            ? null
            : [
                BoxShadow(
                  color:
                      (widget.gradientColors?.first ??
                              theme.colorScheme.primary)
                          .withValues(alpha: 0.28),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..scaleByDouble(_pressed ? 0.97 : 1.0, _pressed ? 0.97 : 1.0, 1.0, 1.0),
      transformAlignment: Alignment.center,
      child: widget.isLoading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: Colors.white,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.leading != null) ...[
                  widget.leading!,
                  const SizedBox(width: AppSpacing.xs),
                ] else if (widget.icon != null) ...[
                  Icon(
                    widget.icon,
                    size: 20,
                    color:
                        widget.labelColor ??
                        (widget.filled
                            ? Colors.white
                            : theme.colorScheme.primary),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Flexible(
                  child: Builder(
                    builder: (context) {
                      final labelStyle = theme.textTheme.labelLarge?.copyWith(
                        color: disabled
                            ? theme.colorScheme.onSurfaceVariant
                            : (widget.labelColor ??
                                  (widget.filled
                                      ? Colors.white
                                      : theme.colorScheme.primary)),
                      );
                      if (widget.strokeLabel &&
                          !disabled &&
                          labelStyle != null) {
                        return StrokedText(
                          widget.label,
                          style: labelStyle,
                          strokeColor: widget.strokeColor,
                        );
                      }
                      return Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: labelStyle,
                      );
                    },
                  ),
                ),
              ],
            ),
    );

    return GestureDetector(
      onTapDown: disabled ? null : (_) => setState(() => _pressed = true),
      onTapUp: disabled ? null : (_) => setState(() => _pressed = false),
      onTapCancel: disabled ? null : () => setState(() => _pressed = false),
      onTap: widget.onPressed,
      child: content,
    );
  }
}
