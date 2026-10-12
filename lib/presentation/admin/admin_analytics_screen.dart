import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/breakpoints.dart';
import '../../core/utils/app_exception.dart';
import '../../core/widgets/states/loading_widget.dart';
import '../../data/repositories/admin_repository.dart';
import '../../data/repositories/analytics_snapshot_repository.dart';
import '../../data/repositories/business_repository.dart';
import '../../data/repositories/destination_repository.dart';
import '../../data/repositories/festival_repository.dart';
import '../../data/repositories/itinerary_repository.dart';
import '../../data/repositories/province_repository.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../data/repositories/review_report_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../domain/models/admin_user.dart';
import '../../domain/models/analytics_snapshot.dart';
import '../../domain/models/destination.dart';
import '../../domain/models/province.dart';
import 'widgets/admin_page_header.dart';
import 'widgets/admin_sidebar_shell.dart';

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
  late final AnalyticsSnapshotRepository _analyticsSnapshotRepository =
      AnalyticsSnapshotRepository(firestore: widget.firestore);

  late final AdminRepository _adminRepository = AdminRepository();

  late Future<_DashboardStats> _future;

  // What the Traveler Growth chart covers: the most recent [_trendDays]
  // snapshots, unless a custom [_trendRange] has been picked. Every other
  // number on this screen is a live "right now" count either way.
  int _trendDays = 14;
  DateTimeRange? _trendRange;

  bool _exporting = false;

  // Narrows the dashboard down to the metrics whose name (or section)
  // matches — see [_searchResults]. Empty shows the full dashboard.
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  Future<_DashboardStats> _loadForProvince(
    String provinceId,
    String provinceName,
  ) async {
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
      provinceStatsCapped:
          destinations.length >= 500 ||
          restaurants.length >= 500 ||
          festivals.length >= 500,
    );
  }

  Future<_DashboardStats> _loadGlobal() async {
    final range = _trendRange;
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
      // Best-effort — a brand-new deployment with no snapshots yet (or a
      // transient read failure) should never break the rest of the
      // dashboard, just leave the trend chart section hidden.
      (range == null
              ? _analyticsSnapshotRepository.getRecent(days: _trendDays)
              : _analyticsSnapshotRepository.getRange(range.start, range.end))
          .catchError((_) => const <AnalyticsSnapshot>[]),
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
      trend: results[10] as List<AnalyticsSnapshot>,
      trendRange: range,
    );
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() {
      _future = future;
    });
    await future;
  }

  String get _rangeLabel {
    final range = _trendRange;
    if (range == null) return 'Last $_trendDays days';
    final format = DateFormat.yMMMd();
    return '${format.format(range.start)} - ${format.format(range.end)}';
  }

  void _setTrendDays(int days) {
    _trendDays = days;
    _trendRange = null;
    _refresh();
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: now,
      initialDateRange: _trendRange,
      helpText: 'Traveler growth range',
    );
    if (picked == null || !mounted) return;
    _trendRange = picked;
    _refresh();
  }

  /// Hands the numbers currently on screen over as a CSV — a download on
  /// the web portal, the share sheet on a phone.
  Future<void> _export(_DashboardStats stats) async {
    String cell(Object value) {
      final text = '$value';
      return text.contains(RegExp('[",\n]')) ? '"${text.replaceAll('"', '""')}"' : text;
    }

    final plus = stats.provinceStatsCapped ? '+' : '';
    final rows = <List<Object>>[
      ['Metric', 'Value'],
      ['Scope', stats.scopedProvinceName ?? 'Platform-wide'],
      ['Exported', DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())],
      if (!stats.isScoped) ...[
        ['Total Travelers', stats.travelerCount],
        ['Suspended Travelers', stats.suspendedTravelerCount],
        ['Provinces w/ Content', stats.provinceWithContentCount],
        ['Provinces', stats.provinceCount],
      ],
      ['Tourist Spots', '${stats.publishedDestinationCount}$plus'],
      ['Restaurants', '${stats.publishedRestaurantCount}$plus'],
      ['Festivals', '${stats.publishedFestivalCount}$plus'],
      if (!stats.isScoped) ...[
        ['Businesses Pending Review', stats.pendingBusinessCount],
        ['Businesses Approved', stats.approvedBusinessCount],
        ['Saved Trips', stats.savedTripCount],
        ['Pending Reports', stats.pendingReportCount],
      ],
      if (stats.trend.isNotEmpty) ...[
        [''],
        ['Date', 'Total Travelers'],
        for (final snap in stats.trend) [DateFormat('yyyy-MM-dd').format(snap.date), snap.travelerCount],
      ],
      if (stats.popularDestinations.isNotEmpty) ...[
        [''],
        ['Popular Destination', 'Province', 'Reviews'],
        for (final d in stats.popularDestinations) [d.name, d.provinceName, d.reviewCount],
      ],
    ];
    final csv = rows.map((row) => row.map(cell).join(',')).join('\n');
    final name = 'tripnest-analytics-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv';

    setState(() => _exporting = true);
    try {
      await Share.shareXFiles(
        [XFile.fromData(utf8.encode(csv), mimeType: 'text/csv', name: name)],
        fileNameOverrides: [name],
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppException.from(e).message)));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: adminPageHeader(
        context,
        title: 'Analytics',
        subtitle: 'Track platform performance and key metrics.',
        icon: Symbols.bar_chart_rounded,
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
              return LayoutBuilder(
                builder: (context, constraints) {
                  // Room for the four-across cards and side-by-side charts.
                  final wide = constraints.maxWidth >= 920;
                  final pad = wide ? AppSpacing.xxl : AppSpacing.lg;
                  return ListView(
                    padding: EdgeInsets.fromLTRB(
                      pad,
                      AppSpacing.md,
                      // Keeps the cards from stretching across an ultra-wide
                      // window.
                      math.max(pad, constraints.maxWidth - pad - 1280),
                      AppSpacing.huge,
                    ),
                    children: [
                      _searchField(),
                      const SizedBox(height: AppSpacing.lg),
                      if (_query.trim().isNotEmpty)
                        ..._searchResults(context, stats, wide)
                      else if (stats.isScoped)
                        ..._scopedSections(context, stats, wide)
                      else
                        ..._globalSections(context, stats, wide),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _searchField() {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _query = value),
          decoration: InputDecoration(
            hintText: 'Search metrics',
            prefixIcon: const Icon(Symbols.search_rounded),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear',
                    icon: const Icon(Symbols.close_rounded),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                  ),
          ),
        ),
      ),
    );
  }

  /// What the dashboard shows instead of its sections while [_query] is
  /// set: every stat card whose label or section name contains it, plus any
  /// matching popular destination (by name or province).
  List<Widget> _searchResults(BuildContext context, _DashboardStats stats, bool wide) {
    final theme = Theme.of(context);
    final query = _query.trim().toLowerCase();
    final horizontal = wide || !context.isCompact;
    final plus = stats.provinceStatsCapped ? '+' : '';
    bool matches(String section, String label) =>
        section.toLowerCase().contains(query) || label.toLowerCase().contains(query);

    // (section, icon, label, value, color) — the same cards the sections
    // above show, minus the ones an LGU's province-scoped dashboard hides.
    final metrics = <(String, IconData, String, String, Color)>[
      if (!stats.isScoped) ...[
        ('Travelers', Symbols.group_rounded, 'Total Travelers', '${stats.travelerCount}', AppColors.adminViolet),
        ('Travelers', Symbols.block_rounded, 'Suspended', '${stats.suspendedTravelerCount}', AppColors.error),
        (
          'Content Coverage',
          Symbols.public_rounded,
          'Provinces w/ Content',
          '${stats.provinceWithContentCount}/${stats.provinceCount}',
          AppColors.adminGreen,
        ),
      ],
      (
        'Content Coverage',
        Symbols.place_rounded,
        'Tourist Spots',
        '${stats.publishedDestinationCount}$plus',
        AppColors.adminBlue,
      ),
      (
        'Content Coverage',
        Symbols.restaurant_rounded,
        'Restaurants',
        '${stats.publishedRestaurantCount}$plus',
        AppColors.adminOrange,
      ),
      (
        'Content Coverage',
        Symbols.celebration_rounded,
        'Festivals',
        '${stats.publishedFestivalCount}$plus',
        AppColors.adminPink,
      ),
      if (!stats.isScoped) ...[
        (
          'Businesses',
          Symbols.hourglass_top_rounded,
          'Businesses Pending Review',
          '${stats.pendingBusinessCount}',
          AppColors.adminOrange,
        ),
        (
          'Businesses',
          Symbols.storefront_rounded,
          'Businesses Approved',
          '${stats.approvedBusinessCount}',
          AppColors.adminViolet,
        ),
        ('Engagement', Symbols.card_travel_rounded, 'Saved Trips', '${stats.savedTripCount}', AppColors.adminTeal),
        ('Engagement', Symbols.flag_rounded, 'Pending Reports', '${stats.pendingReportCount}', AppColors.adminPink),
      ],
    ];
    final cards = [
      for (final (section, icon, label, value, color) in metrics)
        if (matches(section, label))
          _StatCard(icon: icon, label: label, value: value, color: color, horizontal: horizontal),
    ];

    const popularTitle = 'Most Popular Destinations';
    final popular = popularTitle.toLowerCase().contains(query)
        ? stats.popularDestinations
        : stats.popularDestinations.where((d) => matches(d.name, d.provinceName)).toList();

    if (cards.isEmpty && popular.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
          child: Center(
            child: Text(
              'No metrics match "${_query.trim()}".',
              style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ];
    }
    return [
      if (cards.isNotEmpty) _CardGrid(columns: wide ? 4 : 2, children: cards),
      ..._popularSection(stats, destinations: popular),
    ];
  }

  /// A section title with the Refresh / Export actions (and, for the
  /// platform-wide dashboard, the trend's date range) alongside it — dropping
  /// under the title when there isn't room for both on one line.
  Widget _headerWithToolbar(Widget header, _DashboardStats stats) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.sm,
      children: [
        header,
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            if (!stats.isScoped)
              _RangeMenu(
                label: _rangeLabel,
                onSelected: (days) => days == 0 ? _pickCustomRange() : _setTrendDays(days),
              ),
            _ToolbarButton(icon: Symbols.refresh_rounded, label: 'Refresh', onPressed: _refresh),
            _ToolbarButton(
              icon: Symbols.download_rounded,
              label: 'Export',
              onPressed: _exporting ? null : () => _export(stats),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _globalSections(BuildContext context, _DashboardStats stats, bool wide) {
    final horizontal = wide || !context.isCompact;
    final showTrend = stats.trend.length >= 2 || stats.trendRange != null;
    final travelers = [
      _StatCard(
        icon: Symbols.group_rounded,
        label: 'Total Travelers',
        value: '${stats.travelerCount}',
        color: AppColors.adminViolet,
        horizontal: horizontal,
      ),
      _StatCard(
        icon: Symbols.block_rounded,
        label: 'Suspended',
        value: '${stats.suspendedTravelerCount}',
        color: stats.suspendedTravelerCount > 0 ? AppColors.error : AppColors.adminBlue,
        horizontal: horizontal,
      ),
    ];
    return [
      _headerWithToolbar(const _SectionHeader(icon: Symbols.group_rounded, label: 'Travelers'), stats),
      const SizedBox(height: AppSpacing.md),
      if (wide && showTrend)
        SizedBox(
          height: context.textScaledHeight(148, textLine: 70),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: travelers[0]),
              const SizedBox(width: AppSpacing.lg),
              Expanded(child: travelers[1]),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                flex: 2,
                child: _TrendChart(snapshots: stats.trend, range: stats.trendRange, inline: true),
              ),
            ],
          ),
        )
      else ...[
        _CardGrid(columns: 2, children: travelers),
        if (showTrend) ...[
          const SizedBox(height: AppSpacing.lg),
          _TrendChart(snapshots: stats.trend, range: stats.trendRange),
        ],
      ],
      const SizedBox(height: AppSpacing.xl),
      const _SectionHeader(icon: Symbols.description_rounded, label: 'Content Coverage'),
      const SizedBox(height: AppSpacing.md),
      _CardGrid(
        columns: wide ? 4 : 2,
        children: [
          _StatCard(
            icon: Symbols.public_rounded,
            label: 'Provinces w/ Content',
            value: '${stats.provinceWithContentCount}/${stats.provinceCount}',
            color: AppColors.adminGreen,
            horizontal: horizontal,
          ),
          _StatCard(
            icon: Symbols.place_rounded,
            label: 'Tourist Spots',
            value: '${stats.publishedDestinationCount}',
            color: AppColors.adminBlue,
            horizontal: horizontal,
          ),
          _StatCard(
            icon: Symbols.restaurant_rounded,
            label: 'Restaurants',
            value: '${stats.publishedRestaurantCount}',
            color: AppColors.adminOrange,
            horizontal: horizontal,
          ),
          _StatCard(
            icon: Symbols.celebration_rounded,
            label: 'Festivals',
            value: '${stats.publishedFestivalCount}',
            color: AppColors.adminPink,
            horizontal: horizontal,
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.lg),
      ..._contentCharts(stats, wide),
      const SizedBox(height: AppSpacing.xl),
      const _SectionHeader(icon: Symbols.storefront_rounded, label: 'Businesses'),
      const SizedBox(height: AppSpacing.md),
      _CardGrid(
        columns: 2,
        children: [
          _StatCard(
            icon: Symbols.hourglass_top_rounded,
            label: 'Pending Review',
            value: '${stats.pendingBusinessCount}',
            color: stats.pendingBusinessCount > 0 ? AppColors.adminOrange : AppColors.adminTeal,
            horizontal: horizontal,
          ),
          _StatCard(
            icon: Symbols.storefront_rounded,
            label: 'Approved',
            value: '${stats.approvedBusinessCount}',
            color: AppColors.adminViolet,
            horizontal: horizontal,
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.xl),
      const _SectionHeader(icon: Symbols.favorite_rounded, label: 'Engagement'),
      const SizedBox(height: AppSpacing.md),
      _CardGrid(
        columns: 2,
        children: [
          _StatCard(
            icon: Symbols.card_travel_rounded,
            label: 'Saved Trips',
            value: '${stats.savedTripCount}',
            color: AppColors.adminTeal,
            horizontal: horizontal,
          ),
          _StatCard(
            icon: Symbols.flag_rounded,
            label: 'Pending Reports',
            value: '${stats.pendingReportCount}',
            color: stats.pendingReportCount > 0 ? AppColors.adminOrange : AppColors.adminPink,
            horizontal: horizontal,
          ),
        ],
      ),
      ..._popularSection(stats),
    ];
  }

  List<Widget> _scopedSections(BuildContext context, _DashboardStats stats, bool wide) {
    final theme = Theme.of(context);
    final horizontal = wide || !context.isCompact;
    final plus = stats.provinceStatsCapped ? '+' : '';
    return [
      _headerWithToolbar(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              stats.scopedProvinceName!,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              'Content coverage for your province',
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
            ),
          ],
        ),
        stats,
      ),
      const SizedBox(height: AppSpacing.md),
      _CardGrid(
        columns: wide ? 3 : 2,
        children: [
          _StatCard(
            icon: Symbols.place_rounded,
            label: 'Tourist Spots',
            value: '${stats.publishedDestinationCount}$plus',
            color: AppColors.adminBlue,
            horizontal: horizontal,
          ),
          _StatCard(
            icon: Symbols.restaurant_rounded,
            label: 'Restaurants',
            value: '${stats.publishedRestaurantCount}$plus',
            color: AppColors.adminOrange,
            horizontal: horizontal,
          ),
          _StatCard(
            icon: Symbols.celebration_rounded,
            label: 'Festivals',
            value: '${stats.publishedFestivalCount}$plus',
            color: AppColors.adminPink,
            horizontal: horizontal,
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.lg),
      ..._contentCharts(stats, wide),
      ..._popularSection(stats),
    ];
  }

  /// The share of published content each type makes up, next to the same
  /// types as plain counts — side by side when there's room, else stacked.
  List<Widget> _contentCharts(_DashboardStats stats, bool wide) {
    final types = [
      _Slice('Tourist Spots', stats.publishedDestinationCount, AppColors.adminBlue),
      _Slice('Restaurants', stats.publishedRestaurantCount, AppColors.adminOrange),
      _Slice('Festivals', stats.publishedFestivalCount, AppColors.adminPink),
    ];
    final distribution = _DistributionChart(slices: types);
    final byType = _CoverageBarChart(
      slices: [
        // An LGU dashboard is one province, so there's no province bar.
        if (!stats.isScoped) _Slice('Provinces', stats.provinceWithContentCount, AppColors.adminGreen),
        ...types,
      ],
    );
    if (!wide) return [distribution, const SizedBox(height: AppSpacing.lg), byType];
    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: distribution),
          const SizedBox(width: AppSpacing.lg),
          Expanded(child: byType),
        ],
      ),
    ];
  }

  /// [destinations] narrows the list to a search's matches.
  List<Widget> _popularSection(_DashboardStats stats, {List<Destination>? destinations}) {
    final popular = destinations ?? stats.popularDestinations;
    if (popular.isEmpty) return const [];
    return [
      const SizedBox(height: AppSpacing.xl),
      const _SectionHeader(icon: Symbols.trending_up_rounded, label: 'Most Popular Destinations'),
      const SizedBox(height: AppSpacing.md),
      Builder(
        builder: (context) => DecoratedBox(
          decoration: _cardDecoration(context),
          child: Material(
            type: MaterialType.transparency,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
              child: Column(
                children: [
                  for (final d in popular)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Symbols.place_rounded),
                      title: Text(d.name),
                      subtitle: Text(d.provinceName),
                      trailing: Text('${d.reviewCount} reviews'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ];
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
    this.provinceStatsCapped = false,
    this.trend = const [],
    this.trendRange,
  });

  final int travelerCount;
  final int suspendedTravelerCount;
  final int publishedDestinationCount;
  final int publishedRestaurantCount;
  final int publishedFestivalCount;

  /// True once any of the three province-scoped counts above hit the 500
  /// query limit exactly — a coincidence at exactly 500 real listings is
  /// vanishingly unlikely, and this is only ever a hint to add a "+" to the
  /// displayed number, not a value anything else depends on. Without this,
  /// the stat just silently froze at 500 forever past that point, with
  /// nothing distinguishing "there are exactly 500" from "there are at
  /// least 500."
  final bool provinceStatsCapped;
  final int provinceCount;
  final int provinceWithContentCount;
  final int pendingBusinessCount;
  final int approvedBusinessCount;
  final int savedTripCount;
  final int pendingReportCount;
  final List<Destination> popularDestinations;

  /// Recent daily platform-wide snapshots for the trend chart — never
  /// populated for an 'lgu' account's province-scoped dashboard, matching
  /// [travelerCount]/etc.'s own admin-only visibility (see
  /// `snapshotDailyAnalytics`'s doc comment on why those numbers are
  /// platform-wide, not province-scoped).
  final List<AnalyticsSnapshot> trend;

  /// The custom date range [trend] was loaded for, or null when it's simply
  /// the most recent snapshots.
  final DateTimeRange? trendRange;

  /// Non-null only for an 'lgu' account's province-scoped dashboard — the
  /// UI uses this to know whether to show the Travelers/Businesses/Pending
  /// Reports sections at all (never meaningful for a single-province view).
  final String? scopedProvinceName;

  bool get isScoped => scopedProvinceName != null;
}

/// The soft, violet-tinted lift every card here sits on, matching the
/// overview's. A dark surface swallows that shadow, so there it's an outline.
BoxDecoration _cardDecoration(BuildContext context) {
  final theme = Theme.of(context);
  final dark = theme.brightness == Brightness.dark;
  return BoxDecoration(
    color: theme.colorScheme.surface,
    borderRadius: BorderRadius.circular(AppRadius.lg),
    border: dark ? Border.all(color: theme.dividerColor) : null,
    boxShadow: dark
        ? null
        : [
            BoxShadow(
              color: AppColors.adminViolet.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 24, color: theme.colorScheme.onSurface),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            label,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

ButtonStyle _toolbarStyle(BuildContext context) {
  final theme = Theme.of(context);
  return OutlinedButton.styleFrom(
    backgroundColor: theme.colorScheme.surface,
    foregroundColor: theme.colorScheme.onSurface,
    side: BorderSide(color: theme.dividerColor),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
    minimumSize: const Size(0, 44),
    textStyle: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
  );
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({required this.icon, required this.label, required this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: _toolbarStyle(context),
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
    );
  }
}

/// The Traveler Growth chart's window: a few "last N days" presets, or a
/// custom range (reported to [onSelected] as 0).
class _RangeMenu extends StatelessWidget {
  const _RangeMenu({required this.label, required this.onSelected});

  final String label;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopupMenuButton<int>(
      tooltip: 'Traveler growth range',
      position: PopupMenuPosition.under,
      onSelected: onSelected,
      itemBuilder: (context) => const [
        PopupMenuItem(value: 14, child: Text('Last 14 days')),
        PopupMenuItem(value: 30, child: Text('Last 30 days')),
        PopupMenuItem(value: 90, child: Text('Last 90 days')),
        PopupMenuDivider(),
        PopupMenuItem(value: 0, child: Text('Custom range…')),
      ],
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Symbols.calendar_today_rounded, size: 20),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            const Icon(Symbols.expand_more_rounded, size: 20),
          ],
        ),
      ),
    );
  }
}

/// Lays [children] out [columns] across, every card in a row as tall as
/// that row's tallest.
class _CardGrid extends StatelessWidget {
  const _CardGrid({required this.columns, required this.children});

  final int columns;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final gap = context.isCompact ? AppSpacing.sm : AppSpacing.lg;
    return Column(
      children: [
        for (var i = 0; i < children.length; i += columns) ...[
          if (i > 0) SizedBox(height: gap),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var j = i; j < i + columns; j++) ...[
                  if (j > i) SizedBox(width: gap),
                  Expanded(child: j < children.length ? children[j] : const SizedBox.shrink()),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.horizontal = true,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  /// Icon beside the number, as on the desktop mock-up; a phone-width card
  /// stacks them instead, since there isn't room for both across.
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = horizontal ? 56.0 : 44.0;
    final bubble = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Icon(icon, color: color, size: size * 0.48),
    );
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
    return Container(
      padding: EdgeInsets.all(horizontal ? AppSpacing.lg : AppSpacing.md),
      decoration: _cardDecoration(context),
      child: horizontal
          ? Row(
              children: [
                bubble,
                const SizedBox(width: AppSpacing.md),
                Expanded(child: text),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [bubble, const SizedBox(height: AppSpacing.sm), text],
            ),
    );
  }
}

class _ChartTitle extends StatelessWidget {
  const _ChartTitle({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: adminVioletOf(context)),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// New travelers per day across [snapshots] (see
/// `AnalyticsSnapshotRepository.getRecent`) — the one thing a single
/// current-count stat card can never show: whether the platform is
/// actually growing, or has been flat for weeks. Bars of each day's
/// sign-ups rather than a line of the running total, which barely moves
/// from one day to the next and reads as flat even while it's growing.
class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.snapshots, this.range, this.inline = false});

  final List<AnalyticsSnapshot> snapshots;

  /// The custom range [snapshots] were loaded for, if one was picked.
  final DateTimeRange? range;

  /// Sitting in the row of traveler stat cards: fills that row's height
  /// instead of setting its own, with the caption up beside the title.
  final bool inline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final violet = adminVioletOf(context);
    const title = _ChartTitle(icon: Symbols.bar_chart_rounded, label: 'Traveler Growth');
    // Each day's sign-ups, from one snapshot's total to the next — the
    // first snapshot has nothing before it to compare against. A total that
    // dropped (deleted accounts) counts as no new sign-ups, not negative.
    final newPerDay = [
      for (var i = 1; i < snapshots.length; i++)
        math.max(0, snapshots[i].travelerCount - snapshots[i - 1].travelerCount),
    ];
    final totalNew = newPerDay.fold<int>(0, (total, n) => total + n);
    final caption = Text(
      range == null
          ? '+$totalNew new travelers, last ${snapshots.length} days'
          : '+$totalNew new travelers, ${DateFormat.MMMd().format(range!.start)} – ${DateFormat.yMMMd().format(range!.end)}',
      style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    final Widget chart;
    if (snapshots.length < 2) {
      // Only reachable with a custom range — the default view hides the
      // chart entirely until there are two days to draw a line between.
      chart = Center(
        child: Text(
          'No daily snapshots in this range yet.',
          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
      );
    } else {
      final maxNew = newPerDay.fold<int>(0, math.max);
      // Just the first, middle and last day — every bar's own date is in
      // its tooltip, and labelling all of them would collide.
      final labelled = {0, newPerDay.length ~/ 2, newPerDay.length - 1};
      chart = LayoutBuilder(
        builder: (context, constraints) => BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            minY: 0,
            // A stretch with no sign-ups at all would otherwise
            // divide-by-zero this into a degenerate 0-to-0 range.
            maxY: maxNew <= 0 ? 1 : maxNew * 1.2,
            gridData: const FlGridData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              leftTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 20,
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (!labelled.contains(i)) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        DateFormat.MMMd().format(snapshots[i + 1].date),
                        style: theme.textTheme.labelSmall?.copyWith(color: AppColors.textTertiary),
                      ),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(
              show: true,
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                // Kept inside the chart, so it never covers the card's own
                // title and caption above it.
                fitInsideVertically: true,
                fitInsideHorizontally: true,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final snap = snapshots[groupIndex + 1];
                  return BarTooltipItem(
                    '${DateFormat.MMMd().format(snap.date)}\n+${newPerDay[groupIndex]} new · ${snap.travelerCount} total',
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                  );
                },
              ),
            ),
            barGroups: [
              for (var i = 0; i < newPerDay.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: newPerDay[i].toDouble(),
                      color: violet,
                      // Wide for a couple of weeks, thinning out so a
                      // 90-day range still fits.
                      width: (constraints.maxWidth / newPerDay.length * 0.6).clamp(2.0, 18.0),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      // A faint full-height track, so a day with no
                      // sign-ups still reads as a day rather than a gap.
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: maxNew <= 0 ? 1 : maxNew * 1.2,
                        color: violet.withValues(alpha: 0.08),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: inline
            ? [
                Row(
                  children: [
                    title,
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: Align(alignment: Alignment.centerRight, child: caption)),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Expanded(child: chart),
              ]
            : [
                title,
                const SizedBox(height: 2),
                caption,
                const SizedBox(height: AppSpacing.md),
                SizedBox(height: 140, child: chart),
              ],
      ),
    );
  }
}

/// One content type's count and the color it's drawn in on both charts.
class _Slice {
  const _Slice(this.label, this.count, this.color);

  final String label;
  final int count;
  final Color color;
}

class _Legend extends StatelessWidget {
  const _Legend({required this.slices, required this.valueOf});

  final List<_Slice> slices;
  final String Function(_Slice slice) valueOf;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final slice in slices)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: slice.color, shape: BoxShape.circle),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    slice.label,
                    style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  valueOf(slice),
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// How the published content splits across types.
class _DistributionChart extends StatelessWidget {
  const _DistributionChart({required this.slices});

  final List<_Slice> slices;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = slices.fold<int>(0, (running, s) => running + s.count);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ChartTitle(icon: Symbols.donut_small_rounded, label: 'Content Distribution'),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              SizedBox.square(
                dimension: 150,
                child: total == 0
                    ? Center(
                        child: Text(
                          'No published content yet',
                          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 18,
                          pieTouchData: PieTouchData(enabled: false),
                          sections: [
                            for (final slice in slices)
                              if (slice.count > 0)
                                PieChartSectionData(
                                  value: slice.count.toDouble(),
                                  color: slice.color,
                                  radius: 54,
                                  showTitle: false,
                                ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 240),
                  child: _Legend(
                    slices: slices,
                    valueOf: (s) => total == 0 ? '—' : '${(s.count * 100 / total).round()}%',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The same content types as plain counts, one bar each.
class _CoverageBarChart extends StatelessWidget {
  const _CoverageBarChart({required this.slices});

  final List<_Slice> slices;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxCount = slices.fold<int>(0, (max, s) => math.max(max, s.count));
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ChartTitle(icon: Symbols.bar_chart_rounded, label: 'Content Coverage by Type'),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 150,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      minY: 0,
                      maxY: maxCount <= 0 ? 1 : maxCount * 1.1,
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(
                        show: true,
                        border: Border(bottom: BorderSide(color: theme.dividerColor)),
                      ),
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                            '${slices[groupIndex].label}\n${slices[groupIndex].count}',
                            const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                          ),
                        ),
                      ),
                      barGroups: [
                        for (var i = 0; i < slices.length; i++)
                          BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: slices[i].count.toDouble(),
                                color: slices[i].color,
                                width: 26,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                flex: 2,
                child: _Legend(slices: slices, valueOf: (s) => '${s.count}'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
