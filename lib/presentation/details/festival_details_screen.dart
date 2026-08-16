import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/providers/favorites_provider.dart';
import '../../core/routes/route_paths.dart';
import '../../core/services/notification_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/maps_launcher.dart';
import '../../core/utils/reminder_picker.dart';
import '../../core/utils/share_text.dart';
import '../../core/widgets/buttons/animated_button.dart';
import '../../core/widgets/cards/destination_card.dart';
import '../../core/widgets/cards/tag_chip.dart';
import '../../core/widgets/details/details_gallery_app_bar.dart';
import '../../core/widgets/dialogs/emergency_access_sheet.dart';
import '../../core/widgets/dialogs/report_content_dialog.dart';
import '../../domain/models/content_report.dart';
import '../../core/widgets/details/info_stat_card.dart';
import '../../core/widgets/details/map_preview.dart';
import '../../core/widgets/details/review_section.dart';
import '../../core/widgets/indicators/rating_widget.dart';
import '../../core/widgets/layout/max_width_container.dart';
import '../../core/widgets/layout/section_header.dart';
import '../../core/widgets/states/empty_state_widget.dart';
import '../../core/widgets/states/loading_widget.dart';
import '../../data/repositories/destination_repository.dart';
import '../../data/repositories/festival_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../domain/models/destination.dart';
import '../../domain/models/festival.dart';
import '../../domain/models/review.dart';

/// Full detail view for a cultural festival: poster gallery, date/rating
/// facts, organizer, registration link and nearby destinations — loaded
/// live from Firestore.
class FestivalDetailsScreen extends StatefulWidget {
  const FestivalDetailsScreen({super.key, required this.festivalId});

  final String festivalId;

  @override
  State<FestivalDetailsScreen> createState() => _FestivalDetailsScreenState();
}

class _FestivalDetailsScreenState extends State<FestivalDetailsScreen> {
  final FestivalRepository _festivalRepository = FestivalRepository();
  final DestinationRepository _destinationRepository = DestinationRepository();
  final UserRepository _userRepository = UserRepository();

  late Future<_FestivalDetailsData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_FestivalDetailsData> _load() async {
    final uid = context.read<AuthProvider>().firebaseUser?.uid;

    final festival = await _festivalRepository.getById(widget.festivalId);
    if (festival == null) {
      throw const AppException('This festival is no longer available.');
    }
    final nearbyAttractions = await _destinationRepository.filter(
      provinceId: festival.provinceId,
      limit: 6,
    );

    if (uid != null) {
      unawaited(
        _userRepository.recordVisit(
          uid: uid,
          targetType: 'festival',
          targetId: festival.id,
        ),
      );
    }

    return _FestivalDetailsData(
      festival: festival,
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
        child: FutureBuilder<_FestivalDetailsData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return LoadingWidget.detailPage();
            }
            if (snapshot.hasError) {
              return SafeArea(
                child: EmptyStateWidget(
                  icon: Symbols.error_outline_rounded,
                  title: 'Couldn\'t load this festival',
                  message: AppException.from(snapshot.error!).message,
                  actionLabel: 'Go back',
                  onActionTap: () => context.pop(),
                ),
              );
            }
            return _FestivalDetailsBody(data: snapshot.data!);
          },
        ),
      ),
    );
  }
}

class _FestivalDetailsData {
  const _FestivalDetailsData({
    required this.festival,
    required this.nearbyAttractions,
  });

  final Festival festival;
  final List<Destination> nearbyAttractions;
}

class _FestivalDetailsBody extends StatelessWidget {
  const _FestivalDetailsBody({required this.data});

  final _FestivalDetailsData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final festival = data.festival;
    final saved = context.watch<FavoritesProvider>();
    final sidePadding = MaxWidthContainer.sidePadding(context, maxWidth: 900);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          DetailsGalleryAppBar(
            imageUrls: festival.galleryImageUrls,
            title: festival.name,
            isSaved: saved.isFestivalSaved(festival.id),
            onToggleSaved: () => saved.toggleFestival(festival.id),
            onShare: () => Share.share(ShareText.forFestival(festival)),
            onEmergency: () => showEmergencyAccessSheet(
              context,
              provinceId: festival.provinceId,
              provinceName: festival.provinceName,
            ),
            heroTag: 'festival-${festival.id}',
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
                            festival.name,
                            style: theme.textTheme.displayMedium,
                          ),
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: () => context.push(
                              RoutePaths.provinceDetails(festival.provinceId),
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
                                    festival.provinceName,
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
                      rating: festival.rating,
                      reviewCount: festival.reviewCount,
                      starSize: 20,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    InfoStatCard(
                      icon: Symbols.calendar_month_rounded,
                      label: 'Date',
                      value: festival.dateLabel,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    InfoStatCard(
                      icon: festival.isUpcoming
                          ? Symbols.event_available_rounded
                          : Symbols.event_repeat_rounded,
                      label: 'Status',
                      value: festival.isUpcoming ? 'Upcoming' : 'Annual',
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    InfoStatCard(
                      icon: Symbols.star_rounded,
                      label: 'Rating',
                      value: festival.rating.toStringAsFixed(1),
                    ),
                  ],
                ),
                if (festival.organizer.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      const Icon(
                        Symbols.groups_rounded,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Organized by ${festival.organizer}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.xxl),
                Text('Highlights', style: theme.textTheme.titleLarge),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: festival.highlights
                      .map(
                        (h) =>
                            TagChip(label: h, color: AppColors.secondaryDark),
                      )
                      .toList(),
                ),
                const SizedBox(height: AppSpacing.xxl),
                Text('About the Festival', style: theme.textTheme.titleLarge),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  festival.description,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                ),
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
                    onPressed: () => reportContent(context, targetId: festival.id, targetType: ContentTargetType.festival),
                    icon: const Icon(Symbols.flag_rounded, size: 15),
                    label: const Text('Report incorrect info'),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text('Location', style: theme.textTheme.titleLarge),
                const SizedBox(height: AppSpacing.sm),
                MapPreview(
                  latitude: festival.latitude,
                  longitude: festival.longitude,
                  label: festival.name,
                ),
                if (data.nearbyAttractions.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xxl),
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
                  targetId: festival.id,
                  targetType: ReviewTargetType.festival,
                  reviewCount: festival.reviewCount,
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
                  label: 'Set Reminder',
                  icon: Symbols.notifications_active_rounded,
                  filled: false,
                  onPressed: () => _setFestivalReminder(context, festival),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 2,
                child: AnimatedButton(
                  label: festival.registrationLink.isNotEmpty
                      ? 'Register Now'
                      : 'Plan a Trip Here',
                  icon: festival.registrationLink.isNotEmpty
                      ? Symbols.how_to_reg_rounded
                      : Symbols.auto_awesome_rounded,
                  onPressed: festival.registrationLink.isNotEmpty
                      ? () => MapsLauncher.openUrl(festival.registrationLink)
                      : () => context.go(RoutePaths.planner),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _setFestivalReminder(
  BuildContext context,
  Festival festival,
) async {
  final dateTime = await pickReminderDateTime(context);
  if (dateTime == null || !context.mounted) return;
  await NotificationService.instance.scheduleReminder(
    id: festival.id.hashCode,
    title: 'Festival Reminder',
    body: '${festival.name} is coming up — ${festival.dateLabel}.',
    dateTime: dateTime,
  );
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Reminder set for ${festival.name}.')),
    );
  }
}
