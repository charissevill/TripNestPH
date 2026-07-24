import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/routes/route_paths.dart';
import '../../core/services/local_preferences_service.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_exception.dart';
import '../../core/widgets/banners/hero_banner.dart';
import '../../core/widgets/cards/category_card.dart';
import '../../core/widgets/cards/destination_card.dart';
import '../../core/widgets/cards/festival_card.dart';
import '../../core/widgets/cards/restaurant_card.dart';
import '../../core/widgets/cards/travel_tip_card.dart';
import '../../core/widgets/inputs/search_bar_widget.dart';
import '../../core/widgets/layout/section_header.dart';
import '../../core/widgets/states/empty_state_widget.dart';
import '../../core/widgets/states/loading_widget.dart';
import '../../data/mock/mock_categories.dart';
import '../../data/repositories/destination_repository.dart';
import '../../data/repositories/festival_repository.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../core/services/location_service.dart';
import '../../data/repositories/travel_tip_repository.dart';
import '../../domain/models/app_notification.dart';
import '../../domain/models/destination.dart';
import '../../domain/models/festival.dart';
import '../../domain/models/restaurant.dart';
import '../../domain/models/travel_tip.dart';
import 'widgets/home_header.dart';
import 'widgets/location_prompt_card.dart';

class _HomeData {
  const _HomeData({
    required this.featured,
    required this.popular,
    required this.hiddenGems,
    required this.popularRestaurants,
    required this.upcomingFestivals,
    required this.travelTips,
  });

  final List<Destination> featured;
  final List<Destination> popular;
  final List<Destination> hiddenGems;
  final List<Restaurant> popularRestaurants;
  final List<Festival> upcomingFestivals;
  final List<TravelTip> travelTips;
}

