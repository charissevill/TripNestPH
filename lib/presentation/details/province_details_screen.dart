import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/routes/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/auto_advance_gallery_mixin.dart';
import '../../core/utils/maps_launcher.dart';
import '../../core/services/places_service.dart';
import '../../core/widgets/buttons/animated_button.dart';
import '../../core/widgets/cards/destination_card.dart';
import '../../core/widgets/cards/festival_card.dart';
import '../../core/widgets/cards/restaurant_card.dart';
import '../../core/widgets/cards/tag_chip.dart';
import '../../core/widgets/carousels/nearby_places_section.dart';
import '../../core/widgets/details/info_stat_card.dart';
import '../../core/widgets/layout/section_header.dart';
import '../../core/widgets/states/empty_state_widget.dart';
import '../../core/widgets/states/loading_widget.dart';
import '../../data/repositories/business_repository.dart';
import '../../data/repositories/destination_repository.dart';
import '../../data/repositories/festival_repository.dart';
import '../../data/repositories/province_repository.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../domain/models/business.dart';
import '../../domain/models/destination.dart';
import '../../domain/models/festival.dart';
import '../../domain/models/province.dart';
import '../../domain/models/restaurant.dart';

/// Full detail view for a single province: overview, culture, budget and
/// travel tips (once curated — see [Province.hasContent]), plus its
/// featured attractions, festivals, dining, live Places API accommodations/
/// transport, and approved `businessOwner`-submitted local businesses, all
/// pulled by `provinceId`.
class ProvinceDetailsScreen extends StatefulWidget {
  const ProvinceDetailsScreen({super.key, required this.provinceId});

  final String provinceId;

  @override
  State<ProvinceDetailsScreen> createState() => _ProvinceDetailsScreenState();
}

class _ProvinceDetailsScreenState extends State<ProvinceDetailsScreen> {
  final ProvinceRepository _provinceRepository = ProvinceRepository();
  final DestinationRepository _destinationRepository = DestinationRepository();
  final RestaurantRepository _restaurantRepository = RestaurantRepository();
  final FestivalRepository _festivalRepository = FestivalRepository();
  final BusinessRepository _businessRepository = BusinessRepository();

  late Future<_ProvinceDetailsData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ProvinceDetailsData> _load() async {
    final province = await _provinceRepository.getById(widget.provinceId);
    if (province == null) {
      throw const AppException('This province is no longer available.');
    }

    final featured = province.featuredDestinationIds.isNotEmpty
        ? await _destinationRepository.getByIds(province.featuredDestinationIds)
        : await _destinationRepository.filter(
            provinceId: province.id,
            limit: 10,
          );
    final festivals = await _festivalRepository.filter(
      provinceId: province.id,
      limit: 10,
    );
    final restaurants = await _restaurantRepository.filter(
      provinceId: province.id,
      limit: 10,
    );
    // Best-effort: a business-directory hiccup should never block the rest
    // of the page, same reasoning as every other supplementary section here.
    final businesses = await _businessRepository
        .getApprovedForProvince(province.id)
        .catchError((_) => <Business>[]);

    return _ProvinceDetailsData(
      province: province,
      destinations: featured,
      festivals: festivals,
      restaurants: restaurants,
      businesses: businesses,
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
        child: FutureBuilder<_ProvinceDetailsData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return LoadingWidget.detailPage();
            }
            if (snapshot.hasError) {
              return SafeArea(
                child: EmptyStateWidget(
                  icon: Symbols.error_outline_rounded,
                  title: 'Couldn\'t load this province',
                  message: AppException.from(snapshot.error!).message,
                  actionLabel: 'Go back',
                  onActionTap: () => context.pop(),
                ),
              );
            }
            return _ProvinceDetailsBody(data: snapshot.data!);
          },
        ),
      ),
    );
  }
}

class _ProvinceDetailsData {
  const _ProvinceDetailsData({
    required this.province,
    required this.destinations,
    required this.festivals,
    required this.restaurants,
    required this.businesses,
  });

