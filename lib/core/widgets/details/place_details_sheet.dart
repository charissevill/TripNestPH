import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../domain/models/place.dart';
import '../../services/places_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/auto_advance_gallery_mixin.dart';
import '../../utils/maps_launcher.dart';
import '../buttons/animated_button.dart';
import '../indicators/rating_widget.dart';

/// Opens the fuller Places API field set for [place] as a modal bottom
/// sheet — deliberately not a full route, since this is always reached from
/// somewhere already showing the place as a card ([PlaceCard]).
Future<void> showPlaceDetailsSheet(BuildContext context, {required Place place, required PlacesService placesService}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => PlaceDetailsSheet(place: place, placesService: placesService),
  );
}

class PlaceDetailsSheet extends StatelessWidget {
  const PlaceDetailsSheet({super.key, required this.place, required this.placesService});

  final Place place;
  final PlacesService placesService;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          child: SingleChildScrollView(
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
                  if (place.photoNames.isNotEmpty) ...[
                    _PlacePhotoGallery(photoNames: place.photoNames, placesService: placesService),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  Text(place.name, style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  Text(place.categoryLabel, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      if (place.rating != null) RatingWidget(rating: place.rating!, reviewCount: place.userRatingCount, starSize: 18),
                      if (place.priceLevelLabel.isNotEmpty) ...[
                        const SizedBox(width: AppSpacing.md),
                        Text(place.priceLevelLabel, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
                      ],
                      if (place.isOpenNow != null) ...[
                        const SizedBox(width: AppSpacing.md),
                        Text(
                          place.isOpenNow! ? 'Open now' : 'Closed now',
                          style: theme.textTheme.labelMedium?.copyWith(color: place.isOpenNow! ? AppColors.success : AppColors.error),
                        ),
                      ],
                    ],
                  ),
                  if (place.address.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Symbols.location_on_rounded, size: 18, color: AppColors.textSecondary),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: Text(place.address, style: theme.textTheme.bodyMedium)),
                      ],
                    ),
                  ],
                  if (place.phoneNumber.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    InkWell(
                      onTap: () => launchUrl(Uri.parse('tel:${place.phoneNumber}')),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: Row(
                        children: [
                          const Icon(Symbols.call_rounded, size: 18, color: AppColors.textSecondary),
                          const SizedBox(width: AppSpacing.sm),
                          Text(place.phoneNumber, style: theme.textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  ],
                  if (place.websiteUri.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    InkWell(
                      onTap: () => MapsLauncher.openUrl(place.websiteUri),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: Row(
                        children: [
                          const Icon(Symbols.language_rounded, size: 18, color: AppColors.textSecondary),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(child: Text(place.websiteUri, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium)),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  AnimatedButton(
                    label: 'Get Directions',
                    icon: Symbols.directions_rounded,
                    onPressed: place.hasCoordinates
                        ? () => MapsLauncher.openDirections(latitude: place.latitude!, longitude: place.longitude!, label: place.name)
                        : () => MapsLauncher.openPlaceSearch('${place.name}, Philippines'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A swipeable photo gallery for a place's `photoNames` — Places API
/// results often return several photos, but the sheet used to only ever
/// show `photoNames.first` as a static image with nothing to swipe between.
class _PlacePhotoGallery extends StatefulWidget {
  const _PlacePhotoGallery({required this.photoNames, required this.placesService});

  final List<String> photoNames;
  final PlacesService placesService;

  @override
  State<_PlacePhotoGallery> createState() => _PlacePhotoGalleryState();
}

class _PlacePhotoGalleryState extends State<_PlacePhotoGallery> with AutoAdvanceGalleryMixin {
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    startAutoAdvance(_pageController, widget.photoNames.length);
  }

  @override
  void dispose() {
    stopAutoAdvance();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: SizedBox(
        height: 180,
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: widget.photoNames.length,
              itemBuilder: (context, index) => CachedNetworkImage(
                imageUrl: widget.placesService.photoUrl(widget.photoNames[index]),
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            if (widget.photoNames.length > 1)
              Positioned(
                bottom: AppSpacing.sm,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Center(
                    child: SmoothPageIndicator(
                      controller: _pageController,
                      count: widget.photoNames.length,
                      effect: WormEffect(
                        dotHeight: 6,
                        dotWidth: 6,
                        spacing: 6,
                        activeDotColor: Colors.white,
                        dotColor: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
