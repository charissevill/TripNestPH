import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/routes/back_navigation.dart';
import '../../core/routes/route_paths.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_exception.dart';
import '../../core/widgets/cards/destination_card.dart';
import '../../core/widgets/states/empty_state_widget.dart';
import '../../core/widgets/states/loading_widget.dart';
import '../../data/repositories/user_repository.dart';
import '../../domain/models/destination.dart';
import '../../core/theme/breakpoints.dart';
import '../../core/widgets/layout/max_width_container.dart';

const double _gridImageHeight = 140;
const double _gridCellExtent = _gridImageHeight + 92;

/// Every destination the traveler has opened, newest first — backed by the
/// `recently_viewed` subcollection ([UserRepository.recentlyViewedDestinations]).
class RecentlyViewedScreen extends StatefulWidget {
  const RecentlyViewedScreen({super.key});

  @override
  State<RecentlyViewedScreen> createState() => _RecentlyViewedScreenState();
}

class _RecentlyViewedScreenState extends State<RecentlyViewedScreen> {
  final UserRepository _userRepository = UserRepository();
  late Future<List<Destination>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Destination>> _load() {
    final uid = context.read<AuthProvider>().firebaseUser?.uid;
    if (uid == null) return Future.value(const []);
    return _userRepository.recentlyViewedDestinations(uid, limit: 50);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back_rounded),
          onPressed: () => context.popOrGo(RoutePaths.profile),
        ),
        title: const Text('Recently Viewed'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final future = _load();
          setState(() {
            _future = future;
          });
          try {
            await future;
          } catch (_) {
            // Surfaced by the FutureBuilder's error state below; RefreshIndicator
            // just needs this Future to complete either way.
          }
        },
        child: FutureBuilder<List<Destination>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return LoadingWidget.grid();
            }
            if (snapshot.hasError) {
              return ListView(
                children: [
                  EmptyStateWidget(
                    icon: Symbols.error_outline_rounded,
                    title: 'Couldn\'t load your history',
                    message: AppException.from(snapshot.error!).message,
                    actionLabel: 'Retry',
                    onActionTap: () => setState(() {
                      _future = _load();
                    }),
                  ),
                ],
              );
            }
            final destinations = snapshot.data ?? const [];
            if (destinations.isEmpty) {
              return ListView(
                children: const [
                  EmptyStateWidget(
                    icon: Symbols.history_rounded,
                    title: 'Nothing viewed yet',
                    message:
                        'Destinations you open will show up here so you can find your way back.',
                  ),
                ],
              );
            }
            return LayoutBuilder(
              builder: (context, constraints) {
                // Same column count / content width as Explore and Saved: 2 on a
                // phone, 3-4 with room for them, capped so cards don't stretch.
                final side = MaxWidthContainer.sidePadding(context, maxWidth: 1400);
                return GridView.builder(
                  padding: EdgeInsets.fromLTRB(side, AppSpacing.md, side, AppSpacing.huge),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: context.gridColumns,
                    crossAxisSpacing: AppSpacing.md,
                    mainAxisSpacing: AppSpacing.lg,
                    mainAxisExtent: _gridCellExtent,
                  ),
                  itemCount: destinations.length,
                  itemBuilder: (context, i) => DestinationCard(
                    destination: destinations[i],
                    width: double.infinity,
                    imageHeight: _gridImageHeight,
                    onTap: () => context.push(
                      RoutePaths.destinationDetails(destinations[i].id),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
