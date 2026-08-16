/// One of the Philippines' 82 provinces, plus one pseudo-province for Metro
/// Manila. Backed by the `provinces` Firestore collection — like [Region], a
/// small fixed reference list always loaded in full via
/// [ProvinceRepository.getAll].
///
/// Two simplifications, both deliberate:
/// - NCR has no provinces in the official PSA list (it's composed directly
///   of cities). Rather than model its 4 legislative districts as
///   pseudo-provinces travelers don't think in, NCR is a single
///   pseudo-province (`metro-manila`, [isPseudoProvince] = true).
/// - Chartered cities administratively independent of their surrounding
///   province (Baguio, Cebu City, Davao City, ...) are nested under the
///   *geographic* province they sit in, not left province-less — that's how
///   travelers browse, even though it's not how PSA administration works.
class Province {
  const Province({
    required this.id,
    required this.name,
    required this.regionId,
    required this.regionName,
    required this.islandGroup,
    this.isPseudoProvince = false,
    this.hasContent = false,
    this.overview = '',
    this.localCulture = '',
    this.cultureNotes = const [],
    this.localTransport = const [],
    this.bestTimeToVisit = '',
    this.estimatedDailyBudgetMin = 0,
    this.estimatedDailyBudgetMax = 0,
    this.travelTips = const [],
    this.emergencyHotlines = const [],
    this.heroImageUrl = '',
    this.galleryImageUrls = const [],
    this.featuredDestinationIds = const [],
  });

  final String id;
  final String name;
  final String regionId;

  /// Denormalized — lets a province card/badge render the region name
  /// without an extra lookup, same reasoning as [islandGroup] below.
  final String regionName;
  final String islandGroup;
  final bool isPseudoProvince;

  /// Gates the province page's content sections. False for provinces that
  /// only exist as taxonomy today — the page shows a "content coming soon"
  /// state instead of empty overview/culture/tips fields.
  final bool hasContent;

  final String overview;

  /// The original free-text culture field — still written to and still
  /// shown as a fallback paragraph when [cultureNotes] is empty (most
  /// existing provinces, until an admin fills those in for it too).
  final String localCulture;

  /// Short, titled etiquette notes (e.g. "Greeting customs", "Dress at
  /// religious sites") shown as scannable cards on the province page,
  /// instead of [localCulture]'s single dense paragraph. Optional and
  /// additive — a province with none just falls back to [localCulture].
  final List<CultureNote> cultureNotes;

  /// Practical getting-around notes (e.g. "Jeepney" — "Flag down anywhere
  /// along the route, ₱13 minimum fare") shown both on the province page and
  /// surfaced on a generated itinerary for this province, since a traveler
  /// reading their day plan is exactly when this is most useful. Optional
  /// and additive, same as [cultureNotes] — a province with none just shows
  /// no Getting Around section anywhere.
  final List<TransportNote> localTransport;
  final String bestTimeToVisit;
  final double estimatedDailyBudgetMin;
  final double estimatedDailyBudgetMax;
  final List<String> travelTips;
  final List<EmergencyHotline> emergencyHotlines;
  final String heroImageUrl;

  /// Additional photos for the province page's swipeable gallery — the
  /// hero image is always shown first, these fill out the rest of the
  /// slideshow (see `DetailsGalleryAppBar`, the same widget destinations/
  /// restaurants/festivals already use).
  final List<String> galleryImageUrls;

  /// Curated ids into `tourist_spots` for this province's page — falls back
  /// to a plain `provinceId` filter query when empty.
  final List<String> featuredDestinationIds;

