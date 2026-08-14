import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../utils/app_exception.dart';

/// Thin wrapper around [FirebaseAuth] and [GoogleSignIn] — the only place in
/// the app that talks to the Firebase Auth SDK directly.
class AuthService {
  AuthService({FirebaseAuth? auth, GoogleSignIn? googleSignIn})
      : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<User> registerWithEmail({required String name, required String email, required String password}) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
      await credential.user?.updateDisplayName(name.trim());
      // Best-effort, not fatal: the Auth account already exists at this
      // point (irreversible without a separate delete), and the router
      // redirects to Verify Email based on that account existing regardless
      // of whether this call throws. Letting a network blip here fail the
      // whole registerWithEmail call used to land the traveler on "We sent
      // a verification link" while ALSO showing a registration error — and
      // no email had actually been sent. The Resend button on that screen
      // is the real recovery path if this particular send didn't go out.
      try {
        await credential.user?.sendEmailVerification();
      } catch (_) {}
      return credential.user!;
    } on FirebaseAuthException catch (e) {
      throw AppException.from(e);
    }
  }

  Future<User> signInWithEmail({required String email, required String password}) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
      return credential.user!;
    } on FirebaseAuthException catch (e) {
      throw AppException.from(e);
    }
  }

  Future<User> signInWithGoogle() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        throw const AppException('Sign-in was cancelled.');
      }
      final authentication = await account.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: authentication.accessToken,
        idToken: authentication.idToken,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      return userCredential.user!;
    } on FirebaseAuthException catch (e) {
      throw AppException.from(e);
    }
  }

  /// Deliberately indistinguishable from a genuine send: if the Firebase
  /// project doesn't have Email Enumeration Protection enabled server-side,
  /// propagating `user-not-found` here would let anyone learn which emails
  /// have accounts one attempt at a time. Every other failure (bad network,
  /// rate-limited, etc.) still surfaces normally, since those are actionable
  /// for the traveler without revealing anything about the email itself.
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') return;
      throw AppException.from(e);
    }
  }

  Future<void> sendEmailVerification() async {
    try {
      await _auth.currentUser?.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> reloadCurrentUser() async {
    try {
      await _auth.currentUser?.reload();
    } on FirebaseAuthException catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> updateDisplayName(String name) async {
    try {
      await _auth.currentUser?.updateDisplayName(name.trim());
    } on FirebaseAuthException catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> updateEmail(String newEmail) async {
    try {
      await _auth.currentUser?.verifyBeforeUpdateEmail(newEmail.trim());
    } on FirebaseAuthException catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> updatePassword(String newPassword) async {
    try {
      await _auth.currentUser?.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw AppException.from(e);
    }
  }

  /// Re-authenticates with the given password — required by Firebase before
  /// sensitive actions like changing email/password on an older session.
  Future<void> reauthenticateWithPassword(String password) async {
    try {
      final user = _auth.currentUser;
      final email = user?.email;
      if (user == null || email == null) return;
      await user.reauthenticateWithCredential(EmailAuthProvider.credential(email: email, password: password));
    } on FirebaseAuthException catch (e) {
      throw AppException.from(e);
    }
  }

  /// Deletes the signed-in Firebase Auth user outright — call only after
  /// reauthenticating and after the caller has already removed the
  /// traveler's Firestore data, since this is the point of no return.
  Future<void> deleteFirebaseUser() async {
    try {
      await _auth.currentUser?.delete();
    } on FirebaseAuthException catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> signOut() async {
    await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
  }
}
