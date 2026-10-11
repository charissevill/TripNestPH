import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/utils/app_exception.dart';
import '../../domain/models/app_notification.dart';
import '../../domain/models/business_owner_application.dart';
import 'admin_repository.dart';
import 'notification_repository.dart';

/// Firestore access for the `business_owner_applications` collection — see
/// [BusinessOwnerApplication]'s doc comment for why approving one stages an
/// `admin_invites` entry (via the existing [AdminRepository.createInvite])
/// rather than writing `admin_users` directly.
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
    required String phone,
    required String description,
    required String address,
    required double latitude,
    required double longitude,
    required String permitUrl,
    required String idUrl,
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
          phone: phone,
          description: description,
          address: address,
          latitude: latitude,
          longitude: longitude,
          permitUrl: permitUrl,
          idUrl: idUrl,
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

  /// Stages the `businessOwner` role for the applicant (same
  /// `admin_invites` handoff any manually-invited admin already goes
  /// through — the applicant still explicitly accepts it via Profile's
  /// pending-invite banner, this doesn't grant anything by itself), marks
  /// the application approved, then best-effort notifies the applicant so
  /// they know to go accept it rather than relying on them noticing the
  /// banner on their own.
  Future<void> approve(BusinessOwnerApplication application, {required String adminName}) async {
    try {
      await _adminRepository.createInvite(
        email: application.applicantEmail,
        role: 'businessOwner',
        invitedByName: adminName,
      );
      await _collection.doc(application.id).update({'status': BusinessOwnerApplicationStatus.approved});
    } catch (e) {
      throw AppException.from(e);
    }
    try {
      await _notificationRepository.createForUser(
        userId: application.userId,
        title: 'Your business owner application was approved',
        body: 'Open Profile and accept your new role to access the Admin Portal.',
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
