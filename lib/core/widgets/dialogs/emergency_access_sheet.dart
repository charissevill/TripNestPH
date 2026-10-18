import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../data/repositories/province_repository.dart';
import '../../../domain/models/province.dart';
import '../../services/location_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/app_exception.dart';
import '../../utils/maps_launcher.dart';
import '../../utils/safe_launch.dart';

/// One-tap emergency info: a nationwide hotline always shown first, that
/// province's own hotlines (fetched live — [provinceId] may be known before
/// the province's full content is loaded), and two "find nearby" shortcuts
/// that hand off to Google Maps centered on the device's GPS fix. Drop an
/// entry point for this on any screen a traveler is realistically standing
/// on the ground for — the three Details screens and the generated
/// itinerary screen.
Future<void> showEmergencyAccessSheet(
  BuildContext context, {
  String? provinceId,
  String? provinceName,
  ProvinceRepository? provinceRepository,
  LocationService? locationService,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    // See trip_calendar_screen.dart's showModalBottomSheet for why this
    // matters — without it, the floating AI Chat FAB floats visibly on
    // top of this sheet instead of being covered by it.
    useRootNavigator: true,
    builder: (context) => _EmergencyAccessSheet(
      provinceId: provinceId,
      provinceName: provinceName,
      provinceRepository: provinceRepository ?? ProvinceRepository(),
      locationService: locationService ?? LocationService(),
    ),
  );
}

class _EmergencyAccessSheet extends StatefulWidget {
  const _EmergencyAccessSheet({
    this.provinceId,
    this.provinceName,
    required this.provinceRepository,
    required this.locationService,
  });

  final String? provinceId;
  final String? provinceName;
  final ProvinceRepository provinceRepository;
  final LocationService locationService;

  @override
  State<_EmergencyAccessSheet> createState() => _EmergencyAccessSheetState();
}

class _EmergencyAccessSheetState extends State<_EmergencyAccessSheet> {
  List<EmergencyHotline> _hotlines = const [];
  bool _loading = true;
  bool _loadFailed = false;

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
    } catch (e) {
      logTechnicalError(e);
      if (mounted) {
        setState(() {
          _loading = false;
          _loadFailed = true;
        });
      }
    }
  }

  Future<void> _call(String number) => callNumber(number);

  /// The Find Nearby query being located right now, so its button can show
  /// progress and a second tap can't stack another search on top.
  String? _locatingQuery;

  /// Pins the Maps search to where the traveler is actually standing (see
  /// [MapsLauncher.nearbySearchUri]). The GPS fix is capped so a slow or
  /// stuck one never holds up an emergency search — no fix (denied, GPS
  /// off, timed out) just falls back to Maps' own "near me".
  Future<void> _findNearby(String query) async {
    if (_locatingQuery != null) return;
    setState(() => _locatingQuery = query);
    final location = await widget.locationService.resolveCurrentPositionWithin(const Duration(seconds: 8));
    if (mounted) setState(() => _locatingQuery = null);
    final position = location.isGranted ? location.position : null;
    await MapsLauncher.openNearbySearch(query, latitude: position?.latitude, longitude: position?.longitude);
  }

  Widget _findNearbyIcon(String query, IconData icon) => _locatingQuery == query
      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
      : Icon(icon, size: 18);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadius.xxl),
      ),
      child: SafeArea(
        top: false,
        // Scrolls when the sheet is taller than the screen (landscape, large
        // text, several local hotlines) so the Call / Find Nearby actions
        // stay reachable instead of being cut off.
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
              Row(
                children: [
                  const Icon(Symbols.emergency_rounded, color: AppColors.error),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Emergency',
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                widget.provinceName != null && widget.provinceName!.isNotEmpty
                    ? 'Numbers for ${widget.provinceName}, plus nationwide help.'
                    : 'Nationwide emergency numbers.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _HotlineTile(
                label: 'National Emergency Hotline',
                number: '911',
                onTap: () => _call('911'),
              ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                )
              else if (_loadFailed)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Text(
                    'Couldn\'t load local hotlines right now. The national hotline above still works.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                )
              else
                for (final hotline in _hotlines)
                  _HotlineTile(
                    label: hotline.label,
                    number: hotline.number,
                    onTap: () => _call(hotline.number),
                  ),
              const SizedBox(height: AppSpacing.xl),
              Text('Find Nearby', style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _locatingQuery != null
                          ? null
                          : () => _findNearby('hospital'),
                      icon: _findNearbyIcon(
                        'hospital',
                        Symbols.local_hospital_rounded,
                      ),
                      label: const Text('Hospital'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _locatingQuery != null
                          ? null
                          : () => _findNearby('police station'),
                      icon: _findNearbyIcon(
                        'police station',
                        Symbols.local_police_rounded,
                      ),
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
  const _HotlineTile({
    required this.label,
    required this.number,
    required this.onTap,
  });

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
            Text(
              number,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
