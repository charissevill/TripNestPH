import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/providers/favorites_provider.dart';
import '../../core/routes/route_paths.dart';
import '../../core/services/places_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/maps_launcher.dart';
import '../../core/utils/share_text.dart';
import '../../core/widgets/buttons/animated_button.dart';
import '../../core/widgets/cards/destination_card.dart';
import '../../core/widgets/states/loading_widget.dart';
import '../../core/widgets/cards/restaurant_card.dart';
import '../../core/widgets/cards/tag_chip.dart';
import '../../core/widgets/carousels/nearby_places_section.dart';
import '../../core/widgets/details/current_weather_card.dart';
import '../../core/widgets/details/details_gallery_app_bar.dart';
import '../../core/widgets/details/info_stat_card.dart';
import '../../core/widgets/details/map_preview.dart';
import '../../core/widgets/details/review_section.dart';
import '../../core/widgets/indicators/rating_widget.dart';
import '../../core/widgets/layout/max_width_container.dart';
import '../../core/widgets/layout/section_header.dart';
import '../../core/widgets/states/empty_state_widget.dart';
import '../../data/repositories/destination_repository.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../domain/models/destination.dart';
import '../../domain/models/restaurant.dart';
import '../../domain/models/review.dart';

/// Full detail view for a single tourist destination: gallery, key facts,
/// highlights, travel tips, nearby restaurants/attractions/hotels and
/// traveler reviews — all loaded live from Firestore.
class TouristDetailsScreen extends StatefulWidget {
  const TouristDetailsScreen({super.key, required this.destinationId});

  final String destinationId;

  @override
  State<TouristDetailsScreen> createState() => _TouristDetailsScreenState();
}

class _TouristDetailsScreenState extends State<TouristDetailsScreen> {
  final DestinationRepository _destinationRepository = DestinationRepository();
  final RestaurantRepository _restaurantRepository = RestaurantRepository();
  final UserRepository _userRepository = UserRepository();

  late Future<_TouristDetailsData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_TouristDetailsData> _load() async {
    final uid = context.read<AuthProvider>().firebaseUser?.uid;

    final destination = await _destinationRepository.getById(
      widget.destinationId,
    );
    if (destination == null) {
      throw const AppException('This destination is no longer available.');
    }
    final nearbyRestaurants = await _restaurantRepository.getByIds(
      destination.nearbyRestaurantIds,
    );
    final nearbyAttractions = await _destinationRepository.getByIds(
      destination.nearbyDestinationIds
          .where((id) => id != destination.id)
          .toList(),
    );

    if (uid != null) {
      unawaited(_userRepository.recordRecentlyViewed(uid, destination.id));
      unawaited(
        _userRepository.recordVisit(
          uid: uid,
          targetType: 'destination',
          targetId: destination.id,
        ),
      );
    }

    return _TouristDetailsData(
      destination: destination,
      nearbyRestaurants: nearbyRestaurants,
      nearbyAttractions: nearbyAttractions,
    );
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _future = future);
    try {
      await future;
    } catch (_) {
      // Surfaced by the FutureBuilder's error state below; RefreshIndicator
      // just needs this Future to complete either way.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<_TouristDetailsData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return LoadingWidget.detailPage();
            }
            if (snapshot.hasError) {
              return SafeArea(
                child: EmptyStateWidget(
                  icon: Symbols.error_outline_rounded,
                  title: 'Couldn\'t load this destination',
                  message: AppException.from(snapshot.error!).message,
                  actionLabel: 'Go back',
                  onActionTap: () => context.pop(),
                ),
              );
            }
            return _TouristDetailsBody(data: snapshot.data!);
          },
        ),
      ),
    );
  }
}

class _TouristDetailsData {
  const _TouristDetailsData({
    required this.destination,
    required this.nearbyRestaurants,
    required this.nearbyAttractions,
  });

  final Destination destination;
  final List<Restaurant> nearbyRestaurants;
  final List<Destination> nearbyAttractions;
}

class _TouristDetailsBody extends StatelessWidget {
  const _TouristDetailsBody({required this.data});

