import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/services/geocode_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/places_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/buttons/animated_button.dart';
import '../../../core/widgets/inputs/search_bar_widget.dart';
import '../../../domain/models/place.dart';

/// What [MapDestinationPicker] pops — a free-form pin, not tied to any
/// curated [Destination]/[Province] record, so [name] is whatever
/// [GeocodeService] resolved (or a plain fallback if it couldn't).
class MapPickedLocation {
  const MapPickedLocation({
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  final String name;
  final double latitude;
  final double longitude;
}

/// A full-screen Google Map the traveler taps anywhere on to drop a pin, or
/// searches by name to jump straight there. Used two ways:
/// - Whole-country: the manual "Create Your Own Itinerary" flow's own
///   destination picker (no [anchorLatitude]/[anchorLongitude]) — any spot
///   in the Philippines.
/// - Anchored: [GeneratedItineraryScreen]'s "Add Activity" location picker,
///   passing the trip's own destination as the anchor — a single day's
///   activity should be near the trip, not anywhere in the country, so a
///   pick further than [_anchorRadiusKm] from it is rejected the same way
///   a pick outside the Philippines is.
/// A tapped point is reverse-geocoded best-effort (see [GeocodeService]); a
/// resolution failure still lets them confirm with a generic label rather
/// than getting stuck unable to proceed.
class MapDestinationPicker extends StatefulWidget {
  const MapDestinationPicker({
    super.key,
    this.title = 'Pin Your Destination',
    this.anchorLatitude,
    this.anchorLongitude,
    this.anchorLabel,
  }) : assert(
         (anchorLatitude == null) == (anchorLongitude == null),
         'anchorLatitude and anchorLongitude must be given together',
       );

  final String title;
  final double? anchorLatitude;
  final double? anchorLongitude;

  /// Shown in the "too far" rejection message and the map hint — falls back
  /// to a generic "the trip's destination" when an anchor is given without
  /// one.
  final String? anchorLabel;

  @override
  State<MapDestinationPicker> createState() => _MapDestinationPickerState();
}

class _MapDestinationPickerState extends State<MapDestinationPicker> {
  static const _wholeCountryPosition = CameraPosition(target: LatLng(12.8797, 121.7740), zoom: 5.3);
  static const _anchorRadiusKm = 100.0;

  GoogleMapController? _mapController;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<Place>? _searchResults;
  bool _searching = false;

  LatLng? _picked;
  String? _resolvedName;
  bool _resolving = false;
  bool _locating = false;

  bool get _hasAnchor => widget.anchorLatitude != null;
  String get _anchorLabel => widget.anchorLabel?.isNotEmpty == true ? widget.anchorLabel! : 'the trip\'s destination';

  CameraPosition get _initialPosition => _hasAnchor
      ? CameraPosition(target: LatLng(widget.anchorLatitude!, widget.anchorLongitude!), zoom: 10)
      : _wholeCountryPosition;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Null when there's no anchor to check against; otherwise the distance
  /// in km from [widget.anchorLatitude]/[widget.anchorLongitude].
  double? _distanceFromAnchorKm(double latitude, double longitude) {
    if (!_hasAnchor) return null;
    return LocationService().distanceKm(
      lat1: widget.anchorLatitude!,
      lng1: widget.anchorLongitude!,
      lat2: latitude,
      lng2: longitude,
    );
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() => _searchResults = null);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(value.trim()));
  }

  Future<void> _search(String query) async {
    setState(() => _searching = true);
    // This app is Philippines-only, so nudging every free-text query with
    // the country keeps results relevant even for a name that also exists
    // abroad (there's no curated destination list backing this search the
    // way DestinationPickerSheet's is). The suffix alone doesn't guarantee
    // every match is actually in the Philippines (an ambiguous name can
    // still resolve elsewhere), so results are also filtered by address —
    // [Place] has no structured country field to check instead.
    final results = await PlacesService().searchText(
      textQuery: '$query, Philippines',
      maxResultCount: 8,
      biasLatitude: widget.anchorLatitude,
      biasLongitude: widget.anchorLongitude,
      biasRadiusMeters: _anchorRadiusKm * 1000,
    );
    if (!mounted) return;
    setState(() {
      _searching = false;
      _searchResults = results.where((p) {
        if (!p.address.toLowerCase().contains('philippines')) return false;
        final lat = p.latitude;
        final lng = p.longitude;
        if (_hasAnchor && lat != null && lng != null) {
          final distance = _distanceFromAnchorKm(lat, lng);
          if (distance != null && distance > _anchorRadiusKm) return false;
        }
        return true;
      }).toList();
    });
  }

  Future<void> _selectSearchResult(Place place) async {
    final lat = place.latitude;
    final lng = place.longitude;
    if (lat == null || lng == null) return;

    FocusScope.of(context).unfocus();
    final position = LatLng(lat, lng);
    setState(() {
      _picked = position;
      _resolvedName = place.name.isNotEmpty ? place.name : place.address;
      _searchResults = null;
      _searchController.text = place.name;
    });
    await _mapController?.animateCamera(CameraUpdate.newLatLngZoom(position, 14));
  }

