import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../services/weather_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/icon_registry.dart';
import '../../../domain/models/current_weather.dart';

/// Live "right now" weather for a single destination — Location, Temperature,
/// Condition and Humidity, pulled from the free Open-Meteo API (see
/// [WeatherService.getCurrentWeather]). Shows its own loading/error state
/// and a manual refresh action rather than depending on the parent screen's
/// pull-to-refresh, since a stale forecast is common enough (slow network,
/// a momentary API hiccup) to deserve a visible, immediate retry.
class CurrentWeatherCard extends StatefulWidget {
  const CurrentWeatherCard({
    super.key,
    required this.locationLabel,
    required this.latitude,
    required this.longitude,
  });

  final String locationLabel;
  final double latitude;
  final double longitude;

  @override
  State<CurrentWeatherCard> createState() => _CurrentWeatherCardState();
}

class _CurrentWeatherCardState extends State<CurrentWeatherCard> {
  final WeatherService _weatherService = WeatherService();
  late Future<CurrentWeather> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<CurrentWeather> _load() {
    return _weatherService.getCurrentWeather(
      latitude: widget.latitude,
      longitude: widget.longitude,
    );
  }

  void _retry() => setState(() => _future = _load());

  @override
  void dispose() {
    _weatherService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.15)),
      ),
      child: FutureBuilder<CurrentWeather>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox(
              height: 56,
              child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
            );
          }
          if (snapshot.hasError) {
            return Row(
              children: [
                Icon(Symbols.cloud_off_rounded, color: theme.colorScheme.error, size: 22),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Couldn\'t load current weather.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                  ),
                ),
                TextButton(onPressed: _retry, child: const Text('Retry')),
              ],
            );
          }

          final weather = snapshot.data!;
          return Row(
            children: [
              Icon(IconRegistry.resolve(weather.iconKey), size: 36, color: theme.colorScheme.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.locationLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(color: AppColors.textSecondary),
                    ),
                    Text(
                      '${weather.temperature.round()}°C · ${weather.condition}',
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      'Humidity: ${weather.humidity}%',
                      style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _retry,
                icon: const Icon(Symbols.refresh_rounded, size: 20),
                tooltip: 'Refresh weather',
              ),
            ],
          );
        },
      ),
    );
  }
}
