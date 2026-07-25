import 'package:shared_preferences/shared_preferences.dart';

/// Local-only app preferences (dark mode, notifications toggle, location)
/// that don't need to sync across devices, so they're kept out of Firestore.
class LocalPreferencesService {
  static const _hasSeenOnboardingKey = 'pref_has_seen_onboarding';
  static const _darkModeKey = 'pref_dark_mode';
  static const _notificationsKey = 'pref_notifications_enabled';
  static const _disabledCategoriesKey = 'pref_disabled_notification_categories';
  static const _locationPromptDismissedKey = 'pref_location_prompt_dismissed';
  static const _locationFeatureEnabledKey = 'pref_location_feature_enabled';
  static const _themePresetKey = 'pref_theme_preset';
  static const _fontFamilyKey = 'pref_font_family';
  static const _fontScaleKey = 'pref_font_scale';

  /// Whether the traveler has already been shown the first-run onboarding
  /// carousel — so it only ever appears once per install, not on every
  /// cold start while signed out.
  Future<bool> getHasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasSeenOnboardingKey) ?? false;
  }

  Future<void> setHasSeenOnboarding(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasSeenOnboardingKey, value);
  }

  Future<bool> getDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_darkModeKey) ?? false;
  }

  Future<void> setDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, value);
  }

  /// Null means no preference saved yet — the traveler's picked theme (see
  /// [ThemePreset]), or the default preset when absent. Stores the
  /// preset's [ThemePreset.name], looked up against `themePresets` on load.
  Future<String?> getThemePresetName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themePresetKey);
  }

  Future<void> setThemePresetName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themePresetKey, name);
  }

  /// Null means no preference saved yet — the traveler's picked font
  /// family (see [FontFamilyOption]), or the default ('Poppins') when
  /// absent.
  Future<String?> getFontFamily() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_fontFamilyKey);
  }

  Future<void> setFontFamily(String family) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fontFamilyKey, family);
  }

  /// Null means no preference saved yet — the traveler's picked text-size
  /// scale (see [FontSizeOption]), or 1.0 ('Default') when absent.
  Future<double?> getFontScale() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_fontScaleKey);
  }

  Future<void> setFontScale(double scale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontScaleKey, scale);
  }

  Future<bool> getNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationsKey) ?? true;
  }

  Future<void> setNotificationsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsKey, value);
  }

  /// Whether the traveler dismissed the "enable location" prompt on Home —
  /// so it doesn't nag on every cold start once they've said no thanks.
  Future<bool> getLocationPromptDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_locationPromptDismissedKey) ?? false;
  }

  Future<void> setLocationPromptDismissed(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_locationPromptDismissedKey, value);
  }

  /// The app-level "Location Services" toggle in Settings. Distinct from
  /// the OS permission itself — an app can't revoke that from the inside,
  /// so turning this off just makes the app stop using location it may
  /// still technically have permission for.
  Future<bool> getLocationFeatureEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_locationFeatureEnabledKey) ?? true;
  }

  Future<void> setLocationFeatureEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_locationFeatureEnabledKey, value);
  }

  /// Notification category names (matching [NotificationCategory.name]) the
  /// traveler has muted — everything not in this set is shown. Empty by
  /// default, so a fresh install shows every category.
  Future<Set<String>> getDisabledCategories() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_disabledCategoriesKey) ?? const []).toSet();
  }

  Future<void> setCategoryEnabled(String categoryName, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    final disabled = (prefs.getStringList(_disabledCategoriesKey) ?? const []).toSet();
    enabled ? disabled.remove(categoryName) : disabled.add(categoryName);
    await prefs.setStringList(_disabledCategoriesKey, disabled.toList());
  }
}
