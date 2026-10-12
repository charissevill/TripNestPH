import 'package:cloud_firestore/cloud_firestore.dart';

/// Status of a [BusinessOwnerApplication] — `pending` until an admin
/// resolves it via [BusinessOwnerApplicationRepository.approve]/`reject`.
class BusinessOwnerApplicationStatus {
  BusinessOwnerApplicationStatus._();

  static const String pending = 'pending';
  static const String approved = 'approved';
  static const String rejected = 'rejected';
}

/// What `parsePermitFields` (`functions/permit_parser.js`) could read off
/// a permit photo's OCR text. Best-effort: permits differ per LGU, so any
/// field it couldn't find under a recognisable label is just empty.
class PermitFields {
  const PermitFields({
    this.businessName = '',
    this.ownerName = '',
    this.address = '',
    this.permitNo = '',
    this.validUntil,
    this.issuingLgu = '',
  });

  final String businessName;
  final String ownerName;
  final String address;
  final String permitNo;

  /// Last day the permit is valid.
  final DateTime? validUntil;

  /// e.g. "Municipality of Baliwag, Bulacan".
  final String issuingLgu;

  bool get isEmpty =>
      businessName.isEmpty &&
      ownerName.isEmpty &&
      address.isEmpty &&
      permitNo.isEmpty &&
      validUntil == null &&
      issuingLgu.isEmpty;

  factory PermitFields.fromMap(Object? raw) {
    if (raw is! Map) return const PermitFields();
    String text(String key) => raw[key] is String ? raw[key] as String : '';
    return PermitFields(
      businessName: text('businessName'),
      ownerName: text('ownerName'),
      address: text('address'),
      permitNo: text('permitNo'),
      // Stored as a plain `YYYY-MM-DD` string.
      validUntil: DateTime.tryParse(text('validUntil')),
      issuingLgu: text('issuingLgu'),
    );
  }

  /// Same shape [fromMap] reads — [validUntil] as a plain `YYYY-MM-DD`.
  Map<String, dynamic> toMap() {
    final until = validUntil;
    return {
      'businessName': businessName,
      'ownerName': ownerName,
      'address': address,
      'permitNo': permitNo,
      'validUntil': until == null ? '' : until.toIso8601String().substring(0, 10),
      'issuingLgu': issuingLgu,
    };
  }
}

/// A traveler's self-service request, from the "Business Owner" choice on
/// the sign-up form itself (`RegisterScreen`'s role toggle), to be granted
/// the `businessOwner` Admin Portal role. Backed by the
/// `business_owner_applications` Firestore collection.
/// Deliberately just a request — only an admin approving it grants the
/// role, by creating the applicant's `admin_users` doc directly
/// (`AdminRepository.grantRole`). There's no invite for the applicant to
/// accept afterwards, unlike a manually-invited admin/LGU account: they
/// already asked for the role by applying.
class BusinessOwnerApplication {
  const BusinessOwnerApplication({
    required this.id,
    required this.userId,
    required this.applicantName,
    required this.applicantEmail,
    required this.businessName,
    required this.category,
    this.phone = '',
    required this.description,
    this.address = '',
    this.latitude,
    this.longitude,
    this.permitUrl = '',
    this.permitOcrText = '',
    this.permitFields = const PermitFields(),
    this.idUrl = '',
    this.idName = '',
    this.confirmedPermitFields = const PermitFields(),
    this.confirmedIdName = '',
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

  /// Only on applications from before the form stopped asking for one.
  final String phone;
  final String description;

  /// Where the business is — the readable address of a pin the applicant
  /// dropped on a map (`MapDestinationPicker`), with its coordinates.
  /// Empty/null only on applications submitted before these were asked for.
  final String address;
  final double? latitude;
  final double? longitude;

  /// Applicant-uploaded Business Permit photo.
  final String permitUrl;

  /// Best-effort OCR of [permitUrl] — a reading aid for the reviewing admin.
  /// Only ever set by the `extractApplicationPermitText` Cloud Function,
  /// never by the client (see firestore.rules), so it's left out of [toMap].
  final String permitOcrText;

  /// The labelled fields picked out of [permitOcrText] — set by that same
  /// Cloud Function, so likewise never written by the client.
  final PermitFields permitFields;

  /// Applicant-uploaded photo of the front of a valid government ID.
  final String idUrl;

  /// The holder's name as read off [idUrl] — the only thing kept from the
  /// ID's OCR (its number, birth date, etc. are never stored). Set by the
  /// same Cloud Function as [permitOcrText], never by the client; empty
  /// when the ID's layout wasn't one the parser recognises.
  final String idName;

  /// The permit fields as the applicant submitted them: pre-filled from an
  /// OCR reading on the form (`OcrService.readApplicationDocs`), then theirs
  /// to correct. Unlike [permitFields] this *is* client-written, so the admin
  /// sees it next to the untouched reading rather than instead of it. Empty
  /// on applications submitted before the form offered it.
  final PermitFields confirmedPermitFields;

  /// The name on the ID as the applicant submitted it — same relationship to
  /// [idName] as [confirmedPermitFields] has to [permitFields].
  final String confirmedIdName;

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
      permitFields: PermitFields.fromMap(map['permitFields']),
      idUrl: map['idUrl'] as String? ?? '',
      idName: map['idName'] as String? ?? '',
      confirmedPermitFields: PermitFields.fromMap(map['confirmedPermitFields']),
      confirmedIdName: map['confirmedIdName'] as String? ?? '',
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
      'confirmedPermitFields': confirmedPermitFields.toMap(),
      'confirmedIdName': confirmedIdName,
      'status': status,
      'rejectionReason': rejectionReason,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
