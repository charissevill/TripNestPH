import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/utils/app_exception.dart';
import '../../domain/models/admin_invite.dart';
import '../../domain/models/admin_user.dart';

/// Firestore access for the `admin_users` collection — the Admin Portal's
/// own account directory, separate from the traveler `users` collection —
/// plus `admin_invites`, the staged-role handoff that lets a signed-in
/// traveler self-claim an Admin Portal role without anyone running an
/// out-of-band script.
class AdminRepository {
  AdminRepository({FirebaseFirestore? firestore, FirebaseFunctions? functions})
      : _db = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _collection => _db.collection(FirestorePaths.adminUsers);
  CollectionReference<Map<String, dynamic>> get _invites => _db.collection(FirestorePaths.adminInvites);

  /// Live-updates so a role change or suspension takes effect immediately
  /// without the traveler needing to sign out/in — the same "enforced live"
  /// pattern already used for `AppUser.status` in `AuthProvider`.
  Stream<AdminUser?> streamSelf(String uid) {
    return _collection.doc(uid).snapshots().map((doc) => doc.exists ? AdminUser.fromMap(doc.id, doc.data()!) : null);
  }

  Future<AdminUser?> getById(String uid) async {
    try {
      final doc = await _collection.doc(uid).get();
      if (!doc.exists) return null;
      return AdminUser.fromMap(doc.id, doc.data()!);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Every Admin Portal account — the "Team" screen's roster.
  Stream<List<AdminUser>> streamAll() {
    return _collection.snapshots().map((s) => s.docs.map((d) => AdminUser.fromMap(d.id, d.data())).toList());
  }

  Future<void> setStatus(String uid, String status) async {
    try {
      await _collection.doc(uid).update({'status': status});
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> setRole(String uid, String role) async {
    try {
      await _collection.doc(uid).update({'role': role});
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> removeAdmin(String uid) async {
    try {
      await _collection.doc(uid).delete();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  static String _normalizeEmail(String email) => email.trim().toLowerCase();

  /// Stages [role] for [email] — the invited person must already have an
  /// ordinary TripNest account under this exact email; there's no
  /// server-side account creation here (see `AdminInvite`'s doc comment).
  /// [provinceId]/[provinceName] are only meaningful (and required by the
  /// UI) for an [AdminRole.lgu] invite.
  Future<void> createInvite({
    required String email,
    required String role,
    required String invitedByName,
    String? provinceId,
    String? provinceName,
  }) async {
    try {
      await _invites.doc(_normalizeEmail(email)).set(
            AdminInvite(
              email: _normalizeEmail(email),
              role: role,
              provinceId: provinceId,
              provinceName: provinceName,
              invitedByName: invitedByName,
              createdAt: DateTime.now(),
            ).toMap(),
          );
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Stream<List<AdminInvite>> streamInvites() {
    return _invites.snapshots().map((s) => s.docs.map((d) => AdminInvite.fromMap(d.id, d.data())).toList());
  }

  Future<void> revokeInvite(String email) async {
    try {
      await _invites.doc(_normalizeEmail(email)).delete();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// The invite waiting for [email], if any — checked on Profile so a
  /// freshly-invited user sees an accept/decline prompt.
  Future<AdminInvite?> getPendingInvite(String email) async {
    try {
      final doc = await _invites.doc(_normalizeEmail(email)).get();
      if (!doc.exists) return null;
      return AdminInvite.fromMap(doc.id, doc.data()!);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Self-claim: creates the caller's own `admin_users/{uid}` doc using
  /// exactly the role staged in their invite (enforced server-side by
  /// `firestore.rules`, not just this client call), then clears the
  /// invite so it can't be claimed twice.
  Future<void> claimInvite({
    required String uid,
    required String email,
    required String role,
    required String name,
    String? provinceId,
    String? provinceName,
  }) async {
    try {
      await _collection.doc(uid).set({
        'name': name,
        'email': email,
        'photoUrl': '',
        'businessName': '',
        'role': role,
        'status': 'active',
        'provinceId': provinceId,
        'provinceName': provinceName,
      });
      await _invites.doc(_normalizeEmail(email)).delete();
    } catch (e) {
      throw AppException.from(e);
    }
    // Best-effort: the claim itself already succeeded above regardless of
    // whether this sync does — see syncMyAdminClaims' doc comment.
    try {
      await syncMyAdminClaims();
    } catch (_) {
      // Ignored — see comment above.
    }
  }

  Future<void> declineInvite(String email) => revokeInvite(email);

  /// Calls the `syncMyAdminClaims` Cloud Function to mirror the caller's own
  /// `admin_users` doc into their Auth custom claims, then force-refreshes
  /// the local ID token so the new claims take effect immediately — without
  /// this, `storage.rules`' admin-role checks (province/tourist-spot/
  /// festival/business photo uploads) silently keep failing until the
  /// token's next natural refresh (up to an hour) or a sign-out/in.
  ///
  /// Deliberately a direct client call rather than relying on a Firestore
  /// trigger to react to `admin_users` writes automatically — that trigger
  /// path was tried first and found unreliable on this project (see the
  /// Cloud Function's own doc comment for how that was confirmed). Safe to
  /// call anytime, including for non-admin travelers (it just clears any
  /// stale admin claim).
  Future<void> syncMyAdminClaims() async {
    try {
      await _functions.httpsCallable('syncMyAdminClaims').call();
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
