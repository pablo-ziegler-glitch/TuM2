import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tum2_admin/core/catalog/zones_catalog_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ZonesCatalogClient', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      ZonesCatalogClient.resetForTest();
    });

    test('dedupea cargas concurrentes y evita doble request', () async {
      final remoteCatalog = _catalog(version: 2, zoneName: 'Remote V2');
      final manifest = jsonEncode({
        'catalog': 'zones',
        'version': 2,
        'publishedAt': '2026-04-26T00:00:00Z',
        'file': '/catalogs/zones/prod/versions/zones-v2.json',
        'checksum': _checksum(remoteCatalog),
        'schemaVersion': 1,
        'entries': 1,
      });
      final httpClient = _FakeHttpClient({
        '/catalogs/zones/prod/manifest.json': [
          _FakeHttpResponse(200, manifest),
        ],
        '/catalogs/zones/prod/versions/zones-v2.json': [
          _FakeHttpResponse(200, remoteCatalog),
        ],
      });
      final client = ZonesCatalogClient(
        httpClient: httpClient,
        assetBundle:
            _FakeAssetBundle(_catalog(version: 1, zoneName: 'Seed V1')),
      );

      final results = await Future.wait([
        client.loadZones(forceManifestCheck: true),
        client.loadZones(forceManifestCheck: true),
      ]);

      expect(results, hasLength(2));
      expect(results.first.single['name'], 'Remote V2');
      expect(results.last.single['name'], 'Remote V2');
      expect(httpClient.requestCount('/catalogs/zones/prod/manifest.json'), 1);
      expect(
        httpClient.requestCount('/catalogs/zones/prod/versions/zones-v2.json'),
        1,
      );
    });
  });
}

String _catalog({
  required int version,
  required String zoneName,
}) {
  return jsonEncode({
    'catalog': 'zones',
    'schemaVersion': 1,
    'version': version,
    'generatedAt': '2026-04-26T00:00:00Z',
    'entries': 1,
    'zones': [
      {
        'id': 'ar-caba-palermo',
        'zoneId': 'ar-caba-palermo',
        'name': zoneName,
        'normalizedName': 'palermo',
        'provinceId': 'ar-caba',
        'provinceName': 'Ciudad Autónoma de Buenos Aires',
        'provinceNormalizedName': 'ciudad autonoma de buenos aires',
        'departmentId': 'ar-caba-comuna14',
        'departmentName': 'Comuna 14',
        'departmentNormalizedName': 'comuna 14',
        'localityId': 'ar-caba-palermo',
        'localityName': zoneName,
        'localityNormalizedName': 'palermo',
        'cityId': 'ar-caba-palermo',
        'countryId': 'AR',
        'countryName': 'Argentina',
        'status': 'public_enabled',
        'priorityLevel': 1
      }
    ]
  });
}

String _checksum(String payload) {
  final digest = sha256.convert(utf8.encode(payload)).bytes;
  return 'sha256-${base64.encode(digest)}';
}

class _FakeAssetBundle extends AssetBundle {
  _FakeAssetBundle(this._seedCatalog);

  final String _seedCatalog;

  @override
  Future<ByteData> load(String key) async {
    throw UnimplementedError();
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    return _seedCatalog;
  }
}

class _FakeHttpClient extends http.BaseClient {
  _FakeHttpClient(this._responses);

  final Map<String, List<_FakeHttpResponse>> _responses;
  final Map<String, int> _requests = <String, int>{};

  int requestCount(String url) => _requests[url] ?? 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final url = request.url.toString();
    _requests[url] = (_requests[url] ?? 0) + 1;
    final queue = _responses[url];
    if (queue == null || queue.isEmpty) {
      return http.StreamedResponse(
        Stream<List<int>>.value(utf8.encode('not found')),
        404,
      );
    }
    final response = queue.removeAt(0);
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(response.body)),
      response.statusCode,
      headers: {'content-type': 'application/json'},
    );
  }
}

class _FakeHttpResponse {
  const _FakeHttpResponse(this.statusCode, this.body);

  final int statusCode;
  final String body;
}
