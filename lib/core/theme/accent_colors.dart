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
///
/// [shadeDark]/[shadeMid]/[shadeLight] are an optional 4-shade monochromatic
/// scale around [primary] (shade 2) — a hand-designed family of tones for
/// palettes that want one (Ocean Blue, Violet, Rose, Forest), resolving into
/// real Material `ColorScheme` roles (`primaryFixedDim`/`primaryContainer`/
/// `primaryFixed`) rather than Material's own algorithmic approximation.
/// Left null for the simple single-color presets (Teal, Coral, Indigo),
/// which fall back to the same computed values `AppTheme` already used
/// before this existed.
class ThemePreset {
  const ThemePreset({
    required this.name,
    required this.primary,
    this.ctaAccent,
    this.background,
    this.surface,
    this.textPrimary,
    this.textSecondary,
    this.shadeDark,
    this.shadeMid,
    this.shadeLight,
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
  final Color? shadeDark;
  final Color? shadeMid;
  final Color? shadeLight;
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
  ThemePreset(
    name: 'Ocean Blue',
    primary: AppColors.primary,
    // Reuses the app's existing, already-designed blue variants rather
    // than inventing new ones.
    shadeDark: AppColors.primaryDark,
    shadeMid: AppColors.primaryLight,
    shadeLight: Color(0xFFD7EFFA),
  ),
  ThemePreset(
    name: 'Violet',
    primary: Color(0xFF7C3AED),
    shadeDark: Color(0xFF5B21B6),
    shadeMid: Color(0xFFA78BFA),
    shadeLight: Color(0xFFEDE4FE),
  ),
  ThemePreset(name: 'Teal', primary: Color(0xFF0D9488)),
  ThemePreset(
    name: 'Rose',
    primary: Color(0xFFE11D8F),
    shadeDark: Color(0xFFA3155F),
    shadeMid: Color(0xFFF272C0),
    shadeLight: Color(0xFFFCE3F1),
  ),
  ThemePreset(name: 'Coral', primary: Color(0xFFEF6351)),
  ThemePreset(name: 'Indigo', primary: Color(0xFF4F46E5)),

  /// A 4-shade monochromatic green (Pine/Forest/Moss/Sage) paired with a
  /// warm terracotta CTA accent, cream surfaces and charcoal text.
  /// Contrast-verified: white on [primary] 8.47:1 (AAA), [textPrimary] on
  /// [background] 13.56:1 (AAA), white on [ctaAccent] 4.56:1 (AA —
  /// terracotta can't clear AAA without going muddy, so keep it off small
  /// text). [shadeDark] only ever pairs with white text (button gradients)
  /// and is strictly darker than [primary], so contrast can only improve.
  /// [shadeLight] only ever pairs with dark/primary-colored text or icons
  /// on top (chip fills), matching the same Sage-on-charcoal pattern
  /// already verified at 11.29:1.
  ThemePreset(
    name: 'Forest',
    primary: Color(0xFF24563F),
    ctaAccent: Color(0xFFB85C2C),
    background: Color(0xFFFAF6ED),
    surface: Color(0xFFFAF6ED),
    textPrimary: Color(0xFF2B2B28),
    textSecondary: Color(0xFF5C5B54),
    shadeDark: Color(0xFF14342A),
    shadeMid: Color(0xFF4F9573),
    shadeLight: Color(0xFFCFE8DA),
    darkPrimary: Color(0xFF7FC6A1),
    darkCtaAccent: Color(0xFFE08A55),
    darkBackground: Color(0xFF14231C),
    darkSurface: Color(0xFF1D2E25),
    darkTextPrimary: Color(0xFFF3EFE6),
    darkTextSecondary: Color(0xFFB7C9BE),
  ),
];
