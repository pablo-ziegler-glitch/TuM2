import 'package:flutter_test/flutter_test.dart';
import 'package:tum2/modules/owner/models/operational_signals.dart';
import 'package:tum2/modules/owner/providers/operational_signals_provider.dart';
import 'package:tum2/modules/owner/repositories/owner_operational_signals_repository.dart';

void main() {
  group('OperationalSignals model', () {
    test('usa defaults en campos faltantes y serializa claves canónicas', () {
      final model = OperationalSignals.fromMap({
        'temporaryClosed': true,
      });

      expect(model.temporaryClosed, isTrue);
      expect(model.hasDelivery, isFalse);
      expect(model.acceptsWhatsappOrders, isFalse);
      expect(model.openNowManualOverride, isFalse);

      final map = model.toMap();
      expect(
          map.keys,
          containsAll(const [
            'temporaryClosed',
            'hasDelivery',
            'acceptsWhatsappOrders',
            'openNowManualOverride',
          ]));
    });
  });

  group('OwnerOperationalSignalsRepository', () {
    test('valida ownership antes de guardar', () async {
      final dataSource = _FakeDataSource(
        ownerByMerchantId: const {'m1': 'owner-1'},
      );
      final repository = OwnerOperationalSignalsRepository(
        dataSource: dataSource,
      );

      final isOwner = await repository.validateOwnership(
        merchantId: 'm1',
        ownerUserId: 'owner-1',
      );
      expect(isOwner, isTrue);

      final isNotOwner = await repository.validateOwnership(
        merchantId: 'm1',
        ownerUserId: 'owner-2',
      );
      expect(isNotOwner, isFalse);

      await repository.updateSignal(
        merchantId: 'm1',
        ownerUserId: 'owner-1',
        key: OperationalSignalKey.hasDelivery,
        value: true,
      );

      expect(dataSource.saved.length, 1);
      expect(dataSource.saved.first.merchantId, 'm1');
      expect(dataSource.saved.first.updatedBy, 'owner-1');
      expect(dataSource.saved.first.key, OperationalSignalKey.hasDelivery);
      expect(dataSource.saved.first.value, isTrue);
    });
  });

  group('OperationalSignalsNotifier', () {
    test('aplica optimistic update y confirma success', () async {
      final dataSource = _FakeDataSource(
        ownerByMerchantId: const {'m1': 'owner-1'},
      );
      final repository = OwnerOperationalSignalsRepository(
        dataSource: dataSource,
      );

      final notifier = OperationalSignalsNotifier(
        repository: repository,
        scope: const OwnerOperationalSignalsScope(
          merchantId: 'm1',
          ownerUserId: 'owner-1',
        ),
      );
      await _waitForLoad(notifier);

      final future = notifier.updateSignal(
        key: OperationalSignalKey.temporaryClosed,
        value: true,
      );

      expect(notifier.state.signals.temporaryClosed, isTrue);
      expect(
        notifier.state.savingKeys,
        contains(OperationalSignalKey.temporaryClosed),
      );

      await future;

      expect(notifier.state.signals.temporaryClosed, isTrue);
      expect(notifier.state.savingKeys, isEmpty);
      expect(
        notifier.state.saveStatus,
        OperationalSignalsSaveStatus.success,
      );
    });

    test('hace rollback cuando falla la persistencia', () async {
      final dataSource = _FakeDataSource(
        ownerByMerchantId: const {'m1': 'owner-1'},
        throwOnSave: true,
      );
      final repository = OwnerOperationalSignalsRepository(
        dataSource: dataSource,
      );

      final notifier = OperationalSignalsNotifier(
        repository: repository,
        scope: const OwnerOperationalSignalsScope(
          merchantId: 'm1',
          ownerUserId: 'owner-1',
        ),
      );
      await _waitForLoad(notifier);

      final future = notifier.updateSignal(
        key: OperationalSignalKey.acceptsWhatsappOrders,
        value: true,
      );

      expect(notifier.state.signals.acceptsWhatsappOrders, isTrue);
      await future;

      expect(notifier.state.signals.acceptsWhatsappOrders, isFalse);
      expect(
        notifier.state.saveStatus,
        OperationalSignalsSaveStatus.error,
      );
    });

    test('marca error de permisos si ownership no coincide', () async {
      final dataSource = _FakeDataSource(
        ownerByMerchantId: const {'m1': 'owner-99'},
      );
      final repository = OwnerOperationalSignalsRepository(
        dataSource: dataSource,
      );
      final notifier = OperationalSignalsNotifier(
        repository: repository,
        scope: const OwnerOperationalSignalsScope(
          merchantId: 'm1',
          ownerUserId: 'owner-1',
        ),
      );

      await _waitForLoad(notifier);

      expect(notifier.state.hasError, isTrue);
      expect(notifier.state.message, contains('permisos'));
    });

    test('bloquea abierto ahora manual cuando hay cierre temporal', () async {
      final dataSource = _FakeDataSource(
        ownerByMerchantId: const {'m1': 'owner-1'},
      );
      final repository = OwnerOperationalSignalsRepository(
        dataSource: dataSource,
      );
      final notifier = OperationalSignalsNotifier(
        repository: repository,
        scope: const OwnerOperationalSignalsScope(
          merchantId: 'm1',
          ownerUserId: 'owner-1',
        ),
      );

      await _waitForLoad(notifier);

      await notifier.updateSignal(
        key: OperationalSignalKey.temporaryClosed,
        value: true,
      );
      await notifier.updateSignal(
        key: OperationalSignalKey.openNowManualOverride,
        value: true,
      );

      expect(notifier.state.signals.temporaryClosed, isTrue);
      expect(notifier.state.signals.openNowManualOverride, isFalse);
      expect(notifier.state.hasError, isTrue);
      expect(notifier.state.message, contains('Abierto ahora'));
    });

    test('mantiene toggles optimistas cuando hay saves concurrentes', () async {
      final dataSource = _FakeDataSource(
        ownerByMerchantId: const {'m1': 'owner-1'},
        saveDelay: const Duration(milliseconds: 20),
      );
      final repository = OwnerOperationalSignalsRepository(
        dataSource: dataSource,
      );
      final notifier = OperationalSignalsNotifier(
        repository: repository,
        scope: const OwnerOperationalSignalsScope(
          merchantId: 'm1',
          ownerUserId: 'owner-1',
        ),
      );
      await _waitForLoad(notifier);

      final saveA = notifier.updateSignal(
        key: OperationalSignalKey.hasDelivery,
        value: true,
      );
      final saveB = notifier.updateSignal(
        key: OperationalSignalKey.acceptsWhatsappOrders,
        value: true,
      );
      await Future.wait([saveA, saveB]);

      expect(notifier.state.signals.hasDelivery, isTrue);
      expect(notifier.state.signals.acceptsWhatsappOrders, isTrue);
      expect(notifier.state.savingKeys, isEmpty);
    });
  });
}

