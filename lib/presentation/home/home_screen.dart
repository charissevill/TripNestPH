import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/routes/route_paths.dart';
import '../../core/services/local_preferences_service.dart';
import '../../core/services/places_service.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_exception.dart';
import '../../core/widgets/banners/hero_banner.dart';
import '../../core/widgets/cards/category_card.dart';
import '../../core/widgets/cards/festival_card.dart';
import '../../core/widgets/cards/place_card.dart';
import '../../core/widgets/cards/travel_tip_card.dart';
import '../../core/widgets/details/place_details_sheet.dart';
import '../../core/widgets/inputs/search_bar_widget.dart';
import '../../core/widgets/layout/section_header.dart';
import '../../core/widgets/states/empty_state_widget.dart';
import '../../core/widgets/states/loading_widget.dart';
import '../../data/mock/mock_categories.dart';
import '../../data/repositories/festival_repository.dart';
import '../../data/repositories/notification_repository.dart';
import '../../core/services/location_service.dart';
import '../../data/repositories/travel_tip_repository.dart';
import '../../domain/models/app_notification.dart';
import '../../domain/models/festival.dart';
import '../../domain/models/place.dart';
import '../../domain/models/travel_tip.dart';
import 'widgets/home_header.dart';
import 'widgets/location_prompt_card.dart';

class _HomeData {
  const _HomeData({
    required this.featuredPlaces,
    required this.popularRestaurants,
    required this.upcomingFestivals,
    required this.travelTips,
  });

  /// Live Google Places results — LGU-curated `tourist_spots` are
  /// deliberately not shown on Home anymore (see the class doc on
  /// `ExploreScreen`). Google has no separate "featured" vs. "popular"
  /// distinction the way the old curated flags did, so this one batch
  /// backs both the hero banner and the carousel below it, and there's no
  /// standalone "Popular Tourist Spots" section anymore (it would just be
  /// a near-duplicate of this one). There's also no Places analog for a
  /// curated "Hidden Gem" flag at all, so that section is gone rather than
  /// faked.
  final List<Place> featuredPlaces;

  final List<Place> popularRestaurants;
  final List<Festival> upcomingFestivals;
  final List<TravelTip> travelTips;
}

