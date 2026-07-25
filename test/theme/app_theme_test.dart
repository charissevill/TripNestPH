import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:tripnest_ph/core/theme/accent_colors.dart';
import 'package:tripnest_ph/core/theme/app_colors.dart';
import 'package:tripnest_ph/core/theme/app_theme.dart';
import 'package:tripnest_ph/core/widgets/buttons/animated_button.dart';

void main() {
  // AppTheme pulls its type scale through GoogleFonts.poppins(), which
  // kicks off a background font-load attempt as a side effect of building
  // a TextTheme. That's harmless in the real app (falls back gracefully),
  // but a plain `test()` body has no widget-test zone to absorb the
  // trailing async rejection, so every case here runs as `testWidgets()`
  // instead — matching the convention every other test in this repo that
  // touches AppTheme already uses.
  final forest = themePresets.firstWhere((p) => p.name == 'Forest');

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('AppTheme.light/dark with the default preset (Ocean Blue)', () {
    testWidgets('resolves to the original fixed AppColors constants — no regression', (tester) async {
      final light = AppTheme.light(themePresets.first);
      expect(light.colorScheme.primary, AppColors.primary);
      expect(light.scaffoldBackgroundColor, AppColors.background);
      expect(light.colorScheme.onSurface, AppColors.textPrimary);
      expect(light.colorScheme.tertiary, AppColors.accent);
      expect(light.elevatedButtonTheme.style?.backgroundColor?.resolve({}), AppColors.primary);

      final dark = AppTheme.dark(themePresets.first);
      expect(dark.scaffoldBackgroundColor, AppColors.darkBackground);
      expect(dark.colorScheme.onSurface, AppColors.darkTextPrimary);
      expect(dark.colorScheme.tertiary, AppColors.accent);
    });
  });

  group('AppTheme.light/dark with the Forest preset', () {
    testWidgets('light mode resolves every overridden token to the exact Forest hex values', (tester) async {
      final theme = AppTheme.light(forest);

      expect(theme.colorScheme.primary, const Color(0xFF24563F), reason: 'primary (Forest green)');
      expect(theme.colorScheme.tertiary, const Color(0xFFB85C2C), reason: 'tertiary (Terracotta CTA accent)');
      expect(theme.scaffoldBackgroundColor, const Color(0xFFFAF6ED), reason: 'scaffold background (Cream)');
      expect(theme.cardTheme.color, const Color(0xFFFAF6ED), reason: 'card surface (Cream)');
      expect(theme.colorScheme.onSurface, const Color(0xFF2B2B28), reason: 'primary text (Charcoal)');
      expect(theme.colorScheme.onSurfaceVariant, const Color(0xFF5C5B54), reason: 'secondary text');

      // Buttons must actually read the resolved primary, not the fixed
      // AppColors.primary — this is the exact gap that made buttons not
      // change color before this feature existed.
      expect(theme.elevatedButtonTheme.style?.backgroundColor?.resolve({}), const Color(0xFF24563F));
      expect(theme.textTheme.bodyLarge?.color, const Color(0xFF2B2B28));
    });

    testWidgets('dark mode resolves every overridden token to the exact Forest dark values', (tester) async {
      final theme = AppTheme.dark(forest);

      expect(theme.colorScheme.primary, const Color(0xFF7FC6A1), reason: 'dark primary');
      expect(theme.colorScheme.tertiary, const Color(0xFFE08A55), reason: 'dark CTA accent');
      expect(theme.scaffoldBackgroundColor, const Color(0xFF14231C), reason: 'dark background');
      expect(theme.cardTheme.color, const Color(0xFF1D2E25), reason: 'dark surface');
      expect(theme.colorScheme.onSurface, const Color(0xFFF3EFE6), reason: 'dark primary text');
      expect(theme.colorScheme.onSurfaceVariant, const Color(0xFFB7C9BE), reason: 'dark secondary text');
    });
  });

  testWidgets('AnimatedButton default gradient tracks the resolved theme primary, not a hardcoded color', (
    tester,
  ) async {
    // Regression test for the exact bug found and fixed: AnimatedButton
    // used to hard-code AppColors.primary/primaryDark regardless of which
    // theme was active. Pump it under the Forest theme and confirm the
    // button's container actually paints Forest green, not the fixed blue.
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(forest),
        home: const Scaffold(
          body: AnimatedButton(label: 'Generate Itinerary', onPressed: _noop),
        ),
      ),
    );

    final container = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
    final decoration = container.decoration as BoxDecoration;
    final gradientColors = decoration.gradient!.colors;

    expect(gradientColors.first, const Color(0xFF24563F), reason: 'button should paint Forest green, not fixed blue');
  });
}

void _noop() {}
