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
}
