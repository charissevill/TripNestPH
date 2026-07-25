import 'package:cloud_firestore/cloud_firestore.dart';

/// A cultural festival or seasonal event shown on Home and Festival Details.
/// Backed by the `festivals` Firestore collection.
class Festival {
  const Festival({
    required this.id,
    required this.name,
    required this.provinceId,
    required this.provinceName,
    required this.regionId,
    this.cityId = '',
    required this.heroImageUrl,
    required this.galleryImageUrls,
    required this.dateLabel,
    required this.month,
    required this.description,
    required this.highlights,
    required this.rating,
    required this.reviewCount,
    this.isUpcoming = false,
    this.organizer = '',
    this.registrationLink = '',
    this.venue = '',
    this.facebookUrl = '',
    this.latitude,
    this.longitude,
    this.startDate,
    this.endDate,
  });

  final String id;
  final String name;

  /// References `provinces/{provinceId}`.
  final String provinceId;

  /// Denormalized display name — avoids an extra province lookup on every
  /// card/list that shows a location label.
  final String provinceName;

  /// Denormalized — lets region-level filtering/display skip a province
  /// lookup, same reasoning as [provinceName].
  final String regionId;

  /// References `provinces/{provinceId}/cities/{cityId}`, empty when this
  /// festival isn't tied to an on-demand city doc.
  final String cityId;

  final String heroImageUrl;
  final List<String> galleryImageUrls;

  /// Human-readable date range, e.g. "January 15–21, 2027".
  final String dateLabel;

  /// Short month label for compact badges, e.g. "JAN".
  final String month;
  final String description;
  final List<String> highlights;
  final double rating;
  final int reviewCount;
  final bool isUpcoming;
  final String organizer;
  final String registrationLink;
  final String venue;
  final String facebookUrl;
  final double? latitude;
  final double? longitude;

  /// Structured backing for [dateLabel]/[month], set via the admin form's
  /// date picker. Nullable/additive — festivals created before this field
  /// existed only have the formatted [dateLabel] string, not a real date.
  final DateTime? startDate;

  /// Null for a single-day festival; set only when [startDate] differs from
  /// the last day of a multi-day event.
  final DateTime? endDate;

  bool get hasCoordinates => latitude != null && longitude != null;

  factory Festival.fromMap(String id, Map<String, dynamic> map) {
    return Festival(
      id: id,
      name: map['name'] as String? ?? '',
      provinceId: map['provinceId'] as String? ?? '',
      provinceName: map['provinceName'] as String? ?? '',
      regionId: map['regionId'] as String? ?? '',
      cityId: map['cityId'] as String? ?? '',
      heroImageUrl: map['heroImageUrl'] as String? ?? '',
      galleryImageUrls: List<String>.from(
        map['galleryImageUrls'] as List? ?? const [],
      ),
      dateLabel: map['dateLabel'] as String? ?? '',
      month: map['month'] as String? ?? '',
      description: map['description'] as String? ?? '',
      highlights: List<String>.from(map['highlights'] as List? ?? const []),
      rating: (map['rating'] as num?)?.toDouble() ?? 0,
      reviewCount: (map['reviewCount'] as num?)?.toInt() ?? 0,
      isUpcoming: map['isUpcoming'] as bool? ?? false,
      organizer: map['organizer'] as String? ?? '',
      registrationLink: map['registrationLink'] as String? ?? '',
      venue: map['venue'] as String? ?? '',
      facebookUrl: map['facebookUrl'] as String? ?? '',
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      startDate: (map['startDate'] as Timestamp?)?.toDate(),
      endDate: (map['endDate'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'provinceId': provinceId,
      'provinceName': provinceName,
      'regionId': regionId,
      'cityId': cityId,
      'heroImageUrl': heroImageUrl,
      'galleryImageUrls': galleryImageUrls,
      'dateLabel': dateLabel,
      'month': month,
      'description': description,
      'highlights': highlights,
      'rating': rating,
      'reviewCount': reviewCount,
      'isUpcoming': isUpcoming,
      'organizer': organizer,
      'registrationLink': registrationLink,
      'venue': venue,
      'facebookUrl': facebookUrl,
      'latitude': latitude,
      'longitude': longitude,
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
    };
  }

  Festival copyWith({double? rating, int? reviewCount}) {
    return Festival(
      id: id,
      name: name,
      provinceId: provinceId,
      provinceName: provinceName,
      regionId: regionId,
      cityId: cityId,
      heroImageUrl: heroImageUrl,
      galleryImageUrls: galleryImageUrls,
      dateLabel: dateLabel,
      month: month,
      description: description,
      highlights: highlights,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      isUpcoming: isUpcoming,
      organizer: organizer,
      registrationLink: registrationLink,
      venue: venue,
      facebookUrl: facebookUrl,
      latitude: latitude,
      longitude: longitude,
      startDate: startDate,
      endDate: endDate,
    );
  }
}
