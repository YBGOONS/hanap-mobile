import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/weather_info.dart';

/// Client for Open-Meteo (https://open-meteo.com) — a free, keyless weather
/// API. Used to show current conditions for a job's location on the Job
/// Details sheet, since a lot of HANAP's categories (construction, cleaning,
/// gardening, etc) are weather-sensitive: knowing it's likely to rain on the
/// scheduled day is genuinely useful to both the client and the worker.
///
/// Two plain HTTP GET calls, no API key required:
/// 1. Geocoding API — turns the job's free-text `location` string (e.g.
///    "Quezon City, Metro Manila") into latitude/longitude.
/// 2. Forecast API — current conditions for that coordinate.
class WeatherService {
  static const _geocodeUrl = 'https://geocoding-api.open-meteo.com/v1/search';
  static const _forecastUrl = 'https://api.open-meteo.com/v1/forecast';

  Future<WeatherInfo?> fetchForLocation(String location) async {
    final query = location.split(',').first.trim();
    if (query.isEmpty) return null;

    final geoUri = Uri.parse(_geocodeUrl).replace(queryParameters: {
      'name': query,
      'count': '1',
      'language': 'en',
      'format': 'json',
    });
    final geoRes = await http.get(geoUri);
    if (geoRes.statusCode != 200) return null;

    final geoBody = jsonDecode(geoRes.body) as Map<String, dynamic>;
    final results = geoBody['results'] as List?;
    if (results == null || results.isEmpty) return null;
    final place = results.first as Map<String, dynamic>;
    final lat = (place['latitude'] as num).toDouble();
    final lon = (place['longitude'] as num).toDouble();
    final placeName = place['name'] as String? ?? query;

    final forecastUri = Uri.parse(_forecastUrl).replace(queryParameters: {
      'latitude': '$lat',
      'longitude': '$lon',
      'current': 'temperature_2m,precipitation,weather_code,is_day',
      'timezone': 'auto',
    });
    final forecastRes = await http.get(forecastUri);
    if (forecastRes.statusCode != 200) return null;

    final forecastBody = jsonDecode(forecastRes.body) as Map<String, dynamic>;
    final current = forecastBody['current'] as Map<String, dynamic>?;
    if (current == null) return null;

    return WeatherInfo(
      placeName: placeName,
      temperatureC: (current['temperature_2m'] as num).toDouble(),
      precipitationMm: (current['precipitation'] as num?)?.toDouble() ?? 0,
      weatherCode: (current['weather_code'] as num).toInt(),
      isDay: (current['is_day'] as num) == 1,
    );
  }
}

/// WMO weather codes (used by Open-Meteo) collapsed into the handful of
/// buckets worth showing a user — see https://open-meteo.com/en/docs for
/// the full table.
String weatherEmoji(int code, {required bool isDay}) {
  if (code == 0) return isDay ? '☀️' : '🌙';
  if (code <= 2) return isDay ? '🌤️' : '☁️';
  if (code == 3) return '☁️';
  if (code == 45 || code == 48) return '🌫️';
  if (code >= 51 && code <= 67) return '🌦️';
  if (code >= 71 && code <= 77) return '🌨️';
  if (code >= 80 && code <= 82) return '🌧️';
  if (code >= 95) return '⛈️';
  return '🌡️';
}

String weatherLabel(int code) {
  if (code == 0) return 'Clear sky';
  if (code <= 2) return 'Partly cloudy';
  if (code == 3) return 'Overcast';
  if (code == 45 || code == 48) return 'Foggy';
  if (code >= 51 && code <= 57) return 'Drizzle';
  if (code >= 61 && code <= 67) return 'Rain';
  if (code >= 71 && code <= 77) return 'Snow';
  if (code >= 80 && code <= 82) return 'Rain showers';
  if (code >= 95) return 'Thunderstorm';
  return 'Unknown';
}
