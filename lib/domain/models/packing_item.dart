import 'itinerary.dart';

/// One line of a saved itinerary's packing checklist.
class PackingItem {
  const PackingItem({required this.id, required this.label, required this.checked});

  final String id;
  final String label;
  final bool checked;

  factory PackingItem.fromMap(Map<String, dynamic> map) {
    return PackingItem(
      id: map['id'] as String? ?? '',
      label: map['label'] as String? ?? '',
      checked: map['checked'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {'id': id, 'label': label, 'checked': checked};

  PackingItem copyWith({String? label, bool? checked}) {
    return PackingItem(id: id, label: label ?? this.label, checked: checked ?? this.checked);
  }

  /// Sensible starting checklist seeded onto every newly-saved itinerary —
  /// travelers can rename, remove, or add to it freely afterward.
  static List<PackingItem> defaults() {
    const labels = [
      'Passport / valid ID',
      'Cash and cards',
      'Phone charger & power bank',
      'Medications',
      'Sunscreen',
      'Swimwear',
      'Rain gear / light jacket',
      'Toiletries',
    ];
    return [
      for (var i = 0; i < labels.length; i++) PackingItem(id: 'default-$i', label: labels[i], checked: false),
    ];
  }

  /// [defaults] plus a few extra items driven by the itinerary's own
  /// already-fetched forecast (see `AiRepository`'s weather-aware
  /// generation) — no new API call, just reading data the itinerary was
  /// generated with. Falls back to exactly [defaults] when there's no
  /// forecast on file (an itinerary saved before weather was attached, or
  /// the forecast fetch failed at generation time), so this is a pure
  /// addition, never a worse list than before it existed.
  static List<PackingItem> suggestedFor(Itinerary itinerary) {
    final base = defaults();
    if (itinerary.weather.isEmpty) return base;

    final conditions = itinerary.weather.map((w) => w.condition).toSet();
    final lowTemps = itinerary.weather.map((w) => w.lowTemp).toList();

    final extras = <String>[];
    if (conditions.any({'Rainy', 'Showers', 'Thunderstorm'}.contains)) {
      extras.addAll(['Umbrella', 'Waterproof bag / dry bag for electronics']);
    }
    if (conditions.any({'Sunny', 'Partly Cloudy'}.contains)) {
      extras.addAll(['Sunglasses', 'Hat or cap']);
    }
    // Cool by Philippine standards, not by a temperate-climate one — this
    // is what actually distinguishes a highland trip (Baguio, Sagada) from
    // a typical lowland/coastal one in the forecast data.
    if (lowTemps.isNotEmpty && lowTemps.reduce((a, b) => a < b ? a : b) < 22) {
      extras.add('Extra warm layer for cool mornings/evenings');
    }

    return [
      ...base,
      for (var i = 0; i < extras.length; i++) PackingItem(id: 'weather-$i', label: extras[i], checked: false),
    ];
  }
}
