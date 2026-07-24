import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../data/repositories/admin_repository.dart';
import '../../data/repositories/favorites_repository.dart';
import '../../data/repositories/itinerary_repository.dart';
import '../../data/repositories/review_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../domain/models/app_user.dart';
import '../services/auth_service.dart';
import '../utils/app_exception.dart';
import '../utils/view_status.dart';

/// Drives every auth-related screen (Login, Register, Forgot Password,
/// Verify Email) and exposes the signed-in [AppUser] profile to the rest of
/// the app. The single source of truth for "is someone signed in".
class AuthProvider extends ChangeNotifier {
  AuthProvider({
    AuthService? authService,
    UserRepository? userRepository,
    FavoritesRepository? favoritesRepository,
    ItineraryRepository? itineraryRepository,
    ReviewRepository? reviewRepository,
    AdminRepository? adminRepository,
  })  : _authService = authService ?? AuthService(),
        _userRepository = userRepository ?? UserRepository(),
        _favoritesRepositoryOverride = favoritesRepository,
        _itineraryRepositoryOverride = itineraryRepository,
        _reviewRepositoryOverride = reviewRepository,
        _adminRepositoryOverride = adminRepository {
    _authSubscription = _authService.authStateChanges.listen(_onAuthStateChanged);
  }

  final AuthService _authService;
  final UserRepository _userRepository;

  // Only needed by the rare account-deletion path, so these are built
  // lazily on first use rather than at construction time — constructing
  // AuthProvider (e.g. at app startup, or in a widget test with no real
  // Firebase Storage/Firestore backing) never pays for them unnecessarily.
  final FavoritesRepository? _favoritesRepositoryOverride;
  final ItineraryRepository? _itineraryRepositoryOverride;
  final ReviewRepository? _reviewRepositoryOverride;
  final AdminRepository? _adminRepositoryOverride;
  FavoritesRepository? _favoritesRepositoryInstance;
  ItineraryRepository? _itineraryRepositoryInstance;
  ReviewRepository? _reviewRepositoryInstance;
  AdminRepository? _adminRepositoryInstance;

  FavoritesRepository get _favoritesRepository =>
      _favoritesRepositoryOverride ?? (_favoritesRepositoryInstance ??= FavoritesRepository());
  ItineraryRepository get _itineraryRepository =>
      _itineraryRepositoryOverride ?? (_itineraryRepositoryInstance ??= ItineraryRepository());
  ReviewRepository get _reviewRepository => _reviewRepositoryOverride ?? (_reviewRepositoryInstance ??= ReviewRepository());
  AdminRepository get _adminRepository => _adminRepositoryOverride ?? (_adminRepositoryInstance ??= AdminRepository());

  late final StreamSubscription<User?> _authSubscription;
  StreamSubscription<AppUser?>? _profileSubscription;

  User? _firebaseUser;
  AppUser? _appUser;
  ViewStatus _status = ViewStatus.loading;
  String? errorMessage;
  bool _busy = false;

  User? get firebaseUser => _firebaseUser;
  AppUser? get currentUser => _appUser;
  ViewStatus get status => _status;
  bool get isBusy => _busy;
  bool get isSignedIn => _firebaseUser != null;
  bool get isEmailVerified => _firebaseUser?.emailVerified ?? false;

  Future<void> _onAuthStateChanged(User? user) async {
    _firebaseUser = user;
    _profileSubscription?.cancel();
    if (user == null) {
      _appUser = null;
      _status = ViewStatus.loaded;
      notifyListeners();
      return;
    }
    await _userRepository.createIfMissing(
      uid: user.uid,
      name: user.displayName ?? 'Traveler',
      email: user.email ?? '',
      photoUrl: user.photoURL ?? '',
    );
    unawaited(_syncAdminClaimsBestEffort());
    _profileSubscription = _userRepository.streamUser(user.uid).listen((profile) async {
      // Enforced live, not just at sign-in: if an admin suspends this
      // account while the traveler is mid-session, the next profile
      // snapshot signs them out immediately.
      if (profile != null && profile.isSuspended) {
        _appUser = null;
        _status = ViewStatus.loaded;
        errorMessage = 'This account has been suspended. Contact support for help.';
        notifyListeners();
        await _authService.signOut();
        return;
      }
      // Backfills the Google profile photo for accounts created before this
      // was wired up (or that signed up with email and later linked Google) —
      // never overwrites a photo the traveler chose in-app.
      if (profile != null && profile.photoUrl.isEmpty && (user.photoURL ?? '').isNotEmpty) {
        await _userRepository.updateProfile(user.uid, {'photoUrl': user.photoURL});
      }
      _appUser = profile;
      _status = ViewStatus.loaded;
      notifyListeners();
    });
  }

