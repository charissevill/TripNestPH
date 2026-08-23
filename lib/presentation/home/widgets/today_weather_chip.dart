import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/services/weather_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/icon_registry.dart';
import '../../../domain/models/current_weather.dart';

/// A glanceable "right now" weather line shown just under the Home
/// greeting — the one place weather is visible without any tap, unlike
/// `CurrentWeatherCard`'s fuller version on destination detail pages. Falls
/// back to Manila's coordinates when the traveler's own location isn't
/// resolved yet (permission still pending/denied), so the line never just
/// disappears — same reasoning as `LocationPromptCard`'s graceful handling
/// of denied location elsewhere on this screen.
class TodayWeatherChip extends StatefulWidget {
  const TodayWeatherChip({super.key, this.latitude, this.longitude});

  final double? latitude;
  final double? longitude;

  static const double manilaLat = 14.5995;
  static const double manilaLng = 120.9842;

  @override
  State<TodayWeatherChip> createState() => _TodayWeatherChipState();
}

class _TodayWeatherChipState extends State<TodayWeatherChip> {
  late Future<CurrentWeather> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant TodayWeatherChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Home resolves the traveler's location asynchronously after its first
    // frame — once real coordinates arrive, refetch instead of staying
    // pinned to the Manila fallback for the rest of the session.
    if (oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude) {
      setState(() {
        _future = _load();
      });
    }
  }

  Future<CurrentWeather> _load() async {
    final service = WeatherService();
    try {
      return await service.getCurrentWeather(
        latitude: widget.latitude ?? TodayWeatherChip.manilaLat,
        longitude: widget.longitude ?? TodayWeatherChip.manilaLng,
      );
    } finally {
      service.dispose();
    }
  }

  void _retry() {
    setState(() {
      _future = _load();
    });
  }

  /// A one-line nudge tied to today's actual condition/temperature, not a
  /// generic "have a nice trip" — condition values are the fixed set
  /// [WeatherService] maps WMO codes to (see its `_conditionFor`), so this
  /// switches on those exact strings rather than guessing at phrasing.
  String _tipFor(String condition, double temperature) {
    switch (condition) {
      case 'Rainy':
      case 'Showers':
        return 'Pack a light rain jacket — good day for indoor spots or a cozy café.';
      case 'Thunderstorm':
        return 'Storms around — best to keep outdoor plans flexible today.';
      case 'Foggy':
        return 'Low visibility out there — take it slow on mountain or coastal roads.';
      case 'Sunny':
        return temperature >= 32
            ? 'Hot and sunny — stay hydrated and seek shade midday.'
            : 'Clear skies — a great day for sightseeing or a hike.';
      case 'Snow':
        return "Unusually cold out — bundle up if you're heading out.";
      default:
        return temperature >= 32
            ? 'Warm and humid — good day to pace yourself outdoors.'
            : 'Mild weather — good for a walking tour.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<CurrentWeather>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  'Loading today\'s weather…',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          );
        }
        if (snapshot.hasError) {
          return InkWell(
            onTap: _retry,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Symbols.cloud_off_rounded,
                  size: 15,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    'Weather unavailable · Tap to retry',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final weather = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  IconRegistry.resolve(weather.iconKey),
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Today: ${weather.temperature.round()}°C · ${weather.condition}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Symbols.tips_and_updates_rounded,
                  size: 13,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _tipFor(weather.condition, weather.temperature),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
