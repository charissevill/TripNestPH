import 'package:cloud_firestore/cloud_firestore.dart';

/// A named list a traveler groups their favorites into (e.g. "Bohol 2026",
/// "Food to try") — optional and orthogonal to [FavoriteType]: a favorite
/// with no [FavoriteCollection] assigned just stays in the default
/// "Unsorted" view. Backed by the `favorite_collections` Firestore
/// collection.
class FavoriteCollection {
  const FavoriteCollection({
    required this.id,
    required this.userId,
    required this.name,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String name;
  final DateTime createdAt;

  factory FavoriteCollection.fromMap(String id, Map<String, dynamic> map) {
    final timestamp = map['createdAt'];
    return FavoriteCollection(
      id: id,
      userId: map['userId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      createdAt: timestamp is Timestamp ? timestamp.toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {'userId': userId, 'name': name, 'createdAt': FieldValue.serverTimestamp()};
  }
}
