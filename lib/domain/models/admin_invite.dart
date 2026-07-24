import 'package:cloud_firestore/cloud_firestore.dart';

/// A role an admin has staged for an email address that doesn't have an
/// `admin_users` doc yet. Backed by `admin_invites/{lowercasedEmail}` — the
/// invited person's own client reads this (by their own auth token email,
/// per `firestore.rules`) and self-claims the exact role staged here via
/// `AdminRepository.claimInvite`.
class AdminInvite {
  const AdminInvite({
    required this.email,
    required this.role,
    required this.invitedByName,
    required this.createdAt,
  });

  /// Lowercased — also the Firestore document id.
  final String email;

  /// One of [AdminRole]'s values.
  final String role;

  /// Display name of the admin who sent this, shown on the recipient's
  /// accept/decline prompt for context.
  final String invitedByName;
  final DateTime createdAt;

  factory AdminInvite.fromMap(String email, Map<String, dynamic> map) {
    final timestamp = map['createdAt'];
    return AdminInvite(
      email: email,
      role: map['role'] as String? ?? '',
      invitedByName: map['invitedByName'] as String? ?? 'An admin',
      createdAt: timestamp is Timestamp ? timestamp.toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'role': role,
      'invitedByName': invitedByName,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
