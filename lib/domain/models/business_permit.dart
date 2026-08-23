/// `businesses/{id}/private/permit` — split out of [Business] itself so
/// firestore.rules can keep it readable only by the owner and an admin,
/// never by the "approved" public-read branch every other business field
/// goes through (see the rule's own doc comment: a permit can carry a home
/// address, ID number, or TIN — real PII, unlike the rest of a listing).
class BusinessPermit {
  const BusinessPermit({this.permitUrl = '', this.permitOcrText = ''});

  /// Owner-uploaded proof of a real business (Mayor's/Business Permit, DTI
  /// or SEC registration, etc.). Optional — a submission with none isn't
  /// blocked, but an admin can reject one for missing proof the same way
  /// as any other rejection.
  final String permitUrl;

  /// Best-effort OCR of [permitUrl] (Google Cloud Vision TEXT_DETECTION) —
  /// a reading aid for the admin reviewing the application, not a
  /// verification signal. Only ever set by the `extractPermitText` Cloud
  /// Function (see firestore.rules — a client write can never touch this
  /// field directly), so it's always either genuine Vision output or empty.
  final String permitOcrText;

  factory BusinessPermit.fromMap(Map<String, dynamic> map) {
    return BusinessPermit(
      permitUrl: map['permitUrl'] as String? ?? '',
      permitOcrText: map['permitOcrText'] as String? ?? '',
    );
  }
}
