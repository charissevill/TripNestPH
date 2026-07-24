/// A `businessOwner` account's self-service listing (accommodation, food
/// stall, tour operator, shop, etc.) — separate from the curated
/// `restaurants`/`tourist_spots` collections, which stay Admin/LGU-authored.
/// Backed by the `businesses` Firestore collection; see `firestore.rules`
/// for the owner-scoped write rules and admin approval workflow.
class Business {
  const Business({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.category,
    required this.description,
    required this.provinceId,
    required this.provinceName,
    this.address = '',
    this.contactNumber = '',
    this.websiteUrl = '',
    this.heroImageUrl = '',
    this.status = 'pending',
    this.rejectionReason = '',
  });

  final String id;
  final String ownerId;
  final String name;

  /// One of [BusinessCategory.all].
  final String category;
  final String description;

  /// References `provinces/{provinceId}`.
  final String provinceId;
  final String provinceName;
  final String address;
  final String contactNumber;
  final String websiteUrl;
  final String heroImageUrl;

  /// 'pending' | 'approved' | 'rejected' | 'suspended' — only an admin can
  /// change this (see `firestore.rules`); the owner can move a 'rejected'
  /// listing back to 'pending' by resubmitting.
  final String status;

  /// Set by an admin alongside `status: 'rejected'`; cleared on resubmit.
  final String rejectionReason;

  bool get isApproved => status == 'approved';
  bool get isPending => status == 'pending';
  bool get isRejected => status == 'rejected';
  bool get isSuspended => status == 'suspended';

  factory Business.fromMap(String id, Map<String, dynamic> map) {
    return Business(
      id: id,
      ownerId: map['ownerId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      category: map['category'] as String? ?? BusinessCategory.other,
      description: map['description'] as String? ?? '',
      provinceId: map['provinceId'] as String? ?? '',
      provinceName: map['provinceName'] as String? ?? '',
      address: map['address'] as String? ?? '',
      contactNumber: map['contactNumber'] as String? ?? '',
      websiteUrl: map['websiteUrl'] as String? ?? '',
      heroImageUrl: map['heroImageUrl'] as String? ?? '',
      status: map['status'] as String? ?? 'pending',
      rejectionReason: map['rejectionReason'] as String? ?? '',
    );
  }

  /// Info fields only — never includes `ownerId`/`status`/`rejectionReason`,
  /// which `BusinessRepository` writes separately so a plain info-edit save
  /// can never accidentally trip the rules' status-change branch.
  Map<String, dynamic> toInfoMap() {
    return {
      'name': name,
      'category': category,
      'description': description,
      'provinceId': provinceId,
      'provinceName': provinceName,
      'address': address,
      'contactNumber': contactNumber,
      'websiteUrl': websiteUrl,
      'heroImageUrl': heroImageUrl,
    };
  }
}

class BusinessCategory {
  BusinessCategory._();

  static const String accommodation = 'accommodation';
  static const String foodAndDining = 'foodAndDining';
  static const String tourOperator = 'tourOperator';
  static const String shop = 'shop';
  static const String transport = 'transport';
  static const String other = 'other';

  static const List<String> all = [accommodation, foodAndDining, tourOperator, shop, transport, other];

  static String label(String category) {
    switch (category) {
      case accommodation:
        return 'Accommodation';
      case foodAndDining:
        return 'Food & Dining';
      case tourOperator:
        return 'Tour Operator';
      case shop:
        return 'Shop';
      case transport:
        return 'Transport';
      default:
        return 'Other';
    }
  }
}
