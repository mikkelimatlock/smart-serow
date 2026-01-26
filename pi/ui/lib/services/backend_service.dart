import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Data from Arduino (voltage, rpm, engine temp, gear)
class ArduinoData {
  final double? voltage;
  final int? rpm;
  final int? engTemp;
  final int? gear; // 0 = neutral, 1-6 = gear

  ArduinoData({this.voltage, this.rpm, this.engTemp, this.gear});

  factory ArduinoData.fromJson(Map<String, dynamic> json) {
    return ArduinoData(
      voltage: (json['voltage'] as num?)?.toDouble(),
      rpm: (json['rpm'] as num?)?.toInt(),
      engTemp: (json['eng_temp'] as num?)?.toInt(),
      gear: (json['gear'] as num?)?.toInt(),
    );
  }
}

/// Data from GPS
class GpsData {
  final double? lat;
  final double? lon;
  final double? speed; // m/s
  final double? alt;
  final double? track;
  final int? mode; // 0=no fix, 2=2D, 3=3D

  GpsData({this.lat, this.lon, this.speed, this.alt, this.track, this.mode});

  factory GpsData.fromJson(Map<String, dynamic> json) {
    return GpsData(
      lat: (json['lat'] as num?)?.toDouble(),
      lon: (json['lon'] as num?)?.toDouble(),
      speed: (json['speed'] as num?)?.toDouble(),
      alt: (json['alt'] as num?)?.toDouble(),
      track: (json['track'] as num?)?.toDouble(),
      mode: (json['mode'] as num?)?.toInt(),
    );
  }
}

/// HTTP client for Flask backend - fire-and-forget async fetch, sync cache return
///
/// Follows the same pattern as PiIO: never blocks UI, always returns cached data.
class BackendService {
  BackendService._() {
    // Kick off initial fetches
    _refreshArduino();
    _refreshGps();
  }
  static final instance = BackendService._();

  static const _baseUrl = 'http://127.0.0.1:5000';
  static const _timeout = Duration(seconds: 2);

  // Caches
  ArduinoData? _arduinoCache;
  GpsData? _gpsCache;
  bool _connected = false;

  // In-progress flags (prevent duplicate requests)
  bool _arduinoFetchInProgress = false;
  bool _gpsFetchInProgress = false;

  /// Whether backend is reachable
  bool get isConnected => _connected;

  /// Get Arduino data (sync, returns cached value)
  ArduinoData? getArduinoData() {
    if (!_arduinoFetchInProgress) {
      _refreshArduino();
    }
    return _arduinoCache;
  }

  /// Get GPS data (sync, returns cached value)
  GpsData? getGpsData() {
    if (!_gpsFetchInProgress) {
      _refreshGps();
    }
    return _gpsCache;
  }

  /// Background fetch for Arduino data
  Future<void> _refreshArduino() async {
    if (_arduinoFetchInProgress) return;
    _arduinoFetchInProgress = true;

    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/arduino'))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        // Skip if backend returns error (no data yet) - keep cached value
        if (!json.containsKey('error')) {
          _arduinoCache = ArduinoData.fromJson(json);
        }
        _connected = true;
      }
      // Non-200: keep cached data, just mark disconnected
    } catch (e) {
      // Network error, timeout, etc - keep cached data for transient hiccups
      _connected = false;
    } finally {
      _arduinoFetchInProgress = false;
    }
  }

  /// Background fetch for GPS data
  Future<void> _refreshGps() async {
    if (_gpsFetchInProgress) return;
    _gpsFetchInProgress = true;

    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/gps'))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        // Skip if backend returns error (no data yet) - keep cached value
        if (!json.containsKey('error')) {
          _gpsCache = GpsData.fromJson(json);
        }
        _connected = true;
      }
      // Non-200: keep cached data, just mark disconnected
    } catch (e) {
      // Network error, timeout, etc - keep cached data for transient hiccups
      _connected = false;
    } finally {
      _gpsFetchInProgress = false;
    }
  }

  /// Force clear all caches
  void clearCache() {
    _arduinoCache = null;
    _gpsCache = null;
    _connected = false;
  }
}