  factory Province.fromMap(String id, Map<String, dynamic> map) {
    return Province(
      id: id,
      name: map['name'] as String? ?? '',
      regionId: map['regionId'] as String? ?? '',
      regionName: map['regionName'] as String? ?? '',
      islandGroup: map['islandGroup'] as String? ?? '',
      isPseudoProvince: map['isPseudoProvince'] as bool? ?? false,
      hasContent: map['hasContent'] as bool? ?? false,
      overview: map['overview'] as String? ?? '',
      localCulture: map['localCulture'] as String? ?? '',
      cultureNotes: (map['cultureNotes'] as List? ?? const [])
          .map((n) => CultureNote.fromMap(Map<String, dynamic>.from(n as Map)))
          .toList(),
      localTransport: (map['localTransport'] as List? ?? const [])
          .map((n) => TransportNote.fromMap(Map<String, dynamic>.from(n as Map)))
          .toList(),
      bestTimeToVisit: map['bestTimeToVisit'] as String? ?? '',
      estimatedDailyBudgetMin: (map['estimatedDailyBudgetMin'] as num?)?.toDouble() ?? 0,
      estimatedDailyBudgetMax: (map['estimatedDailyBudgetMax'] as num?)?.toDouble() ?? 0,
      travelTips: List<String>.from(map['travelTips'] as List? ?? const []),
      emergencyHotlines: (map['emergencyHotlines'] as List? ?? const [])
          .map((e) => EmergencyHotline.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      heroImageUrl: map['heroImageUrl'] as String? ?? '',
      galleryImageUrls: List<String>.from(map['galleryImageUrls'] as List? ?? const []),
      featuredDestinationIds: List<String>.from(map['featuredDestinationIds'] as List? ?? const []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'regionId': regionId,
      'regionName': regionName,
      'islandGroup': islandGroup,
      'isPseudoProvince': isPseudoProvince,
      'hasContent': hasContent,
      'overview': overview,
      'localCulture': localCulture,
      'cultureNotes': cultureNotes.map((n) => n.toMap()).toList(),
      'localTransport': localTransport.map((n) => n.toMap()).toList(),
      'bestTimeToVisit': bestTimeToVisit,
      'estimatedDailyBudgetMin': estimatedDailyBudgetMin,
      'estimatedDailyBudgetMax': estimatedDailyBudgetMax,
      'travelTips': travelTips,
      'emergencyHotlines': emergencyHotlines.map((h) => h.toMap()).toList(),
      'heroImageUrl': heroImageUrl,
      'galleryImageUrls': galleryImageUrls,
      'featuredDestinationIds': featuredDestinationIds,
    };
  }
}

class CultureNote {
  const CultureNote({required this.title, required this.body});

  final String title;
  final String body;

  factory CultureNote.fromMap(Map<String, dynamic> map) {
    return CultureNote(title: map['title'] as String? ?? '', body: map['body'] as String? ?? '');
  }

  Map<String, dynamic> toMap() => {'title': title, 'body': body};
}

class TransportNote {
  const TransportNote({required this.mode, required this.note});

  /// The mode of transport, e.g. "Jeepney", "Tricycle", "Habal-habal".
  final String mode;
  final String note;

  factory TransportNote.fromMap(Map<String, dynamic> map) {
    return TransportNote(mode: map['mode'] as String? ?? '', note: map['note'] as String? ?? '');
  }

  Map<String, dynamic> toMap() => {'mode': mode, 'note': note};
}

class EmergencyHotline {
  const EmergencyHotline({required this.label, required this.number});

  final String label;
  final String number;

  factory EmergencyHotline.fromMap(Map<String, dynamic> map) {
    return EmergencyHotline(label: map['label'] as String? ?? '', number: map['number'] as String? ?? '');
  }

  Map<String, dynamic> toMap() => {'label': label, 'number': number};
}

/// A city/municipality nested under a province, created on demand as real
/// content references it (see `ProvinceRepository.ensureCity`) rather than
/// pre-seeded — the Philippines has ~1,634 of these, far more than this
/// phase needs to enumerate upfront.
class City {
  const City({required this.id, required this.name, required this.provinceId, required this.regionId});

  final String id;
  final String name;
  final String provinceId;
  final String regionId;

  factory City.fromMap(String id, Map<String, dynamic> map) {
    return City(
      id: id,
      name: map['name'] as String? ?? '',
      provinceId: map['provinceId'] as String? ?? '',
      regionId: map['regionId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {'name': name, 'provinceId': provinceId, 'regionId': regionId};
}
