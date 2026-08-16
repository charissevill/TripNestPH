import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/repositories/province_repository.dart';
import '../../../domain/models/province.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/maps_launcher.dart';

/// One-tap emergency info: a nationwide hotline always shown first, that
/// province's own hotlines (fetched live — [provinceId] may be known before
/// the province's full content is loaded), and two "find nearby" shortcuts
/// that hand off to Google Maps using the device's own location. Drop an
/// entry point for this on any screen a traveler is realistically standing
/// on the ground for — the three Details screens and the generated
/// itinerary screen.
Future<void> showEmergencyAccessSheet(
  BuildContext context, {
  String? provinceId,
  String? provinceName,
  ProvinceRepository? provinceRepository,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => _EmergencyAccessSheet(
      provinceId: provinceId,
      provinceName: provinceName,
      provinceRepository: provinceRepository ?? ProvinceRepository(),
    ),
  );
}

class _EmergencyAccessSheet extends StatefulWidget {
  const _EmergencyAccessSheet({this.provinceId, this.provinceName, required this.provinceRepository});

  final String? provinceId;
  final String? provinceName;
  final ProvinceRepository provinceRepository;

  @override
  State<_EmergencyAccessSheet> createState() => _EmergencyAccessSheetState();
}

class _EmergencyAccessSheetState extends State<_EmergencyAccessSheet> {
  List<EmergencyHotline> _hotlines = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = widget.provinceId;
    if (id == null || id.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final province = await widget.provinceRepository.getById(id);
      if (!mounted) return;
      setState(() {
        _hotlines = province?.emergencyHotlines ?? const [];
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _call(String number) => launchUrl(Uri.parse('tel:$number'));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(AppRadius.pill)),
                ),
              ),
              Row(
                children: [
                  const Icon(Symbols.emergency_rounded, color: AppColors.error),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text('Emergency', style: theme.textTheme.headlineSmall)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                widget.provinceName != null && widget.provinceName!.isNotEmpty
                    ? 'Numbers for ${widget.provinceName}, plus nationwide help.'
                    : 'Nationwide emergency numbers.',
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
              ),
              const SizedBox(height: AppSpacing.lg),
              _HotlineTile(label: 'National Emergency Hotline', number: '911', onTap: () => _call('911')),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
                )
              else
                for (final hotline in _hotlines)
                  _HotlineTile(label: hotline.label, number: hotline.number, onTap: () => _call(hotline.number)),
              const SizedBox(height: AppSpacing.xl),
              Text('Find Nearby', style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => MapsLauncher.openPlaceSearch('hospital near me'),
                      icon: const Icon(Symbols.local_hospital_rounded, size: 18),
                      label: const Text('Hospital'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => MapsLauncher.openPlaceSearch('police station near me'),
                      icon: const Icon(Symbols.local_police_rounded, size: 18),
                      label: const Text('Police'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HotlineTile extends StatelessWidget {
  const _HotlineTile({required this.label, required this.number, required this.onTap});

  final String label;
  final String number;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            const Icon(Symbols.call_rounded, size: 18, color: AppColors.error),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
            Text(number, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
