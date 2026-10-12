import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/utils/app_exception.dart';
import '../../domain/models/app_notification.dart';
import '../../domain/models/business_owner_application.dart';
import 'admin_repository.dart';
import 'notification_repository.dart';

/// Firestore access for the `business_owner_applications` collection — see
/// [BusinessOwnerApplication]'s doc comment for how approving one grants
/// the role (via [AdminRepository.grantRole]).
class BusinessOwnerApplicationRepository {
  BusinessOwnerApplicationRepository({
    FirebaseFirestore? firestore,
    AdminRepository? adminRepository,
    NotificationRepository? notificationRepository,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _adminRepository = adminRepository ?? AdminRepository(),
        _notificationRepository = notificationRepository ?? NotificationRepository();

  final FirebaseFirestore _db;
  final AdminRepository _adminRepository;
  final NotificationRepository _notificationRepository;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _db.collection(FirestorePaths.businessOwnerApplications);

  /// Returns the new application's id — the caller needs it to kick off
  /// the permit OCR (`OcrService.extractApplicationText`).
  Future<String> submit({
    required String userId,
    required String applicantName,
    required String applicantEmail,
    required String businessName,
    required String category,
    required String address,
    required double latitude,
    required double longitude,
    required String permitUrl,
    required String idUrl,
    PermitFields confirmedPermitFields = const PermitFields(),
    String confirmedIdName = '',
  }) async {
    try {
      final doc = await _collection.add(
        BusinessOwnerApplication(
          id: '',
          userId: userId,
          applicantName: applicantName,
          applicantEmail: applicantEmail,
          businessName: businessName,
          category: category,
          // No longer asked for on the form.
          description: '',
          address: address,
          latitude: latitude,
          longitude: longitude,
          permitUrl: permitUrl,
          idUrl: idUrl,
          confirmedPermitFields: confirmedPermitFields,
          confirmedIdName: confirmedIdName,
          status: BusinessOwnerApplicationStatus.pending,
          createdAt: DateTime.now(),
        ).toMap(),
      );
      return doc.id;
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Admin-only review queue, newest first.
  Stream<List<BusinessOwnerApplication>> streamPendingForAdmin() {
    return _collection
        .where('status', isEqualTo: BusinessOwnerApplicationStatus.pending)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => BusinessOwnerApplication.fromMap(d.id, d.data())).toList());
  }

  /// [userId]'s own most recent approved application, or null — what
  /// `MyBusinessScreen` seeds a first listing's form from, so the owner
  /// doesn't retype what an admin already reviewed. Filters on `userId`
  /// alone (the one query shape firestore.rules allows a non-admin) and
  /// narrows to approved here, so it needs no composite index.
  Future<BusinessOwnerApplication?> getLatestApprovedForUser(String userId) async {
    try {
      final snapshot = await _collection.where('userId', isEqualTo: userId).get();
      final approved = snapshot.docs
          .map((d) => BusinessOwnerApplication.fromMap(d.id, d.data()))
          .where((a) => a.status == BusinessOwnerApplicationStatus.approved)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return approved.isEmpty ? null : approved.first;
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Grants the applicant the `businessOwner` role outright (no invite to
  /// accept — applying was already them asking for it), marks the
  /// application approved, then best-effort notifies the applicant that
  /// their account switched over.
  Future<void> approve(BusinessOwnerApplication application) async {
    try {
      await _adminRepository.grantRole(
        uid: application.userId,
        email: application.applicantEmail,
        name: application.applicantName,
        role: 'businessOwner',
      );
      await _collection.doc(application.id).update({'status': BusinessOwnerApplicationStatus.approved});
    } catch (e) {
      throw AppException.from(e);
    }
    try {
      await _notificationRepository.createForUser(
        userId: application.userId,
        title: 'Your business owner application was approved',
        body: 'Your account is now a Business Owner account — open My Business to set up your listing.',
        category: NotificationCategory.general,
      );
    } catch (_) {
      // Best-effort — the approval itself already succeeded above.
    }
  }

  Future<void> reject(String id, String reason) async {
    try {
      await _collection.doc(id).update({
        'status': BusinessOwnerApplicationStatus.rejected,
        'rejectionReason': reason,
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> withdraw(String id) async {
    try {
      await _collection.doc(id).delete();
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
