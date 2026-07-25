/// A named font family the traveler can pick in Settings — a curated
/// preset list (not a free-form font picker) matching the same "curated,
/// not arbitrary" spirit as [ThemePreset].
class FontFamilyOption {
  const FontFamilyOption(this.name, this.familyName);

  final String name;

  /// Exact, case-sensitive Google Fonts family name passed to
  /// `GoogleFonts.getTextTheme` — must match the catalog name precisely.
  final String familyName;
}

/// First entry is exactly the app's default typeface ('Poppins'), so a
/// traveler who never opens the picker sees the app exactly as it looks
/// today.
const List<FontFamilyOption> fontFamilyOptions = [
  FontFamilyOption('Poppins (Default)', 'Poppins'),
  FontFamilyOption('Inter', 'Inter'),
  FontFamilyOption('Nunito', 'Nunito'),
  FontFamilyOption('Merriweather', 'Merriweather'),
];

/// A named text-size preset, applied app-wide via a root-level `TextScaler`
/// override (see `TypographyProvider`) rather than rewriting every
/// `TextStyle`'s `fontSize`.
class FontSizeOption {
  const FontSizeOption(this.name, this.scale);

  final String name;
  final double scale;
}

const List<FontSizeOption> fontSizeOptions = [
  FontSizeOption('Small', 0.9),
  FontSizeOption('Default', 1.0),
  FontSizeOption('Large', 1.15),
  FontSizeOption('Extra Large', 1.3),
];
