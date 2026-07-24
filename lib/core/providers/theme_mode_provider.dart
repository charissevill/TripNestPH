import 'package:flutter/material.dart';

import '../services/local_preferences_service.dart';

/// Drives the Settings screen's "Dark Mode" toggle, persisted locally so it
/// survives app restarts.
class ThemeModeProvider extends ChangeNotifier {
  ThemeModeProvider({LocalPreferencesService? preferencesService})
      : _preferencesService = preferencesService ?? LocalPreferencesService() {
    _load();
  }

  final LocalPreferencesService _preferencesService;
  ThemeMode _mode = ThemeMode.light;

  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  Future<void> _load() async {
    final isDarkSaved = await _preferencesService.getDarkMode();
    _mode = isDarkSaved ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  void setDark(bool value) {
    _mode = value ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    _preferencesService.setDarkMode(value);
  }
}
