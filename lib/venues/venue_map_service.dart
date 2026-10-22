import 'dart:convert';

import 'package:diacritic/diacritic.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';

/// Platform geocoding is cached per address; GPS is requested only on user action.
class VenueMapService {
  VenueMapService({http.Client? client}) : _client = client ?? http.Client();
  static VenueMapService instance = VenueMapService();
  final http.Client _client;
  final _cache = <String, LatLng>{};
  final _labels = <String, String>{};
  final _approximate = <String>{};
  final _pending = <String, Future<LatLng?>>{};
  Future<void> _queue = Future.value();
  DateTime? _lastRequest;
  String? addressLabel(String address) => _labels[address];
  bool isApproximate(String address) => _approximate.contains(address);
  TileProvider createTileProvider() => NetworkTileProvider();

  Future<LatLng?> locateAddress(String address) {
    final cached = _cache[address];
    if (cached != null) return Future.value(cached);
    return _pending.putIfAbsent(
      address,
      () => Future<LatLng?>.sync(() => _resolve(address)).whenComplete(() {
        // Returning the removed future here would make it wait on itself.
        _pending.remove(address);
      }),
    );
  }

  Future<LatLng?> _resolve(String address) async {
    final query = removeDiacritics(
      address,
    ).replaceAll(RegExp(r'TP\.?\s*HCM', caseSensitive: false), 'Ho Chi Minh');
    try {
      var place = await _online(query);
      if (place == null) {
        final street = query
            .split(',')
            .first
            .trim()
            .replaceFirst(RegExp(r'^\d+[\w/\-]*\s+'), '');
        if (street != query && street.isNotEmpty) {
          final city = query.toLowerCase().contains('ho chi minh')
              ? 'Ho Chi Minh'
              : query.split(',').last.trim();
          place = await _online('$street, $city');
          if (place != null) _approximate.add(address);
        }
      }
      if (place != null) {
        final point = LatLng(
          double.parse(place['lat'] as String),
          double.parse(place['lon'] as String),
        );
        if (!point.latitude.isFinite ||
            !point.longitude.isFinite ||
            point.latitude.abs() > 90 ||
            point.longitude.abs() > 180) {
          return null;
        }
        if ((place['place_rank'] as num? ?? 0) < 28) {
          _approximate.add(address);
        }
        _labels[address] = place['display_name'] as String? ?? address;
        return _cache[address] = point;
      }
    } catch (_) {
      // The platform provider remains available if online lookup fails.
    }
    try {
      final results = await Geocoding()
          .locationFromAddress(address)
          .timeout(const Duration(seconds: 4));
      if (results.isEmpty) return null;
      final first = results.first;
      final point = LatLng(first.latitude, first.longitude);
      _cache[address] = point;
      return point;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _online(String query) {
    final result = _queue.then((_) async {
      final last = _lastRequest;
      if (last != null) {
        final wait =
            const Duration(milliseconds: 1100) -
            DateTime.now().difference(last);
        if (wait > Duration.zero) await Future<void>.delayed(wait);
      }
      _lastRequest = DateTime.now();
      final response = await _client
          .get(
            Uri.parse(
              const String.fromEnvironment(
                'GEOCODING_URL',
                defaultValue: 'https://nominatim.openstreetmap.org/search',
              ),
            ).replace(
              queryParameters: {
                'q': query,
                'format': 'jsonv2',
                'countrycodes': 'vn',
                'limit': '1',
                'accept-language': 'vi',
              },
            ),
            headers: {
              'User-Agent': 'NVHSportsDemo/1.0 (com.example.test_do_an)',
            },
          )
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! List || data.isEmpty) return null;
      return Map<String, dynamic>.from(data.first as Map);
    });
    // Serialize requests, including failures, to respect the public geocoder limit.
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<LatLng> currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const MapLocationFailure('Hãy bật GPS để xem vị trí của bạn.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const MapLocationFailure(
        'Quyền vị trí đã bị tắt. Bạn có thể bật trong cài đặt ứng dụng.',
        settings: true,
      );
    }
    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      throw const MapLocationFailure(
        'Chưa được cấp quyền vị trí. Bạn vẫn có thể xem bản đồ và tìm sân.',
      );
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 12),
      ),
    );
    return LatLng(position.latitude, position.longitude);
  }
}

class MapLocationFailure implements Exception {
  const MapLocationFailure(this.message, {this.settings = false});
  final String message;
  final bool settings;
}
