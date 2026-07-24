import 'package:flutter/material.dart';

/// Central color palette for TripNest PH.
///
/// Keep the palette tight — primary/secondary/accent plus travel-inspired
/// gradients. Never introduce ad-hoc colors in screens; add them here.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF2D9CDB);
  static const Color primaryDark = Color(0xFF1B7FB8);
  static const Color primaryLight = Color(0xFF6DBEEC);

  static const Color secondary = Color(0xFF27AE60);
  static const Color secondaryDark = Color(0xFF1E8A4C);
  static const Color secondaryLight = Color(0xFF6FCF97);

  static const Color accent = Color(0xFFF2C94C);
  static const Color accentDark = Color(0xFFD9A62E);

  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);

  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color textOnDark = Color(0xFFFFFFFF);

  static const Color error = Color(0xFFEB5757);
  static const Color success = Color(0xFF27AE60);
  static const Color warning = Color(0xFFF2C94C);

  static const Color border = Color(0xFFE5E9F0);
  static const Color divider = Color(0xFFEFF2F6);
  static const Color shimmerBase = Color(0xFFE9EDF3);
  static const Color shimmerHighlight = Color(0xFFF6F8FB);

  // ---- Dark theme surfaces ----
  static const Color darkBackground = Color(0xFF0F1620);
  static const Color darkSurface = Color(0xFF1A2432);
  static const Color darkBorder = Color(0xFF2A3A4D);
  static const Color darkTextPrimary = Color(0xFFF3F6FA);
  static const Color darkTextSecondary = Color(0xFFA6B2C2);

  // ---- Travel-inspired gradients ----
  static const List<Color> oceanGradient = [
    Color(0xFF2D9CDB),
    Color(0xFF0F6FA6),
  ];

  static const List<Color> sunsetGradient = [
    Color(0xFFFF9966),
    Color(0xFFFF5E62),
  ];

  static const List<Color> forestGradient = [
    Color(0xFF56AB2F),
    Color(0xFF27AE60),
  ];

  static const List<Color> mountainGradient = [
    Color(0xFF757F9A),
    Color(0xFF2D9CDB),
  ];

  static const List<Color> skyGradient = [
    Color(0xFF6DBEEC),
    Color(0xFFB8E1F5),
  ];

  static const List<Color> goldenHourGradient = [
    Color(0xFFF2C94C),
    Color(0xFFF2994A),
  ];

  /// Muted gray-blue for overcast skies and fog.
  static const List<Color> mistGradient = [
    Color(0xFFB0BEC5),
    Color(0xFF90A4AE),
  ];

  /// Deeper blue-gray for rain — darker than [skyGradient]/[oceanGradient]
  /// so a rainy forecast reads as visibly different from a sunny one.
  static const List<Color> rainGradient = [
    Color(0xFF546E8A),
    Color(0xFF3B5171),
  ];

  /// Dark, moody purple-gray for thunderstorms.
  static const List<Color> stormGradient = [
    Color(0xFF4B4E6D),
    Color(0xFF2C2E43),
  ];

  /// Standard dark-to-transparent overlay used at the bottom of hero images
  /// so white text/badges stay legible over any photo.
  static const List<Color> imageScrim = [
    Color(0x00000000),
    Color(0x99000000),
  ];

  /// Resolves a semantic color key (e.g. from Firestore-persisted content)
  /// to one of the palette constants above. Content should only ever pick
  /// from this fixed set — never arbitrary hex values — to keep the UI
  /// consistent.
  static Color byKey(String key) {
    switch (key) {
      case 'secondary':
        return secondary;
      case 'secondaryDark':
        return secondaryDark;
      case 'accent':
        return accent;
      case 'accentDark':
        return accentDark;
      case 'primaryDark':
        return primaryDark;
      case 'error':
        return error;
      case 'primary':
      default:
        return primary;
    }
  }

  static LinearGradient gradient(List<Color> colors, {
    AlignmentGeometry begin = Alignment.topLeft,
    AlignmentGeometry end = Alignment.bottomRight,
  }) {
    return LinearGradient(begin: begin, end: end, colors: colors);
  }
}
