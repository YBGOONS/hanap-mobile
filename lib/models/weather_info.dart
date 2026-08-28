/// A single current-conditions reading for a job's location, fetched from
/// Open-Meteo. `weatherCode` follows the WMO code table Open-Meteo returns —
/// see `weatherLabel`/`weatherEmoji` in weather_service.dart for how it's
/// turned into something a user can read at a glance.
class WeatherInfo {
  final String placeName;
  final double temperatureC;
  final double precipitationMm;
  final int weatherCode;
  final bool isDay;

  const WeatherInfo({
    required this.placeName,
    required this.temperatureC,
    required this.precipitationMm,
    required this.weatherCode,
    required this.isDay,
  });
}
