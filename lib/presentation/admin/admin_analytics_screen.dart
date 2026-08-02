import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_exception.dart';
import '../../core/widgets/states/loading_widget.dart';
import '../../data/repositories/admin_repository.dart';
import '../../data/repositories/business_repository.dart';
import '../../data/repositories/destination_repository.dart';
import '../../data/repositories/festival_repository.dart';
import '../../data/repositories/itinerary_repository.dart';
import '../../data/repositories/province_repository.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../data/repositories/review_report_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../domain/models/admin_user.dart';
import '../../domain/models/destination.dart';
import '../../domain/models/province.dart';

/// Admin-only read-only stats view — the "dashboard" `firestore.rules`
/// already anticipated (its own comments cite "Most Saved Places" and
/// "Saved Trips" dashboard metrics as the reason several collections grant
/// admin read access) but that had no screen built for it until now. Every
/// number here is a real live query, never a cached/estimated figure.
class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key, this.firestore});

  // Test-only override — production call sites never pass this. Every
  // repository below is constructed from this same instance so a widget
  // test only needs to inject one `FakeFirebaseFirestore`, not eight.
  final FirebaseFirestore? firestore;

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  late final DestinationRepository _destinationRepository =
      DestinationRepository(firestore: widget.firestore);
  // `UserRepository`'s own default `destinationRepository` param would
  // otherwise eagerly construct an un-overridden `DestinationRepository()`
  // — its field initializer touches `FirebaseFirestore.instance`
  // synchronously, which throws under `flutter test` with no real app.
  late final UserRepository _userRepository = UserRepository(
    firestore: widget.firestore,
    destinationRepository: _destinationRepository,
  );
  late final RestaurantRepository _restaurantRepository = RestaurantRepository(
    firestore: widget.firestore,
  );
  late final FestivalRepository _festivalRepository = FestivalRepository(
    firestore: widget.firestore,
  );
  late final ProvinceRepository _provinceRepository = ProvinceRepository(
    firestore: widget.firestore,
  );
  late final BusinessRepository _businessRepository = BusinessRepository(
    firestore: widget.firestore,
  );
  late final ItineraryRepository _itineraryRepository = ItineraryRepository(
    firestore: widget.firestore,
  );
  late final ReviewReportRepository _reportRepository = ReviewReportRepository(
    firestore: widget.firestore,
  );

  late final AdminRepository _adminRepository = AdminRepository();

  late Future<_DashboardStats> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  /// An 'lgu' account only ever manages one province (see
  /// `AdminUser.provinceId`'s doc comment) — its dashboard shows that
  /// province's own content/engagement numbers instead of the platform-wide
  /// figures an 'admin' account sees, and skips sections (Travelers,
  /// Businesses, Pending Reports) that aren't an LGU concern at all.
  Future<_DashboardStats> _load() async {
    // Guarded rather than a bare context.read: this screen is also used in
    // widget tests with no AuthProvider above it (see widget.firestore's
    // own "test-only override" doc comment) — falling through to the
    // global dashboard there is correct, the same as any account this
    // lookup can't resolve to an 'lgu' role.
    String? uid;
    try {
      uid = context.read<AuthProvider>().firebaseUser?.uid;
    } catch (_) {
      // No AuthProvider in the widget tree.
    }
    final admin = uid == null ? null : await _adminRepository.getById(uid);
    if (admin?.role == AdminRole.lgu && admin?.provinceId != null) {
      return _loadForProvince(admin!.provinceId!, admin.provinceName ?? '');
    }
    return _loadGlobal();
  }

  Future<_DashboardStats> _loadForProvince(String provinceId, String provinceName) async {
    final results = await Future.wait([
      _provinceRepository.getById(provinceId),
      _destinationRepository.filter(provinceId: provinceId, limit: 500),
      _restaurantRepository.filter(provinceId: provinceId, limit: 500),
      _festivalRepository.filter(provinceId: provinceId, limit: 500),
    ]);

    final province = results[0] as Province?;
    final destinations = results[1] as List<Destination>;
    final restaurants = results[2] as List;
    final festivals = results[3] as List;
    final popular = [...destinations]
      ..sort((a, b) => b.reviewCount.compareTo(a.reviewCount));

    return _DashboardStats(
      scopedProvinceName: provinceName,
      travelerCount: 0,
      suspendedTravelerCount: 0,
      publishedDestinationCount: destinations.length,
      publishedRestaurantCount: restaurants.length,
      publishedFestivalCount: festivals.length,
      provinceCount: 1,
      provinceWithContentCount: (province?.hasContent ?? false) ? 1 : 0,
      pendingBusinessCount: 0,
      approvedBusinessCount: 0,
      savedTripCount: 0,
      pendingReportCount: 0,
      popularDestinations: popular.take(5).toList(),
    );
  }

  Future<_DashboardStats> _loadGlobal() async {
    final results = await Future.wait([
      _userRepository.countAll(),
      _userRepository.countByStatus('suspended'),
      _destinationRepository.countPublished(),
      _restaurantRepository.countPublished(),
      _festivalRepository.countPublished(),
      _provinceRepository.getAll(),
      _businessRepository.streamAllForAdmin().first,
      _itineraryRepository.countAll(),
      _reportRepository.streamAllForAdmin().first,
      _destinationRepository.getPopular(limit: 5),
    ]);

    final provinces = results[5] as List;
    final businesses = results[6] as List;
    final reports = results[8] as List;

    return _DashboardStats(
      travelerCount: results[0] as int,
      suspendedTravelerCount: results[1] as int,
      publishedDestinationCount: results[2] as int,
      publishedRestaurantCount: results[3] as int,
      publishedFestivalCount: results[4] as int,
      provinceCount: provinces.length,
      provinceWithContentCount: provinces
          .where((p) => p.hasContent == true)
          .length,
      pendingBusinessCount: businesses
          .where((b) => b.status == 'pending')
          .length,
      approvedBusinessCount: businesses
          .where((b) => b.status == 'approved')
          .length,
      savedTripCount: results[7] as int,
      pendingReportCount: reports.length,
      popularDestinations: results[9] as List<Destination>,
    );
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _future = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Analytics'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<_DashboardStats>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return LoadingWidget.block(height: 500);
              }
              if (snapshot.hasError) {
                return ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [Text(AppException.from(snapshot.error!).message)],
                );
              }
              final stats = snapshot.data!;
              return ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.huge,
                ),
                children: [
                  if (stats.isScoped) ...[
                    Text(
                      stats.scopedProvinceName!,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Content coverage for your province',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ] else ...[
                    Text(
                      'Travelers',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            icon: Symbols.group_rounded,
                            label: 'Total Travelers',
                            value: '${stats.travelerCount}',
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _StatCard(
                            icon: Symbols.block_rounded,
                            label: 'Suspended',
                            value: '${stats.suspendedTravelerCount}',
                            color: stats.suspendedTravelerCount > 0
                                ? AppColors.error
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'Content Coverage',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            icon: Symbols.public_rounded,
                            label: 'Provinces w/ Content',
                            value:
                                '${stats.provinceWithContentCount}/${stats.provinceCount}',
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _StatCard(
                            icon: Symbols.place_rounded,
                            label: 'Tourist Spots',
                            value: '${stats.publishedDestinationCount}',
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (stats.isScoped) ...[
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            icon: Symbols.place_rounded,
                            label: 'Tourist Spots',
                            value: '${stats.publishedDestinationCount}',
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _StatCard(
                            icon: Symbols.restaurant_rounded,
                            label: 'Restaurants',
                            value: '${stats.publishedRestaurantCount}',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _StatCard(
                      icon: Symbols.celebration_rounded,
                      label: 'Festivals',
                      value: '${stats.publishedFestivalCount}',
                    ),
                  ] else ...[
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            icon: Symbols.restaurant_rounded,
                            label: 'Restaurants',
                            value: '${stats.publishedRestaurantCount}',
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _StatCard(
                            icon: Symbols.celebration_rounded,
                            label: 'Festivals',
                            value: '${stats.publishedFestivalCount}',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'Businesses',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            icon: Symbols.hourglass_top_rounded,
                            label: 'Pending Review',
                            value: '${stats.pendingBusinessCount}',
                            color: stats.pendingBusinessCount > 0
                                ? AppColors.warning
                                : null,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _StatCard(
                            icon: Symbols.storefront_rounded,
                            label: 'Approved',
                            value: '${stats.approvedBusinessCount}',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'Engagement',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            icon: Symbols.card_travel_rounded,
                            label: 'Saved Trips',
                            value: '${stats.savedTripCount}',
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _StatCard(
                            icon: Symbols.flag_rounded,
                            label: 'Pending Reports',
                            value: '${stats.pendingReportCount}',
                            color: stats.pendingReportCount > 0
                                ? AppColors.warning
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (stats.popularDestinations.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'Most Popular Destinations',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ...stats.popularDestinations.map(
                      (d) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Symbols.place_rounded),
                        title: Text(d.name),
                        subtitle: Text(d.provinceName),
                        trailing: Text('${d.reviewCount} reviews'),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DashboardStats {
  const _DashboardStats({
    required this.travelerCount,
    required this.suspendedTravelerCount,
    required this.publishedDestinationCount,
    required this.publishedRestaurantCount,
    required this.publishedFestivalCount,
    required this.provinceCount,
    required this.provinceWithContentCount,
    required this.pendingBusinessCount,
    required this.approvedBusinessCount,
    required this.savedTripCount,
    required this.pendingReportCount,
    required this.popularDestinations,
    this.scopedProvinceName,
  });

  final int travelerCount;
  final int suspendedTravelerCount;
  final int publishedDestinationCount;
  final int publishedRestaurantCount;
  final int publishedFestivalCount;
  final int provinceCount;
  final int provinceWithContentCount;
  final int pendingBusinessCount;
  final int approvedBusinessCount;
  final int savedTripCount;
  final int pendingReportCount;
  final List<Destination> popularDestinations;

  /// Non-null only for an 'lgu' account's province-scoped dashboard — the
  /// UI uses this to know whether to show the Travelers/Businesses/Pending
  /// Reports sections at all (never meaningful for a single-province view).
  final String? scopedProvinceName;

  bool get isScoped => scopedProvinceName != null;
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = color ?? theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
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
          Icon(icon, color: accent, size: 22),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(color: accent),
          ),
          const SizedBox(height: 2),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
