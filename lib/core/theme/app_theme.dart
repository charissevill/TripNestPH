import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'accent_colors.dart';
import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Assembles the light and dark [ThemeData] for TripNest PH from the
/// palette, spacing and type-scale primitives. Screens should always read
/// styling from `Theme.of(context)` rather than reaching for [AppColors]
/// directly, so dark mode stays correct everywhere.
///
/// [light]/[dark] take the traveler's chosen [ThemePreset] (see
/// `AccentColorProvider`) rather than always using the fixed [AppColors]
/// constants — every Material component theme below that used to hard-code
/// [AppColors.primary]/`background`/`surface`/text colors now resolves them
/// from the preset instead, falling back to the original constants for any
/// field a preset leaves unset (`null`).
class AppTheme {
  AppTheme._();

  static ThemeData light(ThemePreset preset, {String fontFamily = 'Poppins'}) {
    final primary = preset.primary;
    final ctaAccent = preset.ctaAccent ?? AppColors.accent;
    final background = preset.background ?? AppColors.background;
    final surface = preset.surface ?? AppColors.surface;
    final textPrimary = preset.textPrimary ?? AppColors.textPrimary;
    final textSecondary = preset.textSecondary ?? AppColors.textSecondary;

    final baseTextTheme = AppTypography.textTheme(textPrimary, textSecondary);
    final textTheme = fontFamily == 'Poppins' ? baseTextTheme : GoogleFonts.getTextTheme(fontFamily, baseTextTheme);

    // The 4-shade monochromatic scale around primary (shade 2): shadeDark
    // (shade 1, darkest — pressed states/dark accents), shadeMid (shade 3 —
    // icons/secondary accents, via primaryContainer), shadeLight (shade 4,
    // lightest tint — chip/selection fills). Falls back to exactly what
    // AppTheme computed before shades were preset-specific, so simple
    // single-color presets (Teal/Coral/Indigo) look pixel-identical.
    final shadeDark = preset.shadeDark ?? Color.lerp(primary, Colors.black, 0.25)!;
    final shadeLight = preset.shadeLight ?? primary.withValues(alpha: 0.1);

    final base = ThemeData(brightness: Brightness.light, useMaterial3: true);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      primary: primary,
      secondary: AppColors.secondary,
      tertiary: ctaAccent,
      error: AppColors.error,
      surface: surface,
    ).copyWith(
      outline: AppColors.border,
      onSurface: textPrimary,
      onSurfaceVariant: textSecondary,
      primaryFixedDim: shadeDark,
      primaryContainer: preset.shadeMid,
      primaryFixed: shadeLight,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      splashFactory: InkRipple.splashFactory,
      dividerColor: AppColors.divider,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: textTheme.headlineSmall,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: background,
        selectedColor: primary,
        labelStyle: textTheme.labelMedium,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
        side: BorderSide.none,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: textTheme.bodyMedium,
        labelStyle: textTheme.bodyMedium,
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        floatingLabelStyle: textTheme.bodyMedium?.copyWith(color: primary),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          textStyle: textTheme.labelLarge?.copyWith(color: Colors.white),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.xl),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: AppColors.border, width: 1.4),
          textStyle: textTheme.labelLarge?.copyWith(color: primary),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.xl),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: textTheme.labelLarge?.copyWith(color: primary),
        ),
      ),
      iconTheme: IconThemeData(color: textPrimary, size: 24),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: textPrimary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
        },
      ),
    );
  }

  static ThemeData dark(ThemePreset preset, {String fontFamily = 'Poppins'}) {
    // A lighter tint of the chosen primary for dark surfaces when a preset
    // doesn't specify its own — approximates the hand-picked
    // primary→primaryLight relationship the fixed palette used before
    // themes were user-selectable.
    final primary = preset.darkPrimary ?? Color.lerp(preset.primary, Colors.white, 0.35)!;
    final ctaAccent = preset.darkCtaAccent ?? AppColors.accent;
    final background = preset.darkBackground ?? AppColors.darkBackground;
    final surface = preset.darkSurface ?? AppColors.darkSurface;
    final textPrimary = preset.darkTextPrimary ?? AppColors.darkTextPrimary;
    final textSecondary = preset.darkTextSecondary ?? AppColors.darkTextSecondary;

    final baseTextTheme = AppTypography.textTheme(textPrimary, textSecondary);
    final textTheme = fontFamily == 'Poppins' ? baseTextTheme : GoogleFonts.getTextTheme(fontFamily, baseTextTheme);

    // Dark-mode shades aren't hand-designed separately. Shade 1 (darkest,
    // used as the button gradient's second stop) lightens toward white —
    // matching how darkPrimary already lightens, and Material's own
    // pressed-state overlays flip direction between light/dark themes.
    // Shades 3/4 are meant to read as gentle fills/tints against a surface,
    // not bright highlights, so they blend toward the dark surface instead
    // of toward white — lightening an already-pale tint further would wash
    // it out to near-white, the opposite of "a subtle tinted fill."
    final shadeDark = Color.lerp(preset.shadeDark ?? Color.lerp(preset.primary, Colors.black, 0.25)!, Colors.white, 0.25)!;
    final shadeMid = preset.shadeMid == null ? null : Color.lerp(preset.shadeMid, surface, 0.5);
    final shadeLight = Color.lerp(preset.shadeLight ?? preset.primary.withValues(alpha: 0.1), surface, 0.55)!;

    final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: preset.primary,
      brightness: Brightness.dark,
      primary: primary,
      secondary: AppColors.secondaryLight,
      tertiary: ctaAccent,
      error: AppColors.error,
      surface: surface,
    ).copyWith(
      outline: AppColors.darkBorder,
      onSurface: textPrimary,
      onSurfaceVariant: textSecondary,
      primaryFixedDim: shadeDark,
      primaryContainer: shadeMid,
      primaryFixed: shadeLight,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      dividerColor: AppColors.darkBorder,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: textTheme.headlineSmall,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: textTheme.bodyMedium,
        labelStyle: textTheme.bodyMedium,
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        floatingLabelStyle: textTheme.bodyMedium?.copyWith(color: primary),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: preset.primary,
          foregroundColor: Colors.white,
          textStyle: textTheme.labelLarge?.copyWith(color: Colors.white),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.xl),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          elevation: 0,
        ),
      ),
      iconTheme: IconThemeData(color: textPrimary, size: 24),
    );
  }
}
