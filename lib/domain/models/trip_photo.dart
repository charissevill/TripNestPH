import 'package:cloud_firestore/cloud_firestore.dart';

/// A single photo in the traveler's "My Photos" journal, persisted at
/// `trip_photos/{id}`. Auto-tagged with a real place at upload time when the
/// photo's GPS EXIF coordinates resolve to one (see
/// `photo_place_matcher.dart`) — [placeName]/[matchTier]/the id fields all
/// stay null when no confident match was found, never a fabricated guess.
class TripPhoto {
  const TripPhoto({
    required this.id,
    required this.userId,
    required this.photoUrl,
    required this.createdAt,
    this.takenAt,
    this.latitude,
    this.longitude,
    this.placeName,
    this.matchTier,
    this.destinationId,
    this.restaurantId,
    this.placeId,
  });

  final String id;
  final String userId;
  final String photoUrl;

  /// When the Firestore doc was created — always set. Distinct from
  /// [takenAt] (the photo's own EXIF capture time, which may be null for a
  /// photo with no EXIF data at all).
  final DateTime createdAt;

  final DateTime? takenAt;

  /// The photo's GPS EXIF coordinates, when present — the only signal
  /// [placeName] is ever derived from (never an AI guess).
  final double? latitude;
  final double? longitude;

  final String? placeName;

  /// Which tier resolved [placeName] — `'curated'` (a real Firestore
  /// destination/restaurant) or `'live'` (a live Google Places result).
  /// Null alongside [placeName] when nothing matched closely enough.
  final String? matchTier;

  /// Set only when [matchTier] is `'curated'` — mutually exclusive with
  /// [restaurantId]/[placeId], and used to navigate to the real in-app
  /// details page on tap.
  final String? destinationId;
  final String? restaurantId;

  /// Set only when [matchTier] is `'live'` — a Google Places id with no
  /// Firestore page to navigate to (opens `showPlaceDetailsSheet` instead).
  final String? placeId;

  bool get hasCoordinates => latitude != null && longitude != null;
  bool get isTagged => placeName != null;

  factory TripPhoto.fromMap(String id, Map<String, dynamic> map) {
    final createdAt = map['createdAt'];
    final takenAt = map['takenAt'];
    return TripPhoto(
      id: id,
      userId: map['userId'] as String? ?? '',
      photoUrl: map['photoUrl'] as String? ?? '',
      createdAt: createdAt is Timestamp ? createdAt.toDate() : DateTime.now(),
      takenAt: takenAt is Timestamp ? takenAt.toDate() : null,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      placeName: map['placeName'] as String?,
      matchTier: map['matchTier'] as String?,
      destinationId: map['destinationId'] as String?,
      restaurantId: map['restaurantId'] as String?,
      placeId: map['placeId'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'photoUrl': photoUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'takenAt': takenAt != null ? Timestamp.fromDate(takenAt!) : null,
      'latitude': latitude,
      'longitude': longitude,
      'placeName': placeName,
      'matchTier': matchTier,
      'destinationId': destinationId,
      'restaurantId': restaurantId,
      'placeId': placeId,
    };
  }
}
