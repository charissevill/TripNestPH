import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// One labeled text field inside a [CredentialDialog]. [validator] follows
/// the standard [FormFieldValidator] contract — return an error string, or
/// null when the value is valid — same as every other form in the app.
class CredentialField {
  const CredentialField({required this.label, required this.controller, required this.obscure, this.validator});

  final String label;
  final TextEditingController controller;
  final bool obscure;
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
        _error = 'Something went wrong. Please check your password and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final field in widget.fields) ...[
              TextFormField(
                controller: field.controller,
                obscureText: field.obscure,
                validator: field.validator,
                decoration: InputDecoration(labelText: field.label, floatingLabelBehavior: FloatingLabelBehavior.auto),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (_error != null) Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(
          style: widget.isDestructive ? FilledButton.styleFrom(backgroundColor: AppColors.error) : null,
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
