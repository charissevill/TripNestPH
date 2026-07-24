import 'package:cloud_firestore/cloud_firestore.dart';

/// The signed-in traveler's profile document, stored at `users/{uid}`.
class AppUser {
  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    this.photoUrl = '',
    this.travelPreferences = const [],
    this.favoriteCategories = const [],
    this.emailVerified = false,
    this.createdAt,
    this.status = 'active',
  });

  final String uid;
  final String name;
  final String email;
  final String photoUrl;
  final List<String> travelPreferences;
  final List<String> favoriteCategories;
  final bool emailVerified;
  final DateTime? createdAt;

  /// Set by the Admin Portal ('active' | 'suspended') — never writable by
  /// the traveler themselves, enforced in firestore.rules.
  final String status;

  bool get isSuspended => status == 'suspended';

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) {
    final timestamp = map['createdAt'];
    return AppUser(
      uid: uid,
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      photoUrl: map['photoUrl'] as String? ?? '',
      travelPreferences: List<String>.from(map['travelPreferences'] as List? ?? const []),
      favoriteCategories: List<String>.from(map['favoriteCategories'] as List? ?? const []),
      emailVerified: map['emailVerified'] as bool? ?? false,
      createdAt: timestamp is Timestamp ? timestamp.toDate() : null,
      status: map['status'] as String? ?? 'active',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'travelPreferences': travelPreferences,
      'favoriteCategories': favoriteCategories,
      'emailVerified': emailVerified,
    };
  }

  AppUser copyWith({
    String? name,
    String? photoUrl,
    List<String>? travelPreferences,
    List<String>? favoriteCategories,
    bool? emailVerified,
  }) {
    return AppUser(
      uid: uid,
      name: name ?? this.name,
      email: email,
      photoUrl: photoUrl ?? this.photoUrl,
      travelPreferences: travelPreferences ?? this.travelPreferences,
      favoriteCategories: favoriteCategories ?? this.favoriteCategories,
      emailVerified: emailVerified ?? this.emailVerified,
      createdAt: createdAt,
      status: status,
    );
  }
}