  final _TouristDetailsData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final destination = data.destination;
    final saved = context.watch<FavoritesProvider>();
    final sidePadding = MaxWidthContainer.sidePadding(context, maxWidth: 900);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          DetailsGalleryAppBar(
            imageUrls: destination.galleryImageUrls,
            title: destination.name,
            isSaved: saved.isDestinationSaved(destination.id),
            onToggleSaved: () => saved.toggleDestination(destination.id),
            onShare: () => Share.share(ShareText.forDestination(destination)),
            heroTag: 'destination-${destination.id}',
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              sidePadding,
              AppSpacing.lg,
              sidePadding,
              AppSpacing.huge,
            ),
            sliver: SliverList.list(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            destination.name,
                            style: theme.textTheme.displayMedium,
                          ),
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: () => context.push(
                              RoutePaths.provinceDetails(
                                destination.provinceId,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Symbols.location_on_rounded,
                                  size: 16,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 2),
                                Flexible(
                                  child: Text(
                                    destination.provinceName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    RatingWidget(
                      rating: destination.rating,
                      reviewCount: destination.reviewCount,
                      starSize: 20,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    InfoStatCard(
                      icon: Symbols.confirmation_number_rounded,
                      label: 'Entrance Fee',
                      value: destination.entranceFee,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    InfoStatCard(
                      icon: Symbols.calendar_month_rounded,
                      label: 'Best Time',
                      value: destination.bestTimeToVisit
                          .split('(')
                          .first
                          .trim(),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    InfoStatCard(
                      icon: Symbols.star_rounded,
                      label: 'Rating',
                      value: destination.rating.toStringAsFixed(1),
                    ),
                  ],
                ),
                if (destination.hasCoordinates) ...[
                  const SizedBox(height: AppSpacing.lg),
                  CurrentWeatherCard(
                    locationLabel: destination.name,
                    latitude: destination.latitude!,
                    longitude: destination.longitude!,
                  ),
                ],
                const SizedBox(height: AppSpacing.xxl),
                Text('Highlights', style: theme.textTheme.titleLarge),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: destination.highlights
                      .map(
                        (h) => TagChip(label: h, color: theme.colorScheme.primary),
                      )
                      .toList(),
                ),
                const SizedBox(height: AppSpacing.xxl),
                Text('About', style: theme.textTheme.titleLarge),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  destination.longDescription,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                ),
                const SizedBox(height: AppSpacing.xxl),
                Text('Location', style: theme.textTheme.titleLarge),
                const SizedBox(height: AppSpacing.sm),
                MapPreview(
                  latitude: destination.latitude,
                  longitude: destination.longitude,
                  label: destination.name,
                ),
                if (destination.openingHours.isNotEmpty ||
                    destination.phoneNumber.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  if (destination.openingHours.isNotEmpty)
                    _InfoRow(
                      icon: Symbols.schedule_rounded,
                      text: destination.openingHours,
                    ),
                  if (destination.phoneNumber.isNotEmpty)
                    _InfoRow(
                      icon: Symbols.call_rounded,
                      text: destination.phoneNumber,
                      onTap: () => launchUrl(
                        Uri.parse('tel:${destination.phoneNumber}'),
                      ),
                    ),
                ],
                if (destination.websiteUrl.isNotEmpty ||
                    destination.facebookUrl.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      if (destination.websiteUrl.isNotEmpty)
                        Expanded(
                          child: AnimatedButton(
                            label: 'Website',
                            icon: Symbols.language_rounded,
                            filled: false,
                            onPressed: () =>
                                MapsLauncher.openUrl(destination.websiteUrl),
                          ),
                        ),
                      if (destination.websiteUrl.isNotEmpty &&
                          destination.facebookUrl.isNotEmpty)
                        const SizedBox(width: AppSpacing.sm),
                      if (destination.facebookUrl.isNotEmpty)
                        Expanded(
                          child: AnimatedButton(
                            label: 'Facebook',
                            icon: Symbols.thumb_up_rounded,
                            filled: false,
                            onPressed: () =>
                                MapsLauncher.openUrl(destination.facebookUrl),
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.xxl),
                Text('Travel Tips', style: theme.textTheme.titleLarge),
                const SizedBox(height: AppSpacing.sm),
                ...destination.travelTips.map(
                  (tip) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 3),
                          child: Icon(
                            Symbols.lightbulb_rounded,
                            size: 18,
                            color: AppColors.accentDark,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(tip, style: theme.textTheme.bodyMedium),
                        ),
                      ],
                    ),
                  ),
                ),
                if (data.nearbyRestaurants.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  const SectionHeader(
                    title: 'Nearby Restaurants',
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    height: 250,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: data.nearbyRestaurants.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(width: AppSpacing.md),
                      itemBuilder: (context, i) => RestaurantCard(
                        restaurant: data.nearbyRestaurants[i],
                        onTap: () => context.push(
                          RoutePaths.restaurantDetails(
                            data.nearbyRestaurants[i].id,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                if (data.nearbyAttractions.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xl),
                  const SectionHeader(
                    title: 'Nearby Attractions',
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    height: 250,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: data.nearbyAttractions.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(width: AppSpacing.md),
                      itemBuilder: (context, i) => DestinationCard(
                        destination: data.nearbyAttractions[i],
                        onTap: () => context.push(
                          RoutePaths.destinationDetails(
                            data.nearbyAttractions[i].id,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                if (destination.hasCoordinates) ...[
                  const SizedBox(height: AppSpacing.xl),
                  NearbyPlacesSection(
                    title: 'Nearby Hotels',
                    includedTypes: PlaceCategory.lodging,
                    latitude: destination.latitude,
                    longitude: destination.longitude,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  NearbyPlacesSection(
                    title: 'Getting Around',
                    includedTypes: PlaceCategory.transportTerminals,
                    latitude: destination.latitude,
                    longitude: destination.longitude,
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                ReviewSection(
                  targetId: destination.id,
                  targetType: ReviewTargetType.destination,
                  reviewCount: destination.reviewCount,
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            sidePadding,
            AppSpacing.sm,
            sidePadding,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: AnimatedButton(
                  label: 'Get Directions',
                  icon: Symbols.directions_rounded,
                  filled: false,
                  onPressed: destination.hasCoordinates
                      ? () => MapsLauncher.openDirections(
                          latitude: destination.latitude!,
                          longitude: destination.longitude!,
                          label: destination.name,
                        )
                      : null,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 2,
                child: AnimatedButton(
                  label: 'Plan a Trip Here',
                  icon: Symbols.auto_awesome_rounded,
                  onPressed: () => context.go(RoutePaths.planner),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text, this.onTap});

  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
            ),
          ],
        ),
      ),
    );
  }
}
