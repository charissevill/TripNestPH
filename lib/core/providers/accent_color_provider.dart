import 'package:flutter/material.dart';

import '../services/local_preferences_service.dart';
import '../theme/accent_colors.dart';

/// Drives the Settings screen's "Theme" picker, persisted locally so it
/// survives app restarts. Defaults to the first [themePresets] entry
/// (exactly [AppColors.primary], no other overrides) until a saved
/// preference loads.
class AccentColorProvider extends ChangeNotifier {
  AccentColorProvider({LocalPreferencesService? preferencesService})
      : _preferencesService = preferencesService ?? LocalPreferencesService() {
    _load();
  }

  final LocalPreferencesService _preferencesService;
  ThemePreset _preset = themePresets.first;

  ThemePreset get preset => _preset;

  Future<void> _load() async {
    final savedName = await _preferencesService.getThemePresetName();
    if (savedName == null) return;
    final match = themePresets.where((p) => p.name == savedName);
    if (match.isEmpty) return;
    _preset = match.first;
    notifyListeners();
  }

  void setPreset(ThemePreset preset) {
    _preset = preset;
    notifyListeners();
    _preferencesService.setThemePresetName(preset.name);
  }
}
