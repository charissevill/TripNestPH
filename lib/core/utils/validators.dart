/// Shared form-field validators for every auth/profile form in the app.
/// Each returns a user-facing error string, or null when the value is valid.
class Validators {
  Validators._();

  static final RegExp _emailPattern = RegExp(r'^[\w\.\-\+]+@[\w\-]+\.[\w\-\.]+$');

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

  static String? maxLength(String? value, int max, {String label = 'This field'}) {
    if ((value ?? '').length > max) return '$label must be $max characters or fewer';
    return null;
  }
}
