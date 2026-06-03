import 'package:http/http.dart' as http;

/// Fetches current weather from wttr.in (free, no API key).
/// Returns a simple weather code: clear, cloudy, rain, snow, fog.
class WeatherService {
  String? _lastCode;
  DateTime? _lastFetch;
  String _location = 'Suzhou'; // 苏州

  /// Set location (city name or lat,lon). Affects next fetch.
  void setLocation(String loc) => _location = loc;

  /// Returns a weather code, cached for 30 minutes.
  Future<String?> fetch() async {
    if (_lastFetch != null &&
        DateTime.now().difference(_lastFetch!) < const Duration(minutes: 30)) {
      return _lastCode;
    }
    try {
      final encoded = Uri.encodeComponent(_location);
      final uri = Uri.parse('https://wttr.in/$encoded?format=%C');
      final resp = await http.get(uri).timeout(const Duration(seconds: 5));
      if (resp.statusCode != 200) return null;
      final raw = resp.body.trim().toLowerCase();
      _lastCode = _classify(raw);
      _lastFetch = DateTime.now();
      return _lastCode;
    } catch (_) {
      return _lastCode; // Return stale on failure
    }
  }

  String _classify(String condition) {
    if (condition.contains('rain') || condition.contains('drizzle') || condition.contains('shower')) return 'rain';
    if (condition.contains('snow') || condition.contains('sleet') || condition.contains('ice')) return 'snow';
    if (condition.contains('fog') || condition.contains('mist') || condition.contains('haze')) return 'fog';
    if (condition.contains('cloud') || condition.contains('overcast')) return 'cloudy';
    return 'clear';
  }
}
