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
import '../../core/widgets/layout/max_width_container.dart';
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
    final sidePadding = MaxWidthContainer.sidePadding(context, maxWidth: 900);

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
          padding: EdgeInsets.fromLTRB(
            sidePadding,
            AppSpacing.lg,
            sidePadding,
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
                if (province.cultureNotes.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final note in province.cultureNotes) ...[
                        _CultureNoteCard(note: note),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                    ],
                  )
                else
                  Text(
                    province.localCulture,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                  ),
                if (province.localTransport.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xxl),
                  Text('Getting Around', style: theme.textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.sm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final note in province.localTransport) ...[
                        _TransportNoteCard(note: note),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                    ],
                  ),
                ],
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
              ] else ...[
                // No curated tourist_spots yet for this province (the LGU
                // hasn't added any) — falls back to a live Places search so
                // the page never goes blank just because nothing's been
                // curated, same reasoning as Hotels & Resorts below.
                const SizedBox(height: AppSpacing.xxl),
                NearbyPlacesSection(
                  title: 'Things to Do',
                  includedTypes: PlaceCategory.attractions,
                  textQuery:
                      'tourist attractions in ${province.name}, Philippines',
                  areaLabel: province.name,
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
              ] else ...[
                // No curated (or approved-business) restaurants yet for
                // this province — same live-Places fallback reasoning as
                // Featured Attractions above.
                const SizedBox(height: AppSpacing.xl),
                NearbyPlacesSection(
                  title: 'Where to Eat',
                  includedTypes: PlaceCategory.dining,
                  textQuery: 'restaurants in ${province.name}, Philippines',
                  areaLabel: province.name,
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
///
/// When a province has no curated `heroImageUrl`/`galleryImageUrls` on file
/// yet (most of them, until an LGU/admin fills them in — see
/// `AdminBulkProvinceContentScreen`), this falls back to a real Google
/// Places photo of the province itself instead of a flat tinted rectangle —
/// the same "never show nothing when live data can fill the gap"
/// principle `NearbyPlacesSection` already applies to attractions/dining.
class _ProvinceGallery extends StatefulWidget {
  const _ProvinceGallery({required this.province});

  final Province province;

  @override
  State<_ProvinceGallery> createState() => _ProvinceGalleryState();
}

class _ProvinceGalleryState extends State<_ProvinceGallery>
    with AutoAdvanceGalleryMixin {
  final PageController _pageController = PageController();
  final PlacesService _places = PlacesService();
  Future<String?>? _liveFallbackPhoto;

  bool get _hasStoredImages =>
      widget.province.heroImageUrl.isNotEmpty ||
      widget.province.galleryImageUrls.any((u) => u.isNotEmpty);

  @override
  void initState() {
    super.initState();
    if (_hasStoredImages) {
      final imageCount = [
        widget.province.heroImageUrl,
        ...widget.province.galleryImageUrls,
      ].where((u) => u.isNotEmpty).length;
      startAutoAdvance(_pageController, imageCount);
    } else {
      _liveFallbackPhoto = _loadLiveFallbackPhoto();
    }
  }

  /// A province name resolves in Places Text Search to a single
  /// administrative-area result (the same limitation the Search screen's
  /// area-match fallback works around) — but that single result still
  /// carries real photos of the province itself, which is exactly what's
  /// wanted here.
  Future<String?> _loadLiveFallbackPhoto() async {
    final places = await _places.searchText(
      textQuery: '${widget.province.name}, Philippines',
      maxResultCount: 1,
    );
    if (places.isEmpty || places.first.photoNames.isEmpty) return null;
    return _places.photoUrl(places.first.photoNames.first);
  }

  @override
  void dispose() {
    stopAutoAdvance();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final province = widget.province;
    final images = [
      province.heroImageUrl,
      ...province.galleryImageUrls,
    ].where((u) => u.isNotEmpty).toList();
    final fallbackTint = Container(
      color: theme.colorScheme.primary.withValues(alpha: 0.15),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        if (images.isNotEmpty)
          PageView.builder(
            controller: _pageController,
            itemCount: images.length,
            itemBuilder: (context, index) =>
                CachedNetworkImage(imageUrl: images[index], fit: BoxFit.cover),
          )
        else
          FutureBuilder<String?>(
            future: _liveFallbackPhoto,
            builder: (context, snapshot) {
              final url = snapshot.data;
              if (url == null || url.isEmpty) return fallbackTint;
              return CachedNetworkImage(imageUrl: url, fit: BoxFit.cover);
            },
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
                TagChip(
                  label: province.regionName,
                  color: theme.colorScheme.primary,
                ),
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

  void _open(BuildContext context) {
    // Best-effort, fire-and-forget — a failed count shouldn't block opening
    // the sheet itself.
    BusinessRepository().incrementViewCount(business.id).catchError((_) {});
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BusinessInfoSheet(business: business),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      onTap: () => _open(context),
      child: Container(
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
                  child: Text(
                    business.name,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                TagChip(
                  label: BusinessCategory.label(business.category),
                  color: theme.colorScheme.primary,
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
              // Not its own tap target — the tile itself opens
              // _BusinessInfoSheet below, which has a proper "Visit Website"
              // button; a nested tap target here would fight the tile's own
              // InkWell over the same gesture.
              Text(
                business.websiteUrl,
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: 12,
                  decoration: TextDecoration.underline,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Opened by tapping a [_BusinessTile] — the full, untruncated version of
/// what the tile already shows, plus real tap-to-call/tap-to-open actions
/// the tile's own plain text can't offer (a nested tap target there would
/// fight the tile's own onTap over the same gesture).
class _BusinessInfoSheet extends StatelessWidget {
  const _BusinessInfoSheet({required this.business});

  final Business business;

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
        child: Padding(
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
                  Expanded(
                    child: Text(
                      business.name,
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                  TagChip(
                    label: BusinessCategory.label(business.category),
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
              if (business.description.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  business.description,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
              ],
              if (business.openingHours.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                _InfoRow(
                  icon: Symbols.schedule_rounded,
                  text: business.openingHours,
                ),
              ],
              if (business.address.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: InkWell(
                    onTap: () => MapsLauncher.openPlaceSearch(business.address),
                    child: _InfoRow(
                      icon: Symbols.location_on_rounded,
                      text: business.address,
                    ),
                  ),
                ),
              if (business.contactNumber.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: InkWell(
                    onTap: () =>
                        launchUrl(Uri.parse('tel:${business.contactNumber}')),
                    child: _InfoRow(
                      icon: Symbols.call_rounded,
                      text: business.contactNumber,
                    ),
                  ),
                ),
              if (business.websiteUrl.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                AnimatedButton(
                  label: 'Visit Website',
                  icon: Symbols.open_in_new_rounded,
                  filled: false,
                  onPressed: () => launchUrl(
                    Uri.parse(business.websiteUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textTertiary),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
      ],
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

/// One scannable "Local Culture" card — see [Province.cultureNotes]'s doc
/// comment on why this only shows once an admin has filled at least one in.
class _CultureNoteCard extends StatelessWidget {
  const _CultureNoteCard({required this.note});

  final CultureNote note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
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
              Icon(
                Symbols.diversity_3_rounded,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  note.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            note.body,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}

/// One scannable "Getting Around" card — same shape as [_CultureNoteCard],
/// reused (not shared) since [TransportNote] and [CultureNote] are distinct
/// types with different field names.
class _TransportNoteCard extends StatelessWidget {
  const _TransportNoteCard({required this.note});

  final TransportNote note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
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
              Icon(
                Symbols.directions_bus_rounded,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  note.mode,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            note.note,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}