/// The primary landing tab: greeting, search entry point, hero carousel and
/// a series of horizontally-scrolling discovery sections — all loaded live
/// from Firestore, except the tourist-spot sections, which are live Google
/// Places (see the class doc on `ExploreScreen` for why LGU-curated
/// `tourist_spots` content isn't shown here).
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.placesService,
    this.festivalRepository,
    this.travelTipRepository,
    this.notificationRepository,
    this.locationService,
  });

  // Test-only overrides — production call sites never pass these (same
  // pattern `ExploreScreen`/`SearchScreen` already use).
  final PlacesService? placesService;
  final FestivalRepository? festivalRepository;
  final TravelTipRepository? travelTipRepository;
  final NotificationRepository? notificationRepository;
  final LocationService? locationService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late final PlacesService _places = widget.placesService ?? PlacesService();
  late final FestivalRepository _festivalRepository =
      widget.festivalRepository ?? FestivalRepository();
  late final TravelTipRepository _travelTipRepository =
      widget.travelTipRepository ?? TravelTipRepository();
  late final NotificationRepository _notificationRepository =
      widget.notificationRepository ?? NotificationRepository();
  late final LocationService _locationService =
      widget.locationService ?? LocationService();
  final LocalPreferencesService _preferences = LocalPreferencesService();

  late Future<_HomeData> _future;
  _HomeData? _lastData;
  List<Place> _nearby = [];
  List<Place> _nearbyRestaurants = [];
  double? _travelerLat;
  double? _travelerLng;
  LocationAccessStatus _nearbyStatus = LocationAccessStatus.unavailable;
  bool _locationBusy = false;
  bool _locationPromptDismissed = false;
  bool _locationFeatureEnabled = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _future = _load();
    _preferences.getLocationPromptDismissed().then((dismissed) {
      if (mounted) setState(() => _locationPromptDismissed = dismissed);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-checks location — without re-fetching Home's Firestore data — when
  /// the app resumes from background. Covers the "denied, went to Settings
  /// to enable it, came back" flow without a manual retry tap.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _nearbyStatus != LocationAccessStatus.granted &&
        _lastData != null) {
      _refreshNearby();
    }
  }

  Future<_HomeData> _load() async {
    final featuredPlacesFuture = _places.searchText(
      textQuery: 'top tourist attractions in the Philippines',
      maxResultCount: 20,
    );
    final popularRestaurantsFuture = _places.searchText(
      textQuery: 'best restaurants in the Philippines',
      maxResultCount: 20,
    );
    final upcomingFestivalsFuture = _festivalRepository.getUpcoming();
    final travelTipsFuture = _travelTipRepository.getAll();
    final data = _HomeData(
      featuredPlaces: await featuredPlacesFuture,
      popularRestaurants: await popularRestaurantsFuture,
      upcomingFestivals: await upcomingFestivalsFuture,
      travelTips: await travelTipsFuture,
    );
    _lastData = data;
    await _refreshNearby();
    return data;
  }

  /// Raw type-based Nearby Search (unlike a text search) surfaces minor,
  /// barely-documented points Google still tags 'tourist_attraction' or
  /// 'restaurant' — e.g. an unnamed arch or gate with no photo and no real
  /// review history. Keeping only entries with at least one photo and a
  /// handful of ratings filters those out, so "Nearby You"/"Nearby
  /// Restaurants" only ever show places a traveler would actually recognize.
  List<Place> _recognizable(List<Place> places) {
    return places
        .where((p) => p.photoNames.isNotEmpty && (p.userRatingCount ?? 0) >= 10)
        .toList();
  }

  Future<void> _refreshNearby() async {
    // Re-read fresh each time (not cached in state) so flipping the
    // Settings toggle takes effect the next time Home refreshes, even
    // though that's a different screen instance in the same nav shell.
    final featureEnabled = await _preferences.getLocationFeatureEnabled();
    if (!mounted) return;
    if (!featureEnabled) {
      setState(() {
        _locationFeatureEnabled = false;
        _nearby = [];
        _nearbyRestaurants = [];
      });
      return;
    }

    final result = await _locationService.resolveCurrentPosition();
    if (!mounted) return;
    setState(() => _nearbyStatus = result.status);
    if (!result.isGranted) {
      setState(() {
        _locationFeatureEnabled = true;
        _nearby = [];
        _nearbyRestaurants = [];
      });
      return;
    }

    final position = result.position!;
    try {
      // Live Places already ranks/limits to genuinely nearby results on its
      // own, so both carousels are a single direct nearby search each — no
      // progressive radius-widening needed.
      final nearbyFuture = _places.searchNearby(
        latitude: position.latitude,
        longitude: position.longitude,
        includedTypes: PlaceCategory.attractions,
        radiusMeters: 5000,
        maxResultCount: 20,
      );
      final nearbyRestaurantsFuture = _places.searchNearby(
        latitude: position.latitude,
        longitude: position.longitude,
        includedTypes: PlaceCategory.dining,
        radiusMeters: 5000,
        maxResultCount: 20,
      );
      final nearby = await nearbyFuture;
      final nearbyRestaurants = await nearbyRestaurantsFuture;
      if (!mounted) return;
      setState(() {
        _locationFeatureEnabled = true;
        _nearby = _recognizable(nearby);
        _nearbyRestaurants = _recognizable(nearbyRestaurants);
        _travelerLat = position.latitude;
        _travelerLng = position.longitude;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locationFeatureEnabled = true;
        _nearby = [];
        _nearbyRestaurants = [];
      });
    }
  }

  Future<void> _handleLocationAction() async {
    setState(() => _locationBusy = true);
    switch (_nearbyStatus) {
      case LocationAccessStatus.permissionDeniedForever:
        await _locationService.openAppSettings();
      case LocationAccessStatus.serviceDisabled:
        await _locationService.openLocationSettings();
      case LocationAccessStatus.permissionDenied:
      case LocationAccessStatus.unavailable:
      case LocationAccessStatus.granted:
        if (_lastData != null) await _refreshNearby();
    }
    if (mounted) setState(() => _locationBusy = false);
  }

  Future<void> _dismissLocationPrompt() async {
    setState(() => _locationPromptDismissed = true);
    await _preferences.setLocationPromptDismissed(true);
  }

  Future<void> _retry() async {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _future = future);
    if (_lastData != null) await _refreshNearby();
    try {
      await future;
    } catch (_) {
      // Surfaced by the FutureBuilder's error state below; RefreshIndicator
      // just needs this Future to complete either way.
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final uid = context.watch<AuthProvider>().firebaseUser?.uid;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    children: [
                      StreamBuilder<List<AppNotification>>(
                        stream: uid == null
                            ? const Stream.empty()
                            : _notificationRepository.streamForUser(uid),
                        builder: (context, snapshot) {
                          final hasUnread = (snapshot.data ?? const []).any(
                            (n) => !n.isRead,
                          );
                          return HomeHeader(
                            userName: user?.name.isNotEmpty == true
                                ? user!.name.split(' ').first
                                : 'Traveler',
                            avatarUrl: user?.photoUrl ?? '',
                            onAvatarTap: () => context.go(RoutePaths.profile),
                            onBellTap: () =>
                                context.push(RoutePaths.notifications),
                            hasUnreadNotifications: hasUnread,
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      SearchBarWidget(
                        readOnly: true,
                        onTap: () => context.push(RoutePaths.search),
                        onFilterTap: () =>
                            context.push(RoutePaths.search, extra: true),
                      ),
                    ],
                  ),
                ),
              ),
              FutureBuilder<_HomeData>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return SliverToBoxAdapter(child: _HomeLoadingSkeleton());
                  }
                  if (snapshot.hasError) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.huge),
                        child: EmptyStateWidget(
                          icon: Symbols.error_outline_rounded,
                          title: 'Couldn\'t load your feed',
                          message: AppException.from(snapshot.error!).message,
                          actionLabel: 'Retry',
                          onActionTap: _retry,
                        ),
                      ),
                    );
                  }
                  return _HomeContent(
                    data: snapshot.data!,
                    places: _places,
                    nearby: _nearby,
                    nearbyRestaurants: _nearbyRestaurants,
                    travelerLat: _travelerLat,
                    travelerLng: _travelerLng,
                    nearbyStatus: _nearbyStatus,
                    locationPromptDismissed:
                        _locationPromptDismissed || !_locationFeatureEnabled,
                    locationBusy: _locationBusy,
                    onLocationAction: _handleLocationAction,
                    onDismissLocationPrompt: _dismissLocationPrompt,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeLoadingSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        LoadingWidget.heroBanner(),
        const SizedBox(height: AppSpacing.xl),
        LoadingWidget.carousel(count: 6, itemWidth: 76),
        const SizedBox(height: AppSpacing.xl),
        LoadingWidget.carousel(),
        LoadingWidget.carousel(),
      ],
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.data,
    required this.places,
    required this.nearby,
    required this.nearbyRestaurants,
    required this.travelerLat,
    required this.travelerLng,
    required this.nearbyStatus,
    required this.locationPromptDismissed,
    required this.locationBusy,
    required this.onLocationAction,
    required this.onDismissLocationPrompt,
  });

  final _HomeData data;
  final PlacesService places;
  final List<Place> nearby;
  final List<Place> nearbyRestaurants;
  final double? travelerLat;
  final double? travelerLng;
  final LocationAccessStatus nearbyStatus;
  final bool locationPromptDismissed;
  final bool locationBusy;
  final VoidCallback onLocationAction;
  final VoidCallback onDismissLocationPrompt;

  String _photoUrl(Place p) =>
      p.photoNames.isNotEmpty ? places.photoUrl(p.photoNames.first) : '';

  @override
  Widget build(BuildContext context) {
    return SliverList.list(
      children: [
        HeroBanner(
          items: data.featuredPlaces
              .take(4)
              .map(
                (p) => HeroBannerItem(
                  imageUrl: _photoUrl(p),
                  title: p.name,
                  subtitle: p.address.isNotEmpty ? p.address : p.categoryLabel,
                  ctaLabel: 'Explore now',
                  onTap: () => showPlaceDetailsSheet(context, place: p, placesService: places),
                ),
              )
              .toList(),
        ).animate().fadeIn(duration: 420.ms),
        const SizedBox(height: AppSpacing.xl),
        SizedBox(
          height: 106,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            itemCount: mockCategories.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, i) {
              final category = mockCategories[i];
              return CategoryCard(
                category: category,
                onTap: () =>
                    context.go('${RoutePaths.explore}?category=${category.id}'),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        if (nearby.isNotEmpty)
          ..._carouselSection(
            context,
            title: 'Nearby You',
            subtitle: 'Closest attractions to your current location',
            onSeeAll: () => context.push(
              RoutePaths.nearbyPlaces,
              extra: {
                'title': 'Nearby You',
                'includedTypes': PlaceCategory.attractions,
                'latitude': travelerLat,
                'longitude': travelerLng,
              },
            ),
            itemCount: nearby.length,
            itemBuilder: (context, i) => PlaceCard(
              place: nearby[i],
              imageUrl: _photoUrl(nearby[i]),
              onTap: () => showPlaceDetailsSheet(context, place: nearby[i], placesService: places),
            ),
          )
        else if (!locationPromptDismissed &&
            nearbyStatus != LocationAccessStatus.granted) ...[
          LocationPromptCard(
            status: nearbyStatus,
            isBusy: locationBusy,
            onAction: onLocationAction,
            onDismiss: onDismissLocationPrompt,
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
        ..._carouselSection(
          context,
          title: 'Nearby Restaurants',
          subtitle: 'Good eats close to your current location',
          onSeeAll: () => context.push(
            RoutePaths.nearbyPlaces,
            extra: {
              'title': 'Nearby Restaurants',
              'includedTypes': PlaceCategory.dining,
              'latitude': travelerLat,
              'longitude': travelerLng,
            },
          ),
          itemCount: nearbyRestaurants.length,
          itemBuilder: (context, i) => PlaceCard(
            place: nearbyRestaurants[i],
            imageUrl: _photoUrl(nearbyRestaurants[i]),
            onTap: () => showPlaceDetailsSheet(context, place: nearbyRestaurants[i], placesService: places),
          ),
        ),
        ..._carouselSection(
          context,
          title: 'Featured Destinations',
          subtitle: 'Real places to explore across the Philippines',
          onSeeAll: () => context.go(RoutePaths.explore),
          itemCount: data.featuredPlaces.length,
          itemBuilder: (context, i) => PlaceCard(
            place: data.featuredPlaces[i],
            imageUrl: _photoUrl(data.featuredPlaces[i]),
            onTap: () => showPlaceDetailsSheet(context, place: data.featuredPlaces[i], placesService: places),
          ),
        ),
        ..._carouselSection(
          context,
          title: 'Popular Restaurants',
          subtitle: 'Where locals and travelers both eat well',
          onSeeAll: () => context.go('${RoutePaths.explore}?category=food'),
          itemCount: data.popularRestaurants.length,
          itemBuilder: (context, i) => PlaceCard(
            place: data.popularRestaurants[i],
            imageUrl: _photoUrl(data.popularRestaurants[i]),
            onTap: () => showPlaceDetailsSheet(context, place: data.popularRestaurants[i], placesService: places),
          ),
        ),
        ..._carouselSection(
          context,
          title: 'Upcoming Festivals',
          subtitle: 'Plan your trip around the celebration',
          onSeeAll: () => context.push(RoutePaths.upcomingFestivals),
          itemCount: data.upcomingFestivals.length,
          itemBuilder: (context, i) => FestivalCard(
            festival: data.upcomingFestivals[i],
            onTap: () => context.push(
              RoutePaths.festivalDetails(data.upcomingFestivals[i].id),
            ),
          ),
        ),
        if (data.travelTips.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(
                title: 'Travel Tips',
                subtitle: 'Good to know before you go',
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                // Tall enough for icon + a 2-line title + a 3-line
                // description + padding, the card's actual worst-case
                // content height — 158 was too tight and clipped with a
                // debug overflow banner as soon as a tip's title wrapped.
                height: 196,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  itemCount: data.travelTips.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: AppSpacing.md),
                  itemBuilder: (context, i) =>
                      TravelTipCard(tip: data.travelTips[i]),
                ),
              ),
            ],
          ),
        // Taller than AppSpacing.huge alone — this tab also has the floating
        // AI Chat FAB (`_AiChatFab` in `MainShellScreen`) hovering above the
        // bottom nav bar, which the plain nav-bar clearance doesn't account
        // for, letting the last row sit right behind it.
        const SizedBox(height: AppSpacing.huge + AppSpacing.xxxl),
      ],
    );
  }

  List<Widget> _carouselSection(
    BuildContext context, {
    required String title,
    required String subtitle,
    required VoidCallback onSeeAll,
    required int itemCount,
    required Widget Function(BuildContext, int) itemBuilder,
  }) {
    if (itemCount == 0) return const [];
    return [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: title,
            subtitle: subtitle,
            actionLabel: 'See all',
            onActionTap: onSeeAll,
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 250,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              itemCount: itemCount,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
              itemBuilder: (context, i) =>
                  _CarouselItemEntrance(child: itemBuilder(context, i)),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    ];
  }
}

/// A short, self-contained fade + slide-in for carousel items. Deliberately
/// avoids flutter_animate here: chaining `.animate()` onto lazily-built
/// `ListView.builder` items never lets its AnimationControllers finish
/// disposing between rebuilds, so `pumpAndSettle` (and, worse, real devices
/// under scroll) never stops scheduling frames.
class _CarouselItemEntrance extends StatefulWidget {
  const _CarouselItemEntrance({required this.child});

  final Widget child;

  @override
  State<_CarouselItemEntrance> createState() => _CarouselItemEntranceState();
}

class _CarouselItemEntranceState extends State<_CarouselItemEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _controller, curve: Curves.easeOut),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0.08, 0), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
            ),
        child: widget.child,
      ),
    );
  }
}
