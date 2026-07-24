/// One of the Philippines' 17 official regions. Backed by the `regions`
/// Firestore collection — a small, fixed reference list (unlike the
/// ever-growing content collections), so it's always loaded in full via
/// [RegionRepository.getAll] rather than paginated or filtered.
class Region {
  const Region({required this.id, required this.name, required this.islandGroup});

  final String id;
  final String name;

  /// 'Luzon', 'Visayas', or 'Mindanao' — used to group the region picker.
  final String islandGroup;

  factory Region.fromMap(String id, Map<String, dynamic> map) {
    return Region(
      id: id,
      name: map['name'] as String? ?? '',
      islandGroup: map['islandGroup'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {'name': name, 'islandGroup': islandGroup};
}
