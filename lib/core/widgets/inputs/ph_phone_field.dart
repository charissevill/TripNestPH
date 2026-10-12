import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../utils/validators.dart';

/// Drawn rather than the 🇵🇭 emoji, which Windows and some web fonts render
/// as the plain letters "PH".
const String _phFlagSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 900 600">
  <rect width="900" height="300" fill="#0038a8"/>
  <rect y="300" width="900" height="300" fill="#ce1126"/>
  <path d="M0 0 519.6 300 0 600z" fill="#fff"/>
  <circle cx="175" cy="300" r="62" fill="#fcd116"/>
  <circle cx="52" cy="80" r="22" fill="#fcd116"/>
  <circle cx="52" cy="520" r="22" fill="#fcd116"/>
  <circle cx="420" cy="300" r="22" fill="#fcd116"/>
</svg>
''';

/// A Philippine phone number field: a fixed flag + "+63" prefix, digits
/// only, capped at [maxDigits]. [controller] holds just the digits after
/// the country code — convert with [nationalDigits] when loading a stored
/// number and [toStored] when saving one.
class PhPhoneField extends StatelessWidget {
  const PhPhoneField({
    super.key,
    required this.controller,
    this.labelText = 'Contact Number',
    this.required = false,
  });

  final TextEditingController controller;
  final String labelText;
  final bool required;

  /// A mobile number's length after +63 (9XX XXX XXXX) — landlines are one
  /// digit shorter.
  static const int maxDigits = 10;

  /// The digits after the country code of a stored number, whichever way
  /// it was written ("+63 917 123 4567", "0917-123-4567", "9171234567").
  static String nationalDigits(String stored) {
    var digits = stored.replaceAll(RegExp(r'\D'), '');
    if (digits.length > maxDigits && digits.startsWith('63')) {
      digits = digits.substring(2);
    }
    digits = digits.replaceFirst(RegExp(r'^0+'), '');
    return digits.length > maxDigits ? digits.substring(0, maxDigits) : digits;
  }

  /// [digits] as stored: "+639171234567", or empty when nothing was typed.
  static String toStored(String digits) {
    final national = nationalDigits(digits);
    return national.isEmpty ? '' : '+63$national';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.phone,
      maxLength: maxDigits,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        // A pasted "+63917…" or typed "0917…" would otherwise spend the
        // limit on a prefix the field already shows.
        TextInputFormatter.withFunction((oldValue, newValue) {
          final text = nationalDigits(newValue.text);
          if (text == newValue.text) return newValue;
          return TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          );
        }),
      ],
      decoration: InputDecoration(
        labelText: labelText,
        hintText: '9171234567',
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 12, right: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: SvgPicture.string(_phFlagSvg, width: 24, height: 16),
              ),
              const SizedBox(width: 6),
              Text('+63', style: theme.textTheme.bodyLarge),
            ],
          ),
        ),
      ),
      validator: (v) => Validators.phPhone(v, required: required),
    );
  }
}
