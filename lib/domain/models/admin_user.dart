/// An Admin Portal account, stored at `admin_users/{uid}` — entirely
/// separate from the traveler `users/{uid}` profile (see
/// `firestore.rules`'s "Admin Portal role helpers" section). The uid is the
/// same Firebase Auth uid as the traveler account; having a doc here is
/// what elevates that account into one of [role]'s permissions.
class AdminUser {
  const AdminUser({
    required this.uid,
    required this.name,
    required this.email,
    this.photoUrl = '',
    this.businessName = '',
    required this.role,
    this.status = 'active',
  });

  final String uid;
  final String name;
  final String email;
  final String photoUrl;

  /// Only meaningful for [AdminRole.businessOwner] accounts.
  final String businessName;

  /// One of [AdminRole]'s values — matches `firestore.rules`'s
  /// `hasAdminRole(roles)` checks exactly, so this stays a plain string
  /// rather than an enum to avoid a serialization mismatch with the rules.
  final String role;

  /// 'active' | 'suspended' — only an existing admin can flip this
  /// (enforced server-side); a suspended account keeps its doc but loses
  /// every `hasAdminRole` check.
  final String status;

  bool get isActive => status == 'active';

  factory AdminUser.fromMap(String uid, Map<String, dynamic> map) {
    return AdminUser(
      uid: uid,
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      photoUrl: map['photoUrl'] as String? ?? '',
      businessName: map['businessName'] as String? ?? '',
      role: map['role'] as String? ?? '',
      status: map['status'] as String? ?? 'active',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'businessName': businessName,
      'role': role,
      'status': status,
    };
  }
}

/// The three roles `firestore.rules` recognizes for `admin_users.role`.
class AdminRole {
  AdminRole._();

  static const String admin = 'admin';
  static const String lgu = 'lgu';
  static const String businessOwner = 'businessOwner';
}
