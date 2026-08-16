import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/providers/favorites_provider.dart';
import '../../core/routes/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/maps_launcher.dart';
import '../../core/utils/share_text.dart';
import '../../core/widgets/buttons/animated_button.dart';
import '../../core/widgets/cards/destination_card.dart';
import '../../core/widgets/cards/tag_chip.dart';
import '../../core/widgets/details/details_gallery_app_bar.dart';
import '../../core/widgets/details/info_stat_card.dart';
import '../../core/widgets/details/map_preview.dart';
import '../../core/widgets/details/review_section.dart';
import '../../core/widgets/dialogs/emergency_access_sheet.dart';
import '../../core/widgets/indicators/rating_widget.dart';
import '../../core/widgets/layout/max_width_container.dart';
import '../../core/widgets/layout/section_header.dart';
import '../../core/widgets/states/empty_state_widget.dart';
import '../../core/widgets/states/loading_widget.dart';
import '../../data/repositories/destination_repository.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../domain/models/destination.dart';
import '../../domain/models/restaurant.dart';
import '../../domain/models/review.dart';

/// Full detail view for a restaurant: gallery, key facts, menu highlights,
/// description, nearby attractions in the same area, and reviews — loaded
/// live from Firestore.
class RestaurantDetailsScreen extends StatefulWidget {
  const RestaurantDetailsScreen({super.key, required this.restaurantId});

  final String restaurantId;

  @override
  State<RestaurantDetailsScreen> createState() =>
      _RestaurantDetailsScreenState();
}

class _RestaurantDetailsScreenState extends State<RestaurantDetailsScreen> {
  final RestaurantRepository _restaurantRepository = RestaurantRepository();
  final DestinationRepository _destinationRepository = DestinationRepository();
  final UserRepository _userRepository = UserRepository();

  late Future<_RestaurantDetailsData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_RestaurantDetailsData> _load() async {
    final uid = context.read<AuthProvider>().firebaseUser?.uid;

    final restaurant = await _restaurantRepository.getById(widget.restaurantId);
    if (restaurant == null) {
      throw const AppException('This restaurant is no longer available.');
    }
    final nearbyAttractions = await _destinationRepository.filter(
      provinceId: restaurant.provinceId,
      limit: 6,
    );

    if (uid != null) {
      unawaited(
        _userRepository.recordVisit(
          uid: uid,
          targetType: 'restaurant',
          targetId: restaurant.id,
        ),
      );
    }

    return _RestaurantDetailsData(
      restaurant: restaurant,
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
        child: FutureBuilder<_RestaurantDetailsData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return LoadingWidget.detailPage();
            }
            if (snapshot.hasError) {
              return SafeArea(
                child: EmptyStateWidget(
                  icon: Symbols.error_outline_rounded,
                  title: 'Couldn\'t load this restaurant',
                  message: AppException.from(snapshot.error!).message,
                  actionLabel: 'Go back',
                  onActionTap: () => context.pop(),
                ),
              );
            }
            return _RestaurantDetailsBody(data: snapshot.data!);
          },
        ),
      ),
    );
  }
}

class _RestaurantDetailsData {
  const _RestaurantDetailsData({
    required this.restaurant,
    required this.nearbyAttractions,
  });

  final Restaurant restaurant;
  final List<Destination> nearbyAttractions;
}

class _RestaurantDetailsBody extends StatelessWidget {
  const _RestaurantDetailsBody({required this.data});

