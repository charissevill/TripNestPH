import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/routes/route_paths.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/cards/festival_card.dart';
import '../../core/widgets/states/empty_state_widget.dart';
import '../../core/widgets/states/loading_widget.dart';
import '../../data/repositories/festival_repository.dart';
import '../../domain/models/festival.dart';

/// Full list of upcoming festivals — reached via "See all" from Home's
/// "Upcoming Festivals" carousel, so that section always has somewhere to
/// point to that isn't Explore (a separate destination-picking screen, not
/// a festivals list).
class UpcomingFestivalsScreen extends StatefulWidget {
  const UpcomingFestivalsScreen({super.key, this.festivalRepository});

  /// Test-only override — production call sites never pass this.
  final FestivalRepository? festivalRepository;

  @override
  State<UpcomingFestivalsScreen> createState() =>
      _UpcomingFestivalsScreenState();
}

class _UpcomingFestivalsScreenState extends State<UpcomingFestivalsScreen> {
  late final FestivalRepository _repository =
      widget.festivalRepository ?? FestivalRepository();

  List<Festival>? _festivals;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final festivals = await _repository.getUpcoming(limit: 50);
      if (!mounted) return;
      setState(() {
        _festivals = festivals;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => context.pop(),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: const Padding(
                      padding: EdgeInsets.all(AppSpacing.xs),
                      child: Icon(Symbols.arrow_back_rounded),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Upcoming Festivals',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: RefreshIndicator(onRefresh: _load, child: _buildResults())),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_loading) return LoadingWidget.grid();
    if (_error != null) {
      return EmptyStateWidget(
        icon: Symbols.error_outline_rounded,
        title: 'Couldn\'t load festivals',
        message: 'Something went wrong reaching the festival catalog — pull to refresh or try again shortly.',
        actionLabel: 'Retry',
        onActionTap: _load,
      );
    }
    final festivals = _festivals ?? const [];
    if (festivals.isEmpty) {
      return const EmptyStateWidget(
        icon: Symbols.celebration_rounded,
        title: 'No upcoming festivals',
        message: 'Check back later for newly announced celebrations.',
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - AppSpacing.lg * 2 - AppSpacing.md) / 2;
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.huge,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.lg,
            mainAxisExtent: 150 + 92,
          ),
          itemCount: festivals.length,
          itemBuilder: (context, i) {
            final festival = festivals[i];
            return FestivalCard(
              festival: festival,
              width: cardWidth,
              onTap: () => context.push(RoutePaths.festivalDetails(festival.id)),
            );
          },
        );
      },
    );
  }
}
