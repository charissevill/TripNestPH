import 'package:flutter/material.dart';

import 'app_colors.dart';

/// A named, curated theme the traveler can pick in Settings — deliberately
/// a fixed preset list rather than free-form pickers, so every combination
/// stays legible and coordinated.
///
/// Most presets only set [primary] (a simple accent-color swap, seeded into
/// `ColorScheme.fromSeed` — background/surface/text stay the app's fixed
/// defaults). A preset can optionally also override [ctaAccent] (resolves
/// into `ColorScheme.tertiary`), [background]/[surface]/[textPrimary]/
/// [textSecondary] for a fuller, more distinct look (see 'Forest'). Every
/// null field falls back to today's fixed [AppColors] constant, so the 6
/// original accent-only presets behave exactly as before this existed.
/// `dark*` fields override the dark-mode value of the same token; when
/// null, the dark value is derived from the light one the same way it
/// always has been (e.g. `darkPrimary` defaults to a lightened [primary]).
class ThemePreset {
  const ThemePreset({
    required this.name,
    required this.primary,
    this.ctaAccent,
    this.background,
    this.surface,
    this.textPrimary,
    this.textSecondary,
    this.darkPrimary,
    this.darkCtaAccent,
    this.darkBackground,
    this.darkSurface,
    this.darkTextPrimary,
    this.darkTextSecondary,
  });

  final String name;
  final Color primary;
  final Color? ctaAccent;
  final Color? background;
  final Color? surface;
  final Color? textPrimary;
  final Color? textSecondary;
  final Color? darkPrimary;
  final Color? darkCtaAccent;
  final Color? darkBackground;
  final Color? darkSurface;
  final Color? darkTextPrimary;
  final Color? darkTextSecondary;
}

/// First entry is exactly [AppColors.primary] with no overrides, so a
/// traveler who never opens the picker sees the app exactly as it looks
/// today.
const List<ThemePreset> themePresets = [
  ThemePreset(name: 'Ocean Blue', primary: AppColors.primary),
  ThemePreset(name: 'Violet', primary: Color(0xFF7C3AED)),
  ThemePreset(name: 'Teal', primary: Color(0xFF0D9488)),
  ThemePreset(name: 'Rose', primary: Color(0xFFE11D8F)),
  ThemePreset(name: 'Coral', primary: Color(0xFFEF6351)),
  ThemePreset(name: 'Indigo', primary: Color(0xFF4F46E5)),

  /// A 4-shade monochromatic green (Pine/Forest/Moss/Sage — Moss and Sage
  /// fall out of `ColorScheme.fromSeed`'s generated tonal palette rather
  /// than being separate fields here) paired with a warm terracotta CTA
  /// accent, cream surfaces and charcoal text. Contrast-verified: white on
  /// [primary] 8.47:1 (AAA), [textPrimary] on [background] 13.56:1 (AAA),
  /// white on [ctaAccent] 4.56:1 (AA — terracotta can't clear AAA without
  /// going muddy, so keep it off small text).
  ThemePreset(
    name: 'Forest',
    primary: Color(0xFF24563F),
    ctaAccent: Color(0xFFB85C2C),
    background: Color(0xFFFAF6ED),
    surface: Color(0xFFFAF6ED),
    textPrimary: Color(0xFF2B2B28),
    textSecondary: Color(0xFF5C5B54),
    darkPrimary: Color(0xFF7FC6A1),
    darkCtaAccent: Color(0xFFE08A55),
    darkBackground: Color(0xFF14231C),
    darkSurface: Color(0xFF1D2E25),
    darkTextPrimary: Color(0xFFF3EFE6),
    darkTextSecondary: Color(0xFFB7C9BE),
  ),
];