  final Province province;
  final List<Destination> destinations;
  final List<Festival> festivals;
  final List<Restaurant> restaurants;
  final List<Business> businesses;
}

class _ProvinceDetailsBody extends StatelessWidget {
  const _ProvinceDetailsBody({required this.data});

  final _ProvinceDetailsData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final province = data.province;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 240,
          backgroundColor: theme.colorScheme.surface,
          surfaceTintColor: Colors.transparent,
          leading: Padding(
            padding: const EdgeInsets.only(left: AppSpacing.md),
            child: _CircleButton(
              icon: Symbols.arrow_back_rounded,
              onTap: () => context.pop(),
            ),
          ),
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.pin,
            background: _ProvinceGallery(province: province),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.huge,
          ),
          sliver: SliverList.list(
            children: [
              AnimatedButton(
                label: 'View on Google Maps',
                icon: Symbols.map_rounded,
                filled: false,
                onPressed: () => MapsLauncher.openPlaceSearch(
                  '${province.name}, Philippines',
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              if (!province.hasContent) ...[
                const EmptyStateWidget(
                  icon: Symbols.auto_stories_rounded,
                  title: 'Content coming soon',
                  message:
                      'This province\'s travel guide is still being written — check back soon.',
                ),
                const SizedBox(height: AppSpacing.md),
              ] else ...[
                Text(
                  province.overview,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    InfoStatCard(
                      icon: Symbols.calendar_month_rounded,
                      label: 'Best Time',
                      value: province.bestTimeToVisit.split(';').first.trim(),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    InfoStatCard(
                      icon: Symbols.payments_rounded,
                      label: 'Daily Budget',
                      value:
                          '₱${province.estimatedDailyBudgetMin.toStringAsFixed(0)}–${province.estimatedDailyBudgetMax.toStringAsFixed(0)}',
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxl),
                Text('Local Culture', style: theme.textTheme.titleLarge),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  province.localCulture,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                ),
              ],
              if (data.destinations.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xxl),
                const SectionHeader(
                  title: 'Featured Attractions',
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  height: 250,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: data.destinations.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: AppSpacing.md),
                    itemBuilder: (context, i) => DestinationCard(
                      destination: data.destinations[i],
                      onTap: () => context.push(
                        RoutePaths.destinationDetails(data.destinations[i].id),
                      ),
                    ),
                  ),
                ),
              ],
              if (data.festivals.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xl),
                const SectionHeader(
                  title: 'Local Festivals',
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  height: 250,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: data.festivals.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: AppSpacing.md),
                    itemBuilder: (context, i) => FestivalCard(
                      festival: data.festivals[i],
                      onTap: () => context.push(
                        RoutePaths.festivalDetails(data.festivals[i].id),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              NearbyPlacesSection(
                title: 'Hotels & Resorts',
                includedTypes: PlaceCategory.lodging,
                textQuery: 'hotels in ${province.name}, Philippines',
                areaLabel: province.name,
              ),
              const SizedBox(height: AppSpacing.xl),
              NearbyPlacesSection(
                title: 'Getting Around',
                includedTypes: PlaceCategory.transportTerminals,
                textQuery:
                    'bus and transport terminals in ${province.name}, Philippines',
                areaLabel: province.name,
              ),
              if (data.businesses.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xl),
                const SectionHeader(
                  title: 'Local Businesses',
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(height: AppSpacing.md),
                ...data.businesses.map(
                  (business) => _BusinessTile(business: business),
                ),
              ],
              if (data.restaurants.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xl),
                const SectionHeader(
                  title: 'Where to Eat',
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  height: 250,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: data.restaurants.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: AppSpacing.md),
                    itemBuilder: (context, i) => RestaurantCard(
                      restaurant: data.restaurants[i],
                      onTap: () => context.push(
                        RoutePaths.restaurantDetails(data.restaurants[i].id),
                      ),
                    ),
                  ),
                ),
              ],
              if (province.hasContent && province.travelTips.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xxl),
                Text('Travel Tips', style: theme.textTheme.titleLarge),
                const SizedBox(height: AppSpacing.sm),
                ...province.travelTips.map(
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
              ],
              if (province.hasContent &&
                  province.emergencyHotlines.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xxl),
                Text('Emergency Hotlines', style: theme.textTheme.titleLarge),
                const SizedBox(height: AppSpacing.sm),
                ...province.emergencyHotlines.map(
                  (hotline) => InkWell(
                    onTap: () => launchUrl(Uri.parse('tel:${hotline.number}')),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(
                            Symbols.emergency_rounded,
                            size: 18,
                            color: AppColors.error,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              hotline.label,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                          Text(
                            hotline.number,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The province cover's swipeable photo gallery — hero image first, then
/// any additional `galleryImageUrls`, with a page indicator when there's
/// more than one. Same real `PageView` + dot-indicator pattern already used
/// by `DetailsGalleryAppBar` on the Tourist/Restaurant/Festival details
/// screens, kept as its own small widget here so the existing region-chip +
/// name overlay stays exactly as designed.
class _ProvinceGallery extends StatefulWidget {
  const _ProvinceGallery({required this.province});

  final Province province;

  @override
  State<_ProvinceGallery> createState() => _ProvinceGalleryState();
}

class _ProvinceGalleryState extends State<_ProvinceGallery>
    with AutoAdvanceGalleryMixin {
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    final imageCount = [
      widget.province.heroImageUrl,
      ...widget.province.galleryImageUrls,
    ].where((u) => u.isNotEmpty).length;
    startAutoAdvance(_pageController, imageCount);
  }

  @override
  void dispose() {
    stopAutoAdvance();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final province = widget.province;
    final images = [
      province.heroImageUrl,
      ...province.galleryImageUrls,
    ].where((u) => u.isNotEmpty).toList();

    return Stack(
      fit: StackFit.expand,
      children: [
        if (images.isEmpty)
          Container(color: AppColors.primary.withValues(alpha: 0.15))
        else
          PageView.builder(
            controller: _pageController,
            itemCount: images.length,
            itemBuilder: (context, index) =>
                CachedNetworkImage(imageUrl: images[index], fit: BoxFit.cover),
          ),
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.6),
                ],
              ),
            ),
          ),
        ),
        if (images.length > 1)
          Positioned(
            top: AppSpacing.huge,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: SmoothPageIndicator(
                  controller: _pageController,
                  count: images.length,
                  effect: WormEffect(
                    dotHeight: 6,
                    dotWidth: 6,
                    spacing: 6,
                    activeDotColor: Colors.white,
                    dotColor: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          bottom: AppSpacing.lg,
          child: IgnorePointer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TagChip(label: province.regionName, color: AppColors.primary),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  province.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A single approved business-directory listing — a traveler-facing,
/// read-only card. No coordinates/photos are guaranteed (unlike Places API
/// results), so this stays a compact info card rather than a full
/// `NearbyPlacesSection`-style carousel.
class _BusinessTile extends StatelessWidget {
  const _BusinessTile({required this.business});

  final Business business;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(business.name, style: theme.textTheme.titleMedium),
              ),
              TagChip(
                label: BusinessCategory.label(business.category),
                color: AppColors.primary,
              ),
            ],
          ),
          if (business.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              business.description,
              style: theme.textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (business.address.isNotEmpty ||
              business.contactNumber.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                const Icon(
                  Symbols.location_on_rounded,
                  size: 14,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    [
                      business.address,
                      business.contactNumber,
                    ].where((s) => s.isNotEmpty).join(' · '),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (business.websiteUrl.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            InkWell(
              onTap: () => launchUrl(
                Uri.parse(business.websiteUrl),
                mode: LaunchMode.externalApplication,
              ),
              child: Text(
                business.websiteUrl,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}
