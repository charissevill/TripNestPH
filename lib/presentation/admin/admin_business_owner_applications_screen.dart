import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/routes/back_navigation.dart';
import '../../core/routes/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/maps_launcher.dart';
import '../../core/utils/permit_field_match.dart';
import '../../core/widgets/dialogs/confirmation_dialog.dart';
import '../../core/widgets/states/empty_state_widget.dart';
import '../../core/widgets/states/loading_widget.dart';
import '../../data/repositories/business_owner_application_repository.dart';
import '../../domain/models/business.dart';
import '../../domain/models/business_owner_application.dart';

/// Admin-only queue for [BusinessOwnerApplication]s — approving one stages
/// an `admin_invites` entry for the applicant (see the repository's
/// `approve` doc comment), it never grants `businessOwner` directly.
class AdminBusinessOwnerApplicationsScreen extends StatefulWidget {
  const AdminBusinessOwnerApplicationsScreen({super.key});

  @override
  State<AdminBusinessOwnerApplicationsScreen> createState() =>
      _AdminBusinessOwnerApplicationsScreenState();
}

class _AdminBusinessOwnerApplicationsScreenState extends State<AdminBusinessOwnerApplicationsScreen> {
  final _repository = BusinessOwnerApplicationRepository();

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppException.from(e).message)));
      }
    }
  }

  Future<void> _approve(BusinessOwnerApplication application) async {
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Approve this application?',
      message:
          '${application.applicantName} will be invited to accept Business Owner access — they still need to accept it on their Profile screen.',
      confirmLabel: 'Approve',
    );
    if (!confirmed || !mounted) return;
    final adminName = context.read<AuthProvider>().currentUser?.name ?? '';
    await _run(() => _repository.approve(application, adminName: adminName));
  }

  Future<String?> _promptReason() async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        // Scrolls on a short viewport (landscape, keyboard open) instead of overflowing.
        scrollable: true,
        title: const Text('Reject this application?'),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Tell the applicant why...',
            alignLabelWithHint: true,
            prefixIcon: Icon(Symbols.edit_note_rounded, size: 20),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              final text = reasonController.text.trim();
              if (text.isEmpty) return;
              Navigator.of(context).pop(text);
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    return (reason == null || reason.isEmpty) ? null : reason;
  }

  Future<void> _reject(BusinessOwnerApplication application) async {
    final reason = await _promptReason();
    if (reason == null || !mounted) return;
    await _run(() => _repository.reject(application.id, reason));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Explicit rather than the implied arrow, which vanished whenever
        // the desktop sidebar opened this screen with `go` — every other
        // admin section keeps its Back button there.
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back_rounded),
          onPressed: () => context.popOrGo(RoutePaths.adminHome),
        ),
        title: const Text('Business Applications'),
      ),
      body: SafeArea(
        child: StreamBuilder<List<BusinessOwnerApplication>>(
          stream: _repository.streamPendingForAdmin(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return LoadingWidget.block(height: 300);
            }
            final applications = snapshot.data ?? const [];
            if (applications.isEmpty) {
              return const EmptyStateWidget(
                icon: Symbols.storefront_rounded,
                title: 'No pending applications',
                message: 'New Business Owner applications will show up here.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: applications.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, i) => _ApplicationCard(
                application: applications[i],
                onApprove: () => _approve(applications[i]),
                onReject: () => _reject(applications[i]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({required this.application, required this.onApprove, required this.onReject});

  final BusinessOwnerApplication application;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(application.businessName, style: theme.textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(BusinessCategory.label(application.category), style: theme.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.sm),
          Text('${application.applicantName} · ${application.applicantEmail}', style: theme.textTheme.bodySmall),
          if (application.phone.isNotEmpty) Text(application.phone, style: theme.textTheme.bodySmall),
          if (application.description.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(application.description, style: theme.textTheme.bodyMedium),
          ],
          // Absent only on applications submitted before the form asked for
          // them — each link just doesn't render rather than showing a dead one.
          if (application.latitude != null && application.longitude != null)
            _ProofLink(
              icon: Symbols.location_on_rounded,
              label: application.address.isEmpty ? 'View pinned location' : application.address,
              onTap: () => MapsLauncher.openDirections(
                latitude: application.latitude!,
                longitude: application.longitude!,
                label: application.businessName,
              ),
            ),
          if (application.permitUrl.isNotEmpty)
            _ProofLink(
              icon: Symbols.description_rounded,
              label: 'View submitted permit',
              onTap: () => MapsLauncher.openUrl(application.permitUrl),
            ),
          if (application.idUrl.isNotEmpty)
            _ProofLink(
              icon: Symbols.badge_rounded,
              label: 'View submitted ID',
              onTap: () => MapsLauncher.openUrl(application.idUrl),
            ),
          if (!application.permitFields.isEmpty ||
              application.idName.isNotEmpty ||
              !application.confirmedPermitFields.isEmpty ||
              application.confirmedIdName.isNotEmpty)
            _PermitFieldsSection(application: application),
          if (application.permitOcrText.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Full extracted text (OCR) — verify against the actual photo',
              style: theme.textTheme.labelSmall?.copyWith(color: AppColors.textTertiary),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 120),
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.border),
              ),
              child: SingleChildScrollView(
                child: Text(application.permitOcrText, style: theme.textTheme.bodySmall),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton(onPressed: onApprove, child: const Text('Approve')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One tappable piece of submitted proof (pinned location, permit, ID) —
/// same underlined-link treatment as `AdminBusinessListScreen`'s permit link.
class _ProofLink extends StatelessWidget {
  const _ProofLink({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: InkWell(
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The fields read off the permit photo — and the name read off the ID —
/// each next to a hint of whether it agrees with what the applicant typed
/// (see `permit_field_match.dart`). Only fields the parsers actually found
/// get a row.
class _PermitFieldsSection extends StatelessWidget {
  const _PermitFieldsSection({required this.application});

  final BusinessOwnerApplication application;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // What the applicant confirmed on the form wins where they gave one; the
    // untouched OCR reading fills in the rest (and is all there is on an
    // application from before the form let them confirm it). Where the two
    // disagree the row says so — see [_ocrNote].
    final ocr = application.permitFields;
    final confirmed = application.confirmedPermitFields;
    String pick(String confirmedValue, String ocrValue) => confirmedValue.isNotEmpty ? confirmedValue : ocrValue;
    final fields = PermitFields(
      businessName: pick(confirmed.businessName, ocr.businessName),
      ownerName: pick(confirmed.ownerName, ocr.ownerName),
      address: pick(confirmed.address, ocr.address),
      permitNo: pick(confirmed.permitNo, ocr.permitNo),
      validUntil: confirmed.validUntil ?? ocr.validUntil,
      issuingLgu: pick(confirmed.issuingLgu, ocr.issuingLgu),
    );
    final dateFormat = DateFormat('MMMM d, yyyy');
    final validUntil = fields.validUntil;
    final ocrValidUntil = ocr.validUntil;
    final expired = validUntil != null && isPermitExpired(validUntil);
    // The ID's name has two things to agree with: the account applying, and
    // the owner named on the permit. Either disagreeing is worth a look.
    final idName = pick(application.confirmedIdName, application.idName);
    final idVsAccount = matchPermitName(idName, application.applicantName);
    final idVsPermit = matchPermitName(idName, fields.ownerName);
    final idChecks = [idVsAccount, idVsPermit];
    final idMatch = idChecks.contains(PermitMatch.differs)
        ? PermitMatch.differs
        : idChecks.contains(PermitMatch.matches)
            ? PermitMatch.matches
            : PermitMatch.unknown;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.md),
        Text(
          'Permit and ID details, as the applicant confirmed them — a hint, not a verdict',
          style: theme.textTheme.labelSmall?.copyWith(color: AppColors.textTertiary),
        ),
        if (fields.businessName.isNotEmpty)
          _PermitFieldRow(
            label: 'Business name',
            value: fields.businessName,
            // No match hint: the form no longer asks for a separately-typed
            // name, so there's nothing independent to compare this against —
            // an edit away from what the photo says shows up as the OCR note.
            ocrNote: _ocrNote(fields.businessName, ocr.businessName),
          ),
        if (fields.ownerName.isNotEmpty)
          _PermitFieldRow(
            label: 'Owner',
            value: fields.ownerName,
            match: matchPermitName(fields.ownerName, application.applicantName),
            differsNote: 'Account name is "${application.applicantName}"',
            ocrNote: _ocrNote(fields.ownerName, ocr.ownerName),
          ),
        if (idName.isNotEmpty)
          _PermitFieldRow(
            label: 'Name on ID',
            value: idName,
            match: idMatch,
            differsNote: idVsAccount == PermitMatch.differs
                ? 'Account name is "${application.applicantName}"'
                : 'Permit owner is "${fields.ownerName}"',
            ocrNote: _ocrNote(idName, application.idName),
          ),
        if (fields.address.isNotEmpty)
          _PermitFieldRow(
            label: 'Address',
            value: fields.address,
            match: matchPermitAddress(fields.address, application.address),
            differsNote: 'Pinned location is "${application.address}"',
            ocrNote: _ocrNote(fields.address, ocr.address),
          ),
        if (validUntil != null)
          _PermitFieldRow(
            label: 'Valid until',
            value: dateFormat.format(validUntil),
            match: expired ? PermitMatch.differs : PermitMatch.matches,
            differsNote: 'This permit has expired',
            ocrNote: ocrValidUntil == null ? '' : _ocrNote(dateFormat.format(validUntil), dateFormat.format(ocrValidUntil)),
          ),
        if (fields.permitNo.isNotEmpty)
          _PermitFieldRow(
            label: 'Permit no.',
            value: fields.permitNo,
            ocrNote: _ocrNote(fields.permitNo, ocr.permitNo),
          ),
        if (fields.issuingLgu.isNotEmpty)
          _PermitFieldRow(
            label: 'Issued by',
            value: fields.issuingLgu,
            ocrNote: _ocrNote(fields.issuingLgu, ocr.issuingLgu),
          ),
      ],
    );
  }

  /// What to say under a row whose shown value isn't what the OCR read off
  /// the photo — i.e. the applicant changed it. Empty when they agree
  /// (ignoring case and spacing) or the OCR found nothing to compare with.
  static String _ocrNote(String shown, String ocrValue) {
    String normalized(String s) => s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (ocrValue.isEmpty || normalized(shown) == normalized(ocrValue)) return '';
    return 'Edited by applicant — the photo was read as "$ocrValue"';
  }
}

class _PermitFieldRow extends StatelessWidget {
  const _PermitFieldRow({
    required this.label,
    required this.value,
    this.match = PermitMatch.unknown,
    this.differsNote = '',
    this.ocrNote = '',
  });

  final String label;
  final String value;
  final PermitMatch match;

  /// Shown under the value only when [match] is [PermitMatch.differs].
  final String differsNote;

  /// Shown under the value whenever non-empty — see
  /// `_PermitFieldsSection._ocrNote`.
  final String ocrNote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final differs = match == PermitMatch.differs;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.labelSmall?.copyWith(color: AppColors.textSecondary)),
                Text(value, style: theme.textTheme.bodyMedium),
                if (differs && differsNote.isNotEmpty)
                  Text(differsNote, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.error)),
                if (ocrNote.isNotEmpty)
                  Text(ocrNote, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.warning)),
              ],
            ),
          ),
          if (match != PermitMatch.unknown) ...[
            const SizedBox(width: AppSpacing.sm),
            Icon(
              differs ? Symbols.error_rounded : Symbols.check_circle_rounded,
              size: 18,
              color: differs ? AppColors.error : AppColors.success,
              semanticLabel: differs ? 'Does not match' : 'Matches',
            ),
          ],
        ],
      ),
    );
  }
}