  /// Picks up any Admin Portal role/status claim change (see
  /// `AdminRepository.syncMyAdminClaims`) that happened since this token was
  /// last minted — an already-cached session otherwise keeps using a stale
  /// token for up to an hour, which would make a freshly granted (or
  /// revoked) Storage-write role silently not take effect until the
  /// token's natural refresh. Cheap and harmless every cold start/sign-in
  /// even for travelers with no admin claims at all.
  ///
  /// Must never surface a failure to the caller: this runs on every sign-in
  /// for every user, admin or not, so a Cloud Functions hiccup (or, in a
  /// test harness with no real Firebase project behind it, an entirely
  /// absent one) can't be allowed to break sign-in itself.
  Future<void> _syncAdminClaimsBestEffort() async {
    try {
      await _adminRepository.syncMyAdminClaims();
    } catch (_) {
      // Ignored — see doc comment above.
    }
  }

  Future<bool> _run(Future<void> Function() action) async {
    _busy = true;
    errorMessage = null;
    notifyListeners();
    try {
      await action();
      _busy = false;
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = AppException.from(e).message;
      _busy = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({required String name, required String email, required String password}) {
    return _run(() => _authService.registerWithEmail(name: name, email: email, password: password));
  }

  Future<bool> signIn({required String email, required String password}) {
    return _run(() => _authService.signInWithEmail(email: email, password: password));
  }

  Future<bool> signInWithGoogle() => _run(_authService.signInWithGoogle);

  Future<bool> sendPasswordResetEmail(String email) => _run(() => _authService.sendPasswordResetEmail(email));

  Future<bool> resendVerificationEmail() => _run(_authService.sendEmailVerification);

  Future<bool> refreshEmailVerified() async {
    final ok = await _run(_authService.reloadCurrentUser);
    _firebaseUser = _authService.currentUser;
    notifyListeners();
    return ok;
  }

  Future<bool> updateName(String name) => _run(() async {
        await _authService.updateDisplayName(name);
        if (_firebaseUser != null) {
          await _userRepository.updateProfile(_firebaseUser!.uid, {'name': name});
        }
      });

  Future<bool> updateTravelPreferences(List<String> preferences) => _run(() async {
        if (_firebaseUser != null) {
          await _userRepository.updateProfile(_firebaseUser!.uid, {'travelPreferences': preferences});
        }
      });

  Future<bool> updateFavoriteCategories(List<String> categories) => _run(() async {
        if (_firebaseUser != null) {
          await _userRepository.updateProfile(_firebaseUser!.uid, {'favoriteCategories': categories});
        }
      });

  Future<bool> updatePhotoUrl(String url) => _run(() async {
        if (_firebaseUser != null) {
          await _userRepository.updateProfile(_firebaseUser!.uid, {'photoUrl': url});
        }
      });

  Future<bool> changeEmail({required String newEmail, required String currentPassword}) => _run(() async {
        await _authService.reauthenticateWithPassword(currentPassword);
        await _authService.updateEmail(newEmail);
      });

  Future<bool> changePassword({required String newPassword, required String currentPassword}) => _run(() async {
        await _authService.reauthenticateWithPassword(currentPassword);
        await _authService.updatePassword(newPassword);
      });

  /// Permanently deletes the signed-in traveler's account: reauthenticates,
  /// removes every review/favorite/saved-itinerary/profile doc they own,
  /// then deletes the Firebase Auth user itself. Order matters — Firestore
  /// data is removed first, while the user is still authenticated enough
  /// to pass the owner-only security rules; the Auth user goes last since
  /// that step can't be undone.
  Future<bool> deleteAccount({required String currentPassword}) => _run(() async {
        final uid = _firebaseUser?.uid;
        if (uid == null) return;
        await _authService.reauthenticateWithPassword(currentPassword);
        final reviews = await _reviewRepository.getByUser(uid);
        for (final review in reviews) {
          await _reviewRepository.deleteReview(review);
        }
        await _favoritesRepository.deleteAllForUser(uid);
        await _itineraryRepository.deleteAllForUser(uid);
        await _userRepository.deleteAccountData(uid);
        await _authService.deleteFirebaseUser();
      });

  Future<void> signOut() async {
    await _authService.signOut();
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    _profileSubscription?.cancel();
    super.dispose();
  }
}