  final _RestaurantDetailsData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final restaurant = data.restaurant;
    final saved = context.watch<FavoritesProvider>();
    final sidePadding = MaxWidthContainer.sidePadding(context, maxWidth: 900);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          DetailsGalleryAppBar(
            imageUrls: restaurant.galleryImageUrls,
            title: restaurant.name,
            isSaved: saved.isRestaurantSaved(restaurant.id),
            onToggleSaved: () => saved.toggleRestaurant(restaurant.id),
            onShare: () => Share.share(ShareText.forRestaurant(restaurant)),
            onEmergency: () => showEmergencyAccessSheet(
              context,
              provinceId: restaurant.provinceId,
              provinceName: restaurant.provinceName,
            ),
            heroTag: 'restaurant-${restaurant.id}',
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
                            restaurant.name,
                            style: theme.textTheme.displayMedium,
                          ),
                          if (restaurant.businessId.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            TagChip(
                              label: 'Verified Partner',
                              color: theme.colorScheme.primary,
                            ),
                          ],
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Symbols.location_on_rounded,
                                size: 16,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${restaurant.cuisine} · ',
                                style: theme.textTheme.bodyMedium,
                              ),
                              Flexible(
                                child: InkWell(
                                  onTap: () => context.push(
                                    RoutePaths.provinceDetails(
                                      restaurant.provinceId,
                                    ),
                                  ),
                                  child: Text(
                                    restaurant.provinceName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    RatingWidget(
                      rating: restaurant.rating,
                      reviewCount: restaurant.reviewCount,
                      starSize: 20,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    InfoStatCard(
                      icon: Symbols.payments_rounded,
                      label: 'Price Range',
                      value: restaurant.priceRange,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    InfoStatCard(
                      icon: Symbols.schedule_rounded,
                      label: 'Open Hours',
                      value: restaurant.openingHours,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    InfoStatCard(
                      icon: Symbols.star_rounded,
                      label: 'Rating',
                      value: restaurant.rating.toStringAsFixed(1),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxl),
                Text('About', style: theme.textTheme.titleLarge),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  restaurant.description,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                ),
                if (restaurant.accessibilityTags.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text('Accessibility', style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: restaurant.accessibilityTags
                        .map((tag) => TagChip(label: tag, color: AppColors.success))
                        .toList(),
                  ),
                ],
                const SizedBox(height: AppSpacing.xxl),
                Text('Location', style: theme.textTheme.titleLarge),
                const SizedBox(height: AppSpacing.sm),
                MapPreview(
                  latitude: restaurant.latitude,
                  longitude: restaurant.longitude,
                  label: restaurant.name,
                ),
                if (restaurant.websiteUrl.isNotEmpty ||
                    restaurant.facebookUrl.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      if (restaurant.websiteUrl.isNotEmpty)
                        Expanded(
                          child: AnimatedButton(
                            label: 'Website',
                            icon: Symbols.language_rounded,
                            filled: false,
                            onPressed: () =>
                                MapsLauncher.openUrl(restaurant.websiteUrl),
                          ),
                        ),
                      if (restaurant.websiteUrl.isNotEmpty &&
                          restaurant.facebookUrl.isNotEmpty)
                        const SizedBox(width: AppSpacing.sm),
                      if (restaurant.facebookUrl.isNotEmpty)
                        Expanded(
                          child: AnimatedButton(
                            label: 'Facebook',
                            icon: Symbols.thumb_up_rounded,
                            filled: false,
                            onPressed: () =>
                                MapsLauncher.openUrl(restaurant.facebookUrl),
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.xxl),
                Text('Menu Highlights', style: theme.textTheme.titleLarge),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  height: 168,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: restaurant.menuHighlights.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: AppSpacing.md),
                    itemBuilder: (context, i) =>
                        _MenuItemTile(item: restaurant.menuHighlights[i]),
                  ),
                ),
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
                const SizedBox(height: AppSpacing.xl),
                ReviewSection(
                  targetId: restaurant.id,
                  targetType: ReviewTargetType.restaurant,
                  reviewCount: restaurant.reviewCount,
                  ownerUserId: restaurant.ownerId,
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
                  label: 'Call',
                  icon: Symbols.call_rounded,
                  filled: false,
                  onPressed: restaurant.phoneNumber.isNotEmpty
                      ? () => launchUrl(
                          Uri.parse('tel:${restaurant.phoneNumber}'),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 2,
                child: AnimatedButton(
                  label: 'Get Directions',
                  icon: Symbols.directions_rounded,
                  onPressed: restaurant.hasCoordinates
                      ? () => MapsLauncher.openDirections(
                          latitude: restaurant.latitude!,
                          longitude: restaurant.longitude!,
                          label: restaurant.name,
                        )
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuItemTile extends StatelessWidget {
  const _MenuItemTile({required this.item});

  final MenuItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 140,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.lg),
            ),
            child: CachedNetworkImage(
              imageUrl: item.imageUrl,
              height: 96,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  item.price,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
