/// A single live "right now" reading for one place — distinct from
/// [WeatherForecast] (a multi-day outlook), used by [CurrentWeatherCard] on
/// a destination's details page.
class CurrentWeather {
  const CurrentWeather({
    required this.temperature,
    required this.condition,
    required this.humidity,
    required this.iconKey,
  });

  final double temperature;
  final String condition;
  final int humidity;
  final String iconKey;
}
