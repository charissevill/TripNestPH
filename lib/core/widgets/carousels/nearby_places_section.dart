import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/models/place.dart';
import '../../routes/route_paths.dart';
import '../../services/places_service.dart';
import '../../theme/app_spacing.dart';
import '../details/place_details_sheet.dart';
import '../layout/section_header.dart';
import '../states/loading_widget.dart';
import '../cards/place_card.dart';

/// A horizontal carousel of live Places API results — either around a
/// known coordinate ([latitude]/[longitude], e.g. a destination that
/// already has one on file) or a free-text area query ([textQuery], e.g.
/// "hotels in Palawan, Philippines" for a province with no single point).
/// Renders nothing at all when the query comes back empty or the Places
/// API isn't configured — same best-effort treatment every other
/// supplementary section in this app already gets (see
/// `_loadRecommendations` on the details screens).
class NearbyPlacesSection extends StatefulWidget {
  const NearbyPlacesSection({
    super.key,
    required this.title,
    required this.includedTypes,
    this.latitude,
    this.longitude,
    this.textQuery,
    this.areaLabel,
    this.placesService,
  }) : assert(
          (latitude != null && longitude != null) || (textQuery != null && areaLabel != null),
          'Provide either coordinates, or a textQuery with its areaLabel',
        );

  final String title;
  final List<String> includedTypes;
  final double? latitude;
  final double? longitude;
  final String? textQuery;

  /// The plain area name (e.g. "Palawan") backing [textQuery] — required
  /// alongside it so "See All" can rebuild a *different* category's text
  /// query (e.g. switching from hotels to restaurants) without needing to
  /// parse the original query string back apart.
  final String? areaLabel;

  /// Overridable for tests; defaults to a fresh [PlacesService].
  final PlacesService? placesService;

  @override
  State<NearbyPlacesSection> createState() => _NearbyPlacesSectionState();
}

class _NearbyPlacesSectionState extends State<NearbyPlacesSection> {
  late final PlacesService _places = widget.placesService ?? PlacesService();
  late Future<List<Place>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Place>> _load() {
    if (widget.latitude != null && widget.longitude != null) {
      return _places.searchNearby(latitude: widget.latitude!, longitude: widget.longitude!, includedTypes: widget.includedTypes);
    }
    return _places.searchText(textQuery: widget.textQuery!);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Place>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return LoadingWidget.carousel();
        }
        final places = snapshot.data ?? const [];
        if (places.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: widget.title,
              padding: EdgeInsets.zero,
              actionLabel: 'See All',
              onActionTap: () => context.push(
                RoutePaths.nearbyPlaces,
                extra: {
                  'title': widget.title,
                  'includedTypes': widget.includedTypes,
                  'latitude': widget.latitude,
                  'longitude': widget.longitude,
                  'areaLabel': widget.areaLabel,
                },
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 250,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: places.length,
                separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
                itemBuilder: (context, i) {
                  final place = places[i];
                  final imageUrl = place.photoNames.isNotEmpty ? _places.photoUrl(place.photoNames.first) : '';
                  return PlaceCard(
                    place: place,
                    imageUrl: imageUrl,
                    onTap: () => showPlaceDetailsSheet(context, place: place, placesService: _places),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