  /// Drops the pin at [position] and reverse-geocodes it — shared by a
  /// direct map tap and [_useCurrentLocation], which additionally needs to
  /// re-center the camera since the traveler didn't tap the point directly.
  /// A point Google resolves to a country other than the Philippines (this
  /// app's whole scope), or one further than [_anchorRadiusKm] from
  /// [widget.anchorLatitude]/[widget.anchorLongitude] when that's given, is
  /// rejected outright — the pin is cleared rather than left down with no
  /// way to confirm it.
  Future<void> _dropPin(LatLng position, {bool moveCamera = false}) async {
    FocusScope.of(context).unfocus();

    final distance = _distanceFromAnchorKm(position.latitude, position.longitude);
    if (distance != null && distance > _anchorRadiusKm) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('That\'s too far from $_anchorLabel — pick a spot within ${_anchorRadiusKm.round()}km.')),
      );
      return;
    }

    setState(() {
      _picked = position;
      _resolvedName = null;
      _resolving = true;
      _searchResults = null;
      _searchController.clear();
    });
    if (moveCamera) {
      await _mapController?.animateCamera(CameraUpdate.newLatLngZoom(position, 14));
    }
    try {
      final result = await GeocodeService().reverseGeocode(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (!mounted) return;
      if (result.countryCode.isNotEmpty && result.countryCode != 'PH') {
        setState(() {
          _picked = null;
          _resolvedName = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('That\'s outside the Philippines — pick a spot within the country.')),
        );
        return;
      }
      setState(() => _resolvedName = result.name);
    } catch (_) {
      // Best-effort — _resolvedName stays null, _confirm() falls back to a
      // generic label rather than blocking the pin from being usable.
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  Future<void> _onTap(LatLng position) => _dropPin(position);

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    final result = await LocationService().resolveCurrentPosition();
    if (!mounted) return;
    setState(() => _locating = false);

    if (!result.isGranted) {
      final locationService = LocationService();
      final needsSettings = result.status == LocationAccessStatus.permissionDeniedForever ||
          result.status == LocationAccessStatus.serviceDisabled;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            needsSettings
                ? 'Location access is off at the system level. Enable it in your device settings.'
                : 'Couldn\'t get your current location.',
          ),
          action: needsSettings
              ? SnackBarAction(
                  label: 'Open Settings',
                  onPressed: result.status == LocationAccessStatus.serviceDisabled
                      ? locationService.openLocationSettings
                      : locationService.openAppSettings,
                )
              : null,
        ),
      );
      return;
    }

    final position = result.position!;
    await _dropPin(LatLng(position.latitude, position.longitude), moveCamera: true);
  }

  void _confirm() {
    final picked = _picked;
    if (picked == null) return;
    final name = _resolvedName;
    Navigator.of(context).pop(
      MapPickedLocation(
        name: (name != null && name.isNotEmpty) ? name : 'Pinned location',
        latitude: picked.latitude,
        longitude: picked.longitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final picked = _picked;
    final searchResults = _searchResults;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _initialPosition,
            onMapCreated: (controller) => _mapController = controller,
            onTap: _onTap,
            myLocationButtonEnabled: false,
            markers: picked == null
                ? const {}
                : {Marker(markerId: const MarkerId('picked'), position: picked)},
          ),
          Positioned(
            top: AppSpacing.md,
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SearchBarWidget(
                  hintText: 'Search for a place in the Philippines',
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  trailing: _searching
                      ? const Padding(
                          padding: EdgeInsets.only(right: AppSpacing.sm),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
                if (searchResults != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Card(
                      elevation: 4,
                      child: searchResults.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(AppSpacing.md),
                              child: Text('No places found'),
                            )
                          : ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 260),
                              child: ListView.separated(
                                shrinkWrap: true,
                                padding: EdgeInsets.zero,
                                itemCount: searchResults.length,
                                separatorBuilder: (context, index) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final place = searchResults[index];
                                  return ListTile(
                                    leading: const Icon(Symbols.location_on_rounded, color: AppColors.primary),
                                    title: Text(place.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                                    subtitle: Text(place.address, maxLines: 1, overflow: TextOverflow.ellipsis),
                                    onTap: () => _selectSearchResult(place),
                                  );
                                },
                              ),
                            ),
                    ),
                  )
                else if (picked == null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: _Hint(
                      text: _hasAnchor
                          ? 'Search above or tap within ${_anchorRadiusKm.round()}km of $_anchorLabel'
                          : 'Search above or tap anywhere on the map to drop a pin',
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            right: AppSpacing.lg,
            // Clears the web map's own +/- zoom control stack (bottom-right)
            // when no pin is down yet, or the "confirm location" card once
            // one is (that card's height varies with the resolved place
            // name's length, so 216 is an estimate, not a measured value —
            // same tradeoff every fixed-offset overlay here makes).
            bottom: picked == null ? 135 : 216,
            child: InkWell(
              onTap: _locating ? null : _useCurrentLocation,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: _locating
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Symbols.my_location_rounded, color: AppColors.primary),
              ),
            ),
          ),
          if (picked != null)
            Positioned(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              bottom: AppSpacing.lg,
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_resolving)
                        Row(
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text('Finding location name…', style: theme.textTheme.bodyMedium),
                          ],
                        )
                      else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Symbols.location_on_rounded, size: 20, color: AppColors.primary),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                (_resolvedName != null && _resolvedName!.isNotEmpty)
                                    ? _resolvedName!
                                    : 'Unnamed location — you can still use this pin',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: AppSpacing.md),
                      AnimatedButton(
                        label: 'Confirm Location',
                        icon: Symbols.check_rounded,
                        onPressed: _resolving ? null : _confirm,
                        height: 48,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 13),
      ),
    );
  }
}
