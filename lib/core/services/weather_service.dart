import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../domain/models/itinerary.dart';

/// Fetches a real multi-day forecast from Open-Meteo (free, no API key
/// required) for the AI Planner's "Weather Outlook" section. Best-effort:
/// any failure (no network, destination missing coordinates, bad response)
/// returns an empty list rather than throwing, since weather is a nice-to-
/// have addition to an itinerary, never a reason to fail generating one.
class WeatherService {
  WeatherService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<WeatherForecast>> getForecast({
    required double latitude,
    required double longitude,
    required int days,
  }) async {
    // Open-Meteo's free forecast only looks 16 days ahead; itineraries are
    // already capped at 14 days by the planner form, but clamp defensively.
    final forecastDays = days.clamp(1, 16);
    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$latitude&longitude=$longitude'
      '&daily=weathercode,temperature_2m_max,temperature_2m_min'
      '&timezone=auto&forecast_days=$forecastDays',
    );

    try {
      final response = await _client.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return const [];

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final daily = json['daily'] as Map<String, dynamic>?;
      if (daily == null) return const [];

      final dates = List<String>.from(daily['time'] as List? ?? const []);
      final codes = List<num>.from(daily['weathercode'] as List? ?? const []);
      final highs = List<num>.from(daily['temperature_2m_max'] as List? ?? const []);
      final lows = List<num>.from(daily['temperature_2m_min'] as List? ?? const []);
      if (dates.isEmpty || codes.length != dates.length || highs.length != dates.length || lows.length != dates.length) {
        return const [];
      }

      return List.generate(dates.length, (i) {
        final code = codes[i].toInt();
        return WeatherForecast(
          dayLabel: DateFormat.E().format(DateTime.parse(dates[i])),
          condition: _conditionFor(code),
          iconKey: _iconKeyFor(code),
          highTemp: highs[i].round(),
          lowTemp: lows[i].round(),
        );
      });
    } catch (_) {
      return const [];
    }
  }

  /// WMO weather-interpretation codes, as used by Open-Meteo.
  /// https://open-meteo.com/en/docs
  String _conditionFor(int code) {
    if (code == 0) return 'Sunny';
    if (code <= 2) return 'Partly Cloudy';
    if (code == 3) return 'Overcast';
    if (code == 45 || code == 48) return 'Foggy';
    if (code >= 51 && code <= 67) return 'Rainy';
    if (code >= 71 && code <= 77) return 'Snow';
    if (code >= 80 && code <= 82) return 'Showers';
    if (code >= 95) return 'Thunderstorm';
    return 'Cloudy';
  }

  String _iconKeyFor(int code) {
    if (code == 0) return 'wb_sunny';
    if (code <= 2) return 'cloud';
    if (code == 3) return 'wb_cloudy';
    if (code == 45 || code == 48) return 'foggy';
    if (code >= 51 && code <= 67) return 'rainy';
    if (code >= 71 && code <= 77) return 'wb_cloudy';
    if (code >= 80 && code <= 82) return 'rainy';
    if (code >= 95) return 'thunderstorm';
    return 'wb_cloudy';
  }

  void dispose() => _client.close();
}
