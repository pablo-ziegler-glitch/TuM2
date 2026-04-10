import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import '../../../../core/cache/zones_cache_service.dart';

/// Sugerencia de dirección del autocomplete de Places.
class PlaceSuggestion {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;

  const PlaceSuggestion({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });
}

/// Detalles de un lugar seleccionado.
class PlaceDetails {
  final String formattedAddress;
  final double lat;
  final double lng;

  const PlaceDetails({
    required this.formattedAddress,
    required this.lat,
    required this.lng,
  });
}

/// Resolución de zona a partir de lat/lng.
class ZoneResolution {
  final String zoneId;
  final String cityId;
  final String provinceId;

  const ZoneResolution({
    required this.zoneId,
    required this.cityId,
    required this.provinceId,
  });
}

/// Error específico de Places API (red o respuesta inválida).
class PlacesNetworkException implements Exception {
  final String message;
  const PlacesNetworkException(this.message);
  @override
  String toString() => 'PlacesNetworkException: $message';
}

/// Error cuando no se puede determinar la zona desde lat/lng.
class ZoneNotFoundException implements Exception {
  const ZoneNotFoundException();
  @override
  String toString() => 'ZoneNotFoundException: No se pudo identificar la zona.';
}

/// SL-04 — GooglePlacesService
///
/// Integración real con Google Places Autocomplete y Details APIs.
/// API key: `--dart-define=GOOGLE_PLACES_API_KEY=...` al compilar.
///
/// Métodos:
/// - getAddressSuggestions: autocompletado restringido a Argentina.
/// - getPlaceDetails: obtiene lat/lng y dirección formateada del placeId.
/// - resolveZone: dado lat/lng, busca la zona en Firestore por proximidad geográfica.
class GooglePlacesService {
  static const String _apiKey = String.fromEnvironment('GOOGLE_PLACES_API_KEY');

  static const String _autocompleteBaseUrl =
      'https://maps.googleapis.com/maps/api/place/autocomplete/json';
  static const String _detailsBaseUrl =
      'https://maps.googleapis.com/maps/api/place/details/json';
  static const Set<String> _inactiveZoneStatuses = <String>{
    'draft',
    'internal_test',
    'paused',
    'borrador',
    'pausado',
    'pausada',
  };
  final http.Client _httpClient;
  final ZonesCacheService _zonesCache;

  GooglePlacesService({
    http.Client? httpClient,
    FirebaseFirestore? firestore,
  })  : _httpClient = httpClient ?? http.Client(),
        _zonesCache = ZonesCacheService(
          firestore: firestore ?? FirebaseFirestore.instance,
        );

