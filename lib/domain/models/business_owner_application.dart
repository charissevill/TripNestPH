import 'package:cloud_firestore/cloud_firestore.dart';

/// Status of a [BusinessOwnerApplication] — `pending` until an admin
/// resolves it via [BusinessOwnerApplicationRepository.approve]/`reject`.
class BusinessOwnerApplicationStatus {
  BusinessOwnerApplicationStatus._();

  static const String pending = 'pending';
  static const String approved = 'approved';
  static const String rejected = 'rejected';
}

/// A traveler's self-service request, from the "Business Owner" choice on
/// the sign-up form itself (`RegisterScreen`'s role toggle), to be granted
/// the `businessOwner` Admin Portal role. Backed by the
/// `business_owner_applications` Firestore collection.
/// Deliberately just a request — approving one doesn't touch `admin_users`
/// directly, it stages an `admin_invites` entry via the existing
/// `AdminRepository.createInvite`, so the applicant still explicitly
/// accepts it (via Profile's `_PendingInviteBanner`) the same way any
/// admin-invited role already works.
class BusinessOwnerApplication {
  const BusinessOwnerApplication({
    required this.id,
    required this.userId,
    required this.applicantName,
    required this.applicantEmail,
    required this.businessName,
    required this.category,
    required this.phone,
    required this.description,
    this.address = '',
    this.latitude,
    this.longitude,
    this.permitUrl = '',
    this.permitOcrText = '',
    this.idUrl = '',
    required this.status,
    this.rejectionReason,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String applicantName;
  final String applicantEmail;
  final String businessName;

  /// One of [BusinessCategory.all] (`lib/domain/models/business.dart`).
  final String category;
  final String phone;
  final String description;

  /// Where the business is — the readable address of a pin the applicant
  /// dropped on a map (`MapDestinationPicker`), with its coordinates.
  /// Empty/null only on applications submitted before these were asked for.
  final String address;
  final double? latitude;
  final double? longitude;

  /// Applicant-uploaded Business Permit / DTI Registration photo.
  final String permitUrl;

  /// Best-effort OCR of [permitUrl] — a reading aid for the reviewing admin.
  /// Only ever set by the `extractApplicationPermitText` Cloud Function,
  /// never by the client (see firestore.rules), so it's left out of [toMap].
  final String permitOcrText;

  /// Applicant-uploaded photo of a valid government ID.
  final String idUrl;

  /// One of [BusinessOwnerApplicationStatus]'s values.
  final String status;
  final String? rejectionReason;
  final DateTime createdAt;

  factory BusinessOwnerApplication.fromMap(String id, Map<String, dynamic> map) {
    final timestamp = map['createdAt'];
    return BusinessOwnerApplication(
      id: id,
      userId: map['userId'] as String? ?? '',
      applicantName: map['applicantName'] as String? ?? '',
      applicantEmail: map['applicantEmail'] as String? ?? '',
      businessName: map['businessName'] as String? ?? '',
      category: map['category'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      description: map['description'] as String? ?? '',
      address: map['address'] as String? ?? '',
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      permitUrl: map['permitUrl'] as String? ?? '',
      permitOcrText: map['permitOcrText'] as String? ?? '',
      idUrl: map['idUrl'] as String? ?? '',
      status: map['status'] as String? ?? BusinessOwnerApplicationStatus.pending,
      rejectionReason: map['rejectionReason'] as String?,
      createdAt: timestamp is Timestamp ? timestamp.toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'applicantName': applicantName,
      'applicantEmail': applicantEmail,
      'businessName': businessName,
      'category': category,
      'phone': phone,
      'description': description,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'permitUrl': permitUrl,
      'idUrl': idUrl,
      'status': status,
      'rejectionReason': rejectionReason,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
