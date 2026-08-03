import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// One labeled text field inside a [CredentialDialog]. [validator] follows
/// the standard [FormFieldValidator] contract — return an error string, or
/// null when the value is valid — same as every other form in the app.
class CredentialField {
  const CredentialField({
    required this.label,
    required this.controller,
    required this.obscure,
    this.icon,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
  final bool obscure;
  final IconData? icon;
  final FormFieldValidator<String>? validator;
}

/// A small dialog that collects one or more credential fields (current
/// password, new password/email, etc.) and runs [onConfirm] against them —
/// shared by Edit Profile (update email) and Settings (change password,
/// delete account) so the "enter your password to confirm" pattern only
/// exists in one place.
class CredentialDialog extends StatefulWidget {
  const CredentialDialog({
    super.key,
    required this.title,
    required this.fields,
    required this.onConfirm,
    this.confirmLabel = 'Confirm',
    this.isDestructive = false,
  });

  final String title;
  final List<CredentialField> fields;
  final Future<bool> Function() onConfirm;
  final String confirmLabel;
  final bool isDestructive;

  @override
  State<CredentialDialog> createState() => _CredentialDialogState();
}

class _CredentialDialogState extends State<CredentialDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;
  String? _error;

  /// One entry per [CredentialField], mirroring each field's own [CredentialField.obscure] —
  /// toggled independently by that field's show/hide icon rather than a single
  /// dialog-wide switch, since a dialog can mix a password field with a plain one.
  late final List<bool> _obscured = widget.fields
      .map((f) => f.obscure)
      .toList();

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await widget.onConfirm();
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _busy = false;
        _error =
            'Something went wrong. Please check your password and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < widget.fields.length; i++) ...[
                TextFormField(
                  controller: widget.fields[i].controller,
                  obscureText: widget.fields[i].obscure && _obscured[i],
                  validator: widget.fields[i].validator,
                  decoration: InputDecoration(
                    labelText: widget.fields[i].label,
                    floatingLabelBehavior: FloatingLabelBehavior.auto,
                    prefixIcon: widget.fields[i].icon != null
                        ? Icon(widget.fields[i].icon, size: 20)
                        : null,
                    suffixIcon: widget.fields[i].obscure
                        ? IconButton(
                            icon: Icon(
                              _obscured[i]
                                  ? Symbols.visibility_off_rounded
                                  : Symbols.visibility_rounded,
                              size: 20,
                            ),
                            onPressed: () =>
                                setState(() => _obscured[i] = !_obscured[i]),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              if (_error != null)
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.error, fontSize: 12),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: widget.isDestructive
              ? FilledButton.styleFrom(backgroundColor: AppColors.error)
              : null,
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
