import 'package:flutter/material.dart';

import '../services/local_preferences_service.dart';
import '../theme/typography_options.dart';

/// Drives the Settings screen's "Font Style" and "Text Size" pickers,
/// persisted locally so they survive app restarts. Combines both into one
/// provider since they're consumed together at the same `main.dart` call
/// site and both represent "text look" preference.
class TypographyProvider extends ChangeNotifier {
  TypographyProvider({LocalPreferencesService? preferencesService})
      : _preferencesService = preferencesService ?? LocalPreferencesService() {
    _load();
  }

  final LocalPreferencesService _preferencesService;
  String _fontFamily = fontFamilyOptions.first.familyName;
  double _fontScale = fontSizeOptions[1].scale;

  String get fontFamily => _fontFamily;
  double get fontScale => _fontScale;

  Future<void> _load() async {
    final savedFamily = await _preferencesService.getFontFamily();
    final savedScale = await _preferencesService.getFontScale();
    if (savedFamily == null && savedScale == null) return;
    if (savedFamily != null) _fontFamily = savedFamily;
    if (savedScale != null) _fontScale = savedScale;
    notifyListeners();
  }

  void setFontFamily(String family) {
    _fontFamily = family;
    notifyListeners();
    _preferencesService.setFontFamily(family);
  }

  void setFontScale(double scale) {
    _fontScale = scale;
    notifyListeners();
    _preferencesService.setFontScale(scale);
  }
}