// TODO(tum2-0067): agregar test de integración con emulador Firestore para:
// - validar que `updatedAt` llegue como serverTimestamp real
// - verificar que Rules bloqueen escritura de merchant ajeno (IDOR)
// - verificar que write en `merchant_operational_signals` dispare trigger backend
//   y recomponga `merchant_public` con prioridad de `temporaryClosed`.

Future<void> _waitForLoad(OperationalSignalsNotifier notifier) async {
  for (var i = 0; i < 20; i++) {
    if (!notifier.state.isInitialLoading) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

class _SavedSignal {
  const _SavedSignal({
    required this.merchantId,
    required this.updatedBy,
    required this.key,
    required this.value,
  });

  final String merchantId;
  final String updatedBy;
  final OperationalSignalKey key;
  final bool value;
}

class _FakeDataSource implements OwnerOperationalSignalsDataSource {
  _FakeDataSource({
    this.ownerByMerchantId = const {},
    this.throwOnSave = false,
    this.saveDelay = Duration.zero,
  });

  final Map<String, String> ownerByMerchantId;
  final bool throwOnSave;
  final Duration saveDelay;
  final List<_SavedSignal> saved = [];
  final Map<String, OperationalSignals> _signalsByMerchant = {};
  final Map<String, DateTime> _updatedAtByMerchant = {};

  @override
  Future<String?> fetchOwnerUserId({required String merchantId}) async {
    return ownerByMerchantId[merchantId];
  }

  @override
  Future<OperationalSignalsSnapshot> fetchSignals({
    required String merchantId,
  }) async {
    return OperationalSignalsSnapshot(
      signals: _signalsByMerchant[merchantId] ?? OperationalSignals.defaults,
      updatedAt: _updatedAtByMerchant[merchantId],
      updatedBy: ownerByMerchantId[merchantId],
    );
  }

  @override
  Future<void> saveSignalsIfOwned({
    required String merchantId,
    required String ownerUserId,
    required String updatedBy,
    required Map<OperationalSignalKey, bool> values,
  }) async {
    if (saveDelay > Duration.zero) {
      await Future<void>.delayed(saveDelay);
    }
    if (throwOnSave) {
      throw Exception('save failed');
    }
    final expectedOwnerUserId = ownerByMerchantId[merchantId];
    if (expectedOwnerUserId == null || expectedOwnerUserId != ownerUserId) {
      throw const OwnerOperationalSignalsUnauthorizedException();
    }
    final current =
        _signalsByMerchant[merchantId] ?? OperationalSignals.defaults;
    var next = current;
    for (final entry in values.entries) {
      next = next.withValue(entry.key, entry.value);
      saved.add(
        _SavedSignal(
          merchantId: merchantId,
          updatedBy: updatedBy,
          key: entry.key,
          value: entry.value,
        ),
      );
    }
    _signalsByMerchant[merchantId] = next;
    _updatedAtByMerchant[merchantId] = DateTime(2026, 4, 8, 14, 0, 0);
  }
}