/// The primary landing tab: greeting, search entry point, hero carousel and
/// a series of horizontally-scrolling discovery sections — all loaded live
/// from Firestore.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final DestinationRepository _destinationRepository = DestinationRepository();
  final RestaurantRepository _restaurantRepository = RestaurantRepository();
  final FestivalRepository _festivalRepository = FestivalRepository();
  final TravelTipRepository _travelTipRepository = TravelTipRepository();
  final NotificationRepository _notificationRepository = NotificationRepository();
  final LocationService _locationService = LocationService();
  final LocalPreferencesService _preferences = LocalPreferencesService();

  late Future<_HomeData> _future;
  _HomeData? _lastData;
  List<Destination> _nearby = [];
  List<Restaurant> _nearbyRestaurants = [];
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
    if (state == AppLifecycleState.resumed && _nearbyStatus != LocationAccessStatus.granted && _lastData != null) {
      _refreshNearby();
    }
  }

  Future<_HomeData> _load() async {
    final results = await Future.wait([
      _destinationRepository.getFeatured(),
      _destinationRepository.getPopular(),
      _destinationRepository.getHiddenGems(),
      _restaurantRepository.getPopular(),
      _festivalRepository.getUpcoming(),
      _travelTipRepository.getAll(),
    ]);
    final data = _HomeData(
      featured: results[0] as List<Destination>,
      popular: results[1] as List<Destination>,
      hiddenGems: results[2] as List<Destination>,
      popularRestaurants: results[3] as List<Restaurant>,
      upcomingFestivals: results[4] as List<Festival>,
      travelTips: results[5] as List<TravelTip>,
    );
    _lastData = data;
    await _refreshNearby();
    return data;
  }

  List<T> _sortByDistance<T>(
    List<T> items,
    double travelerLat,
    double travelerLng, {
    required double Function(T) lat,
    required double Function(T) lng,
  }) {
    final sorted = [...items]
      ..sort((a, b) {
        final distanceA = _locationService.distanceKm(lat1: travelerLat, lng1: travelerLng, lat2: lat(a), lng2: lng(a));
        final distanceB = _locationService.distanceKm(lat1: travelerLat, lng1: travelerLng, lat2: lat(b), lng2: lng(b));
        return distanceA.compareTo(distanceB);
      });
    return sorted.take(8).toList();
  }

  /// Progressively widening search radii for "Nearby You" — starts tight so
  /// genuinely close results win, but widens if the live catalog is too
  /// sparse near the traveler to fill the carousel. Content is concentrated
  /// around specific destinations nationwide rather than spread evenly, so
  /// a fixed small radius could come up empty even when the database has
  /// plenty to show a bit farther out.
  static const List<double> _nearbyRadiusStepsKm = [50, 200, 800, 3000];

  /// Searches the full published catalog (not a pre-loaded candidate list)
  /// at increasing radii until enough results are found nearby, then sorts
  /// that batch by real distance.
  Future<List<T>> _fetchNearbyWithFallback<T>(
    Future<List<T>> Function(double radiusKm) fetchLatitudeBand,
    double travelerLat,
    double travelerLng, {
    required double Function(T) lat,
    required double Function(T) lng,
  }) async {
    for (final radiusKm in _nearbyRadiusStepsKm) {
      final band = await fetchLatitudeBand(radiusKm);
      final withinCircle = band
          .where((item) =>
              _locationService.distanceKm(lat1: travelerLat, lng1: travelerLng, lat2: lat(item), lng2: lng(item)) <=
              radiusKm)
          .toList();
      if (withinCircle.length >= 3 || radiusKm == _nearbyRadiusStepsKm.last) {
        return _sortByDistance(withinCircle, travelerLat, travelerLng, lat: lat, lng: lng);
      }
    }
    return [];
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
      final nearby = await _fetchNearbyWithFallback<Destination>(
        (radiusKm) => _destinationRepository.getNearbyLatitudeBand(latitude: position.latitude, radiusKm: radiusKm),
        position.latitude,
        position.longitude,
        lat: (d) => d.latitude!,
        lng: (d) => d.longitude!,
      );
      final nearbyRestaurants = await _fetchNearbyWithFallback<Restaurant>(
        (radiusKm) => _restaurantRepository.getNearbyLatitudeBand(latitude: position.latitude, radiusKm: radiusKm),
        position.latitude,
        position.longitude,
        lat: (r) => r.latitude!,
        lng: (r) => r.longitude!,
      );
      if (!mounted) return;
      setState(() {
        _locationFeatureEnabled = true;
        _nearby = nearby;
        _nearbyRestaurants = nearbyRestaurants;
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

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final uid = context.watch<AuthProvider>().firebaseUser?.uid;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    StreamBuilder<List<AppNotification>>(
                      stream: uid == null ? const Stream.empty() : _notificationRepository.streamForUser(uid),
                      builder: (context, snapshot) {
                        final hasUnread = (snapshot.data ?? const []).any((n) => !n.isRead);
                        return HomeHeader(
                          userName: user?.name.isNotEmpty == true ? user!.name.split(' ').first : 'Traveler',
                          avatarUrl: user?.photoUrl ?? '',
                          onAvatarTap: () => context.go(RoutePaths.profile),
                          onBellTap: () => context.push(RoutePaths.notifications),
                          hasUnreadNotifications: hasUnread,
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SearchBarWidget(
                      readOnly: true,
                      onTap: () => context.push(RoutePaths.search),
                      onFilterTap: () => context.push(RoutePaths.search, extra: true),
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
                  nearby: _nearby,
                  nearbyRestaurants: _nearbyRestaurants,
                  nearbyStatus: _nearbyStatus,
                  locationPromptDismissed: _locationPromptDismissed || !_locationFeatureEnabled,
                  locationBusy: _locationBusy,
                  onLocationAction: _handleLocationAction,
                  onDismissLocationPrompt: _dismissLocationPrompt,
                );
              },
            ),
          ],
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
    required this.nearby,
    required this.nearbyRestaurants,
    required this.nearbyStatus,
    required this.locationPromptDismissed,
    required this.locationBusy,
    required this.onLocationAction,
    required this.onDismissLocationPrompt,
  });

  final _HomeData data;
  final List<Destination> nearby;
  final List<Restaurant> nearbyRestaurants;
  final LocationAccessStatus nearbyStatus;
  final bool locationPromptDismissed;
  final bool locationBusy;
  final VoidCallback onLocationAction;
  final VoidCallback onDismissLocationPrompt;

  @override
  Widget build(BuildContext context) {
    return SliverList.list(
      children: [
        HeroBanner(
          items: data.featured
              .take(4)
              .map(
                (d) => HeroBannerItem(
                  imageUrl: d.heroImageUrl,
                  title: d.name,
                  subtitle: '${d.provinceName} · ★ ${d.rating}',
                  ctaLabel: 'Explore now',
                  onTap: () => context.push(RoutePaths.destinationDetails(d.id)),
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
                onTap: () => context.go('${RoutePaths.explore}?category=${category.id}'),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        if (nearby.isNotEmpty)
          ..._carouselSection(
            context,
            title: 'Nearby You',
            subtitle: 'Closest destinations to your current location',
            onSeeAll: () => context.go(RoutePaths.explore),
            itemCount: nearby.length,
            itemBuilder: (context, i) => DestinationCard(
              destination: nearby[i],
              onTap: () => context.push(RoutePaths.destinationDetails(nearby[i].id)),
            ),
          )
        else if (!locationPromptDismissed && nearbyStatus != LocationAccessStatus.granted) ...[
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
          onSeeAll: () => context.go(RoutePaths.explore),
          itemCount: nearbyRestaurants.length,
          itemBuilder: (context, i) => RestaurantCard(
            restaurant: nearbyRestaurants[i],
            onTap: () => context.push(RoutePaths.restaurantDetails(nearbyRestaurants[i].id)),
          ),
        ),
        ..._carouselSection(
          context,
          title: 'Featured Destinations',
          subtitle: 'Editor\'s picks for this season',
          onSeeAll: () => context.go(RoutePaths.explore),
          itemCount: data.featured.length,
          itemBuilder: (context, i) => DestinationCard(
            destination: data.featured[i],
            onTap: () => context.push(RoutePaths.destinationDetails(data.featured[i].id)),
          ),
        ),
        ..._carouselSection(
          context,
          title: 'Popular Tourist Spots',
          subtitle: 'Loved by thousands of travelers',
          onSeeAll: () => context.go(RoutePaths.explore),
          itemCount: data.popular.length,
          itemBuilder: (context, i) => DestinationCard(
            destination: data.popular[i],
            onTap: () => context.push(RoutePaths.destinationDetails(data.popular[i].id)),
          ),
        ),
        ..._carouselSection(
          context,
          title: 'Hidden Gems',
          subtitle: 'Off the beaten path, worth the detour',
          onSeeAll: () => context.go(RoutePaths.explore),
          itemCount: data.hiddenGems.length,
          itemBuilder: (context, i) => DestinationCard(
            destination: data.hiddenGems[i],
            onTap: () => context.push(RoutePaths.destinationDetails(data.hiddenGems[i].id)),
          ),
        ),
        ..._carouselSection(
          context,
          title: 'Popular Restaurants',
          subtitle: 'Where locals and travelers both eat well',
          onSeeAll: () => context.go(RoutePaths.explore),
          itemCount: data.popularRestaurants.length,
          itemBuilder: (context, i) => RestaurantCard(
            restaurant: data.popularRestaurants[i],
            onTap: () => context.push(RoutePaths.restaurantDetails(data.popularRestaurants[i].id)),
          ),
        ),
        ..._carouselSection(
          context,
          title: 'Upcoming Festivals',
          subtitle: 'Plan your trip around the celebration',
          onSeeAll: () => context.go(RoutePaths.explore),
          itemCount: data.upcomingFestivals.length,
          itemBuilder: (context, i) => FestivalCard(
            festival: data.upcomingFestivals[i],
            onTap: () => context.push(RoutePaths.festivalDetails(data.upcomingFestivals[i].id)),
          ),
        ),
        if (data.travelTips.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'Travel Tips', subtitle: 'Good to know before you go'),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                // Tall enough for icon + a 2-line title + a 3-line
                // description + padding, the card's actual worst-case
                // content height — 158 was too tight and clipped with a
                // debug overflow banner as soon as a tip's title wrapped.
                height: 196,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  itemCount: data.travelTips.length,
                  separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
                  itemBuilder: (context, i) => TravelTipCard(tip: data.travelTips[i]),
                ),
              ),
            ],
          ),
        const SizedBox(height: AppSpacing.huge),
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
          SectionHeader(title: title, subtitle: subtitle, actionLabel: 'See all', onActionTap: onSeeAll),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 250,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              itemCount: itemCount,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
              itemBuilder: (context, i) => _CarouselItemEntrance(child: itemBuilder(context, i)),
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

class _CarouselItemEntranceState extends State<_CarouselItemEntrance> with SingleTickerProviderStateMixin {
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
            .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic)),
        child: widget.child,
      ),
    );
  }
}