  /// Retorna sugerencias de dirección para el texto ingresado.
  /// Restringido a Argentina. Usa sessionToken para reducir costo de API.
  Future<List<PlaceSuggestion>> getAddressSuggestions(
    String query,
    String sessionToken,
  ) async {
    if (query.trim().isEmpty) return [];

    final uri = Uri.parse(_autocompleteBaseUrl).replace(queryParameters: {
      'input': query,
      'components': 'country:ar',
      'types': 'address',
      'language': 'es',
      'sessiontoken': sessionToken,
      'key': _apiKey,
    });

    try {
      final response = await _httpClient.get(uri).timeout(
            const Duration(seconds: 8),
            onTimeout: () => throw const PlacesNetworkException(
              'Timeout en Places Autocomplete',
            ),
          );

      if (response.statusCode != 200) {
        throw PlacesNetworkException('HTTP ${response.statusCode}');
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final status = body['status'] as String?;
      if (status == 'ZERO_RESULTS') return [];
      if (status != 'OK') {
        throw PlacesNetworkException('Places API status: $status');
      }

      final predictions = (body['predictions'] as List<dynamic>?) ?? [];
      return predictions.map((p) {
        final map = p as Map<String, dynamic>;
        final structured =
            map['structured_formatting'] as Map<String, dynamic>? ?? {};
        return PlaceSuggestion(
          placeId: map['place_id'] as String,
          description: map['description'] as String,
          mainText: structured['main_text'] as String? ??
              map['description'] as String,
          secondaryText: structured['secondary_text'] as String? ?? '',
        );
      }).toList();
    } on PlacesNetworkException {
      rethrow;
    } catch (e) {
      throw PlacesNetworkException(e.toString());
    }
  }

  /// Obtiene lat/lng y dirección formateada para el placeId seleccionado.
  Future<PlaceDetails> getPlaceDetails(
    String placeId,
    String sessionToken,
  ) async {
    final uri = Uri.parse(_detailsBaseUrl).replace(queryParameters: {
      'place_id': placeId,
      'fields': 'geometry,formatted_address',
      'language': 'es',
      'sessiontoken': sessionToken,
      'key': _apiKey,
    });

    try {
      final response = await _httpClient.get(uri).timeout(
            const Duration(seconds: 8),
            onTimeout: () =>
                throw const PlacesNetworkException('Timeout en Places Details'),
          );

      if (response.statusCode != 200) {
        throw PlacesNetworkException('HTTP ${response.statusCode}');
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final status = body['status'] as String?;
      if (status != 'OK') {
        throw PlacesNetworkException('Places Details API status: $status');
      }

      final result = body['result'] as Map<String, dynamic>;
      final geometry = result['geometry'] as Map<String, dynamic>;
      final location = geometry['location'] as Map<String, dynamic>;

      return PlaceDetails(
        formattedAddress: result['formatted_address'] as String,
        lat: (location['lat'] as num).toDouble(),
        lng: (location['lng'] as num).toDouble(),
      );
    } on PlacesNetworkException {
      rethrow;
    } catch (e) {
      throw PlacesNetworkException(e.toString());
    }
  }

  /// Dado lat/lng, busca la zona correspondiente en Firestore.
  /// La colección `zones` tiene campos: zoneId, cityId, provinceId, lat, lng, radiusKm.
  /// Retorna la zona más cercana dentro de su radio. Lanza [ZoneNotFoundException] si no hay.
  Future<ZoneResolution> resolveZone(double lat, double lng) async {
    ZoneResolution? best;
    double bestDistance = double.infinity;

    final zoneRecords = await _zonesCache.fetchZones(
      timeout: const Duration(seconds: 8),
    );
    for (final zone in zoneRecords) {
      final data = zone.data;
      final status = _readText(data, const ['status', 'estado'])?.toLowerCase();
      if (status != null && _inactiveZoneStatuses.contains(status)) {
        continue;
      }
      final centroid = _readMap(data, const ['centroid', 'centroide']);
      final zoneLat = _readNum(centroid, const ['lat']) ??
          _readNum(data, const ['lat', 'latitude']);
      final zoneLng = _readNum(centroid, const ['lng']) ??
          _readNum(data, const ['lng', 'longitude']);
      final radiusKm = _readNum(data, const ['radiusKm', 'radioKm']) ?? 2.0;

      if (zoneLat == null || zoneLng == null) continue;

      final distKm = _haversineKm(lat, lng, zoneLat, zoneLng);
      if (distKm <= radiusKm && distKm < bestDistance) {
        bestDistance = distKm;
        best = ZoneResolution(
          zoneId: zone.id,
          cityId:
              _readText(data, const ['cityId', 'ciudadId', 'city_id']) ?? '',
          provinceId: _readText(
                data,
                const ['provinceId', 'provinciaId', 'province_id'],
              ) ??
              '',
        );
      }
    }

    if (best == null) throw const ZoneNotFoundException();
    return best;
  }

  static String? _readText(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  static Map<String, dynamic>? _readMap(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return Map<String, dynamic>.from(value);
    }
    return null;
  }

  static double? _readNum(Map<String, dynamic>? data, List<String> keys) {
    if (data == null) return null;
    for (final key in keys) {
      final value = data[key];
      if (value is num) return value.toDouble();
    }
    return null;
  }

  double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLng = (lng2 - lng1) * math.pi / 180;
    final sinDLat = math.sin(dLat / 2);
    final sinDLng = math.sin(dLng / 2);
    final a = sinDLat * sinDLat +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            sinDLng *
            sinDLng;
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
}
