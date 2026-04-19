import 'package:flutter_test/flutter_test.dart';
import 'package:tum2/modules/pharmacy/repositories/pharmacy_duty_repository.dart';

void main() {
  group('PharmacyDutyRepository.chunkIds', () {
    test('chunking defensivo para whereIn', () {
      final ids = List<String>.generate(23, (index) => 'm$index');
      final chunks = PharmacyDutyRepository.chunkIds(ids, chunkSize: 10);
      expect(chunks.length, 3);
      expect(chunks[0].length, 10);
      expect(chunks[1].length, 10);
      expect(chunks[2].length, 3);
    });
  });

  group('PharmacyDutyRepository.getPublishedDuties', () {
    test('filtra merchants ocultos o inconsistentes', () async {
      final logger = _RecordingInconsistencyLogger();
      final repository = PharmacyDutyRepository(
        dataSource: _FakeDataSource(
          duties: const [
            PharmacyDutyRecord(
              id: 'duty-1',
              merchantId: 'm-1',
              zoneId: 'z1',
              date: '2026-04-07',
            ),
            PharmacyDutyRecord(
              id: 'duty-2',
              merchantId: 'm-2',
              zoneId: 'z1',
              date: '2026-04-07',
            ),
            PharmacyDutyRecord(
              id: 'duty-3',
              merchantId: 'm-3',
              zoneId: 'z1',
              date: '2026-04-07',
            ),
          ],
          merchants: const [
            MerchantPublicRecord(
              id: 'm-1',
              data: {
                'name': 'Farmacia Uno',
                'categoryId': 'farmacia',
                'zoneId': 'z1',
                'addressLine': 'Calle 123',
                'phone': '11 5555 1111',
                'visibilityStatus': 'visible',
                'isOpenNow': true,
                'is24Hours': false,
              },
            ),
            MerchantPublicRecord(
              id: 'm-2',
              data: {
                'name': 'Farmacia Oculta',
                'categoryId': 'farmacia',
                'zoneId': 'z1',
                'addressLine': 'Calle 555',
                'phone': '11 5555 2222',
                'visibilityStatus': 'hidden',
              },
            ),
          ],
        ),
        inconsistencyLogger: logger,
      );

      final result = await repository.getPublishedDuties(
        zoneId: 'z1',
        dateKey: '2026-04-07',
      );

      expect(result.length, 1);
      expect(result.first.merchantId, 'm-1');
      expect(
        logger.codes,
        containsAll(
            <String>['merchant_not_visible', 'missing_merchant_public']),
      );
    });

    test('deduplica duties publicados para mismo merchant', () async {
      final logger = _RecordingInconsistencyLogger();
      final repository = PharmacyDutyRepository(
        dataSource: _FakeDataSource(
          duties: const [
            PharmacyDutyRecord(
              id: 'duty-1',
              merchantId: 'm-1',
              zoneId: 'z1',
              date: '2026-04-07',
            ),
            PharmacyDutyRecord(
              id: 'duty-2',
              merchantId: 'm-1',
              zoneId: 'z1',
              date: '2026-04-07',
            ),
          ],
          merchants: const [
            MerchantPublicRecord(
              id: 'm-1',
              data: {
                'name': 'Farmacia Uno',
                'categoryId': 'farmacia',
                'zoneId': 'z1',
                'addressLine': 'Calle 123',
                'phone': '11 5555 1111',
                'visibilityStatus': 'visible',
              },
            ),
          ],
        ),
        inconsistencyLogger: logger,
      );

      final result = await repository.getPublishedDuties(
        zoneId: 'z1',
        dateKey: '2026-04-07',
      );

      expect(result.length, 1);
      expect(logger.codes, contains('duplicate_duty_published'));
    });

    test('acepta flag is24h canonico de merchant_public', () async {
      final repository = PharmacyDutyRepository(
        dataSource: _FakeDataSource(
          duties: const [
            PharmacyDutyRecord(
              id: 'duty-1',
              merchantId: 'm-1',
              zoneId: 'z1',
              date: '2026-04-07',
            ),
          ],
          merchants: const [
            MerchantPublicRecord(
              id: 'm-1',
              data: {
                'name': 'Farmacia Uno',
                'categoryId': 'farmacia',
                'zoneId': 'z1',
                'addressLine': 'Calle 123',
                'phone': '11 5555 1111',
                'visibilityStatus': 'visible',
                'isOpenNow': true,
                'is24h': true,
              },
            ),
          ],
        ),
      );

      final result = await repository.getPublishedDuties(
        zoneId: 'z1',
        dateKey: '2026-04-07',
      );

      expect(result.length, 1);
      expect(result.first.is24Hours, isTrue);
    });
  });
}

class _FakeDataSource implements PharmacyDutyDataSource {
  _FakeDataSource({
    required this.duties,
    required this.merchants,
  });

  final List<PharmacyDutyRecord> duties;
  final List<MerchantPublicRecord> merchants;

  @override
  Future<List<PharmacyDutyRecord>> fetchPublishedDuties({
    required String zoneId,
    required String dateKey,
  }) async {
    return duties;
  }

  @override
  Future<List<MerchantPublicRecord>> fetchMerchantsByIds(
      List<String> ids) async {
    return merchants.where((merchant) => ids.contains(merchant.id)).toList();
  }
}

class _RecordingInconsistencyLogger implements PharmacyDutyInconsistencyLogger {
  final List<PharmacyDutyInconsistency> logged = [];

  List<String> get codes =>
      logged.map((entry) => entry.code).toList(growable: false);

  @override
  void log(PharmacyDutyInconsistency inconsistency) {
    logged.add(inconsistency);
  }
}
