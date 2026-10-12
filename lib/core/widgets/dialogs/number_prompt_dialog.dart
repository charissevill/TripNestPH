import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// A small "type the exact number" dialog for the days/travelers counters —
/// the +/- steppers are fine for nudging by one, but slow for jumping from
/// 1 to 12. Validates against [min]/[max] the same way every other form in
/// the app validates input, rather than silently clamping a bad value.
Future<int?> promptForNumber(
  BuildContext context, {
  required String title,
  required int initial,
  required int min,
  required int max,
}) {
  final controller = TextEditingController(text: '$initial');
  final formKey = GlobalKey<FormState>();
  return showDialog<int>(
    context: context,
    builder: (context) => AlertDialog(
      // Scrolls on a short viewport (landscape, keyboard open) instead of overflowing.
      scrollable: true,
      title: Text(title),
      content: Form(
        key: formKey,
        child: TextFormField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Between $min and $max',
            prefixIcon: const Icon(Symbols.numbers_rounded, size: 20),
          ),
          validator: (v) {
            final n = int.tryParse((v ?? '').trim());
            if (n == null) return 'Enter a whole number';
            if (n < min || n > max)
              return 'Enter a number between $min and $max';
            return null;
          },
          onFieldSubmitted: (_) {
            if (formKey.currentState!.validate())
              Navigator.of(context).pop(int.parse(controller.text.trim()));
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (formKey.currentState!.validate())
              Navigator.of(context).pop(int.parse(controller.text.trim()));
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
