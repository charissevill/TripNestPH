/// Shared form-field validators for every auth/profile form in the app.
/// Each returns a user-facing error string, or null when the value is valid.
class Validators {
  Validators._();

  // No leading/trailing/consecutive dots in either the local part or the
  // domain (the previous pattern let "a@b.com." and "a@b..com" through —
  // obviously malformed, even though Firebase itself would still reject
  // them server-side with invalid-email).
  static final RegExp _emailPattern = RegExp(r'^[\w+-]+(\.[\w+-]+)*@[\w-]+(\.[\w-]+)+$');

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Email is required';
    if (!_emailPattern.hasMatch(v)) return 'Enter a valid email address';
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Password is required';
    if (v.length < 8) return 'Password must be at least 8 characters';
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if (value != original) return 'Passwords do not match';
    return null;
  }

  static String? name(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Name is required';
    if (v.length < 2) return 'Name is too short';
    if (v.length > 60) return 'Name must be 60 characters or fewer';
    return null;
  }

  static String? required(String? value, {String label = 'This field'}) {
    if ((value ?? '').trim().isEmpty) return '$label is required';
    return null;
  }

  /// Lenient on purpose — this only guards against obviously-broken input
  /// (no scheme, no host), not a strict RFC check, since a real business's
  /// website URL can otherwise take many valid shapes.
  static String? url(String? value, {bool required = false}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return required ? 'This field is required' : null;
    final uri = Uri.tryParse(v);
    if (uri == null || !uri.hasScheme || !(uri.isScheme('http') || uri.isScheme('https')) || uri.host.isEmpty) {
      return 'Enter a valid URL (starting with http:// or https://)';
    }
    return null;
  }

  /// Tolerant of spaces/dashes/parens/a leading `+` — just checks there's a
  /// plausible run of digits, not a strict per-country phone format.
  static String? phone(String? value, {bool required = false}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return required ? 'This field is required' : null;
    final digitsOnly = v.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (!RegExp(r'^\+?\d{7,15}$').hasMatch(digitsOnly)) return 'Enter a valid phone number';
    return null;
  }

  /// Optional (an admin listing can be saved without coordinates and still
  /// work — it just loses the weather card/map/directions on the details
  /// screen), but if something was typed, it must be a real latitude.
  static String? latitude(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    final parsed = double.tryParse(v);
    if (parsed == null) return 'Enter a valid latitude';
    if (parsed < -90 || parsed > 90) return 'Latitude must be between -90 and 90';
    return null;
  }

  static String? longitude(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    final parsed = double.tryParse(v);
    if (parsed == null) return 'Enter a valid longitude';
    if (parsed < -180 || parsed > 180) return 'Longitude must be between -180 and 180';
    return null;
  }

  static String? maxLength(String? value, int max, {String label = 'This field'}) {
    if ((value ?? '').length > max) return '$label must be $max characters or fewer';
    return null;
  }

  /// A peso amount — must parse and be positive, capped at [maxAmount]
  /// (default ₱1,000,000) to catch an obvious typo (an extra zero) rather
  /// than a legitimately large but real price/expense.
  static String? amount(String? value, {bool required = false, double maxAmount = 1000000}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return required ? 'This field is required' : null;
    final parsed = double.tryParse(v);
    if (parsed == null) return 'Enter a valid amount';
    if (parsed <= 0) return 'Amount must be greater than 0';
    if (parsed > maxAmount) return 'Amount must be ₱${maxAmount.toStringAsFixed(0)} or less';
    return null;
  }
}
