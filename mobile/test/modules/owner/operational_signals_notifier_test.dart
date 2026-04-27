import 'package:flutter_test/flutter_test.dart';
import 'package:tum2/modules/owner/models/operational_signals.dart';
import 'package:tum2/modules/owner/providers/operational_signals_provider.dart';
import 'package:tum2/modules/owner/repositories/owner_operational_signals_repository.dart';

void main() {
  group('OperationalSignalType', () {
    test('mapea firestore values canónicos', () {
      expect(
        OperationalSignalTypeX.fromFirestoreValue('vacation'),
        OperationalSignalType.vacation,
      );
      expect(
        OperationalSignalTypeX.fromFirestoreValue('temporary_closure'),
        OperationalSignalType.temporaryClosure,
      );
      expect(
        OperationalSignalTypeX.fromFirestoreValue('delay'),
        OperationalSignalType.delay,
      );
      expect(
        OperationalSignalTypeX.fromFirestoreValue('otro'),
        OperationalSignalType.none,
      );
    });
  });

  group('OwnerOperationalSignalsRepository', () {
    test('upsert guarda tipo + fuerza de cierre', () async {
      final dataSource = _FakeDataSource();
      final repository =
          OwnerOperationalSignalsRepository(dataSource: dataSource);

      await repository.upsertSignal(
        merchantId: 'm1',
        ownerUserId: 'owner-1',
        signalType: OperationalSignalType.vacation,
        message: 'Cerrado por vacaciones',
      );

      expect(dataSource.savedType, OperationalSignalType.vacation);
      expect(dataSource.savedMessage, 'Cerrado por vacaciones');
    });
  });

  group('OperationalSignalsNotifier', () {
    test('carga inicial sin señal activa', () async {
      final dataSource = _FakeDataSource();
      final notifier = _buildNotifier(dataSource);
      await _waitForLoad(notifier);

      expect(notifier.state.hasActiveSignal, isFalse);
      expect(
          notifier.state.currentSignal.signalType, OperationalSignalType.none);
    });

    test('carga inicial con señal activa', () async {
      final dataSource = _FakeDataSource(
        stored: const OwnerOperationalSignal(
          merchantId: 'm1',
          ownerUserId: 'owner-1',
          signalType: OperationalSignalType.delay,
          isActive: true,
          message: 'Abrimos a las 10:00',
          forceClosed: false,
          schemaVersion: operationalSignalSchemaVersion,
        ),
      );
      final notifier = _buildNotifier(dataSource);
      await _waitForLoad(notifier);

      expect(notifier.state.hasActiveSignal, isTrue);
      expect(notifier.state.draftSignalType, OperationalSignalType.delay);
    });

    test('guardar vacation', () async {
      final dataSource = _FakeDataSource();
      final notifier = _buildNotifier(dataSource);
      await _waitForLoad(notifier);

      notifier.setDraftSignalType(OperationalSignalType.vacation);
      notifier.setDraftMessage('Volvemos el lunes');
      await notifier.saveDraft();

      expect(dataSource.savedType, OperationalSignalType.vacation);
      expect(notifier.state.hasSuccess, isTrue);
      expect(notifier.state.currentSignal.forceClosed, isTrue);
    });

    test('guardar temporary_closure', () async {
      final dataSource = _FakeDataSource();
      final notifier = _buildNotifier(dataSource);
      await _waitForLoad(notifier);

      notifier.setDraftSignalType(OperationalSignalType.temporaryClosure);
      notifier.setDraftMessage('Mantenimiento');
      await notifier.saveDraft();

      expect(dataSource.savedType, OperationalSignalType.temporaryClosure);
      expect(notifier.state.currentSignal.forceClosed, isTrue);
    });

    test('guardar delay', () async {
      final dataSource = _FakeDataSource();
      final notifier = _buildNotifier(dataSource);
      await _waitForLoad(notifier);

      notifier.setDraftSignalType(OperationalSignalType.delay);
      notifier.setDraftMessage('Abrimos con demora');
      await notifier.saveDraft();

      expect(dataSource.savedType, OperationalSignalType.delay);
      expect(notifier.state.currentSignal.forceClosed, isFalse);
    });

    test('limpiar señal activa', () async {
      final dataSource = _FakeDataSource(
        stored: const OwnerOperationalSignal(
          merchantId: 'm1',
          ownerUserId: 'owner-1',
          signalType: OperationalSignalType.vacation,
          isActive: true,
          message: 'Cerrado por vacaciones',
          forceClosed: true,
          schemaVersion: operationalSignalSchemaVersion,
        ),
      );
      final notifier = _buildNotifier(dataSource);
      await _waitForLoad(notifier);

      await notifier.clearSignal();

      expect(dataSource.clearCalled, isTrue);
      expect(
          notifier.state.currentSignal.signalType, OperationalSignalType.none);
      expect(notifier.state.hasActiveSignal, isFalse);
    });

    test('error de permisos', () async {
      final dataSource = _FakeDataSource(unauthorizedOnSave: true);
      final notifier = _buildNotifier(dataSource);
      await _waitForLoad(notifier);

      notifier.setDraftSignalType(OperationalSignalType.delay);
      await notifier.saveDraft();

      expect(notifier.state.hasError, isTrue);
      expect(notifier.state.message, contains('no puede editar'));
    });

    test('error de red', () async {
      final dataSource = _FakeDataSource(throwOnSave: true);
      final notifier = _buildNotifier(dataSource);
      await _waitForLoad(notifier);

      notifier.setDraftSignalType(OperationalSignalType.delay);
      await notifier.saveDraft();

      expect(notifier.state.hasError, isTrue);
      expect(notifier.state.message, contains('No pudimos guardar'));
    });

    test('rechaza mensaje mayor a 80 caracteres', () async {
      final dataSource = _FakeDataSource();
      final notifier = _buildNotifier(dataSource);
      await _waitForLoad(notifier);

      notifier.setDraftSignalType(OperationalSignalType.delay);
      notifier.setDraftMessage('a' * 81);
      await notifier.saveDraft();

      expect(notifier.state.hasError, isTrue);
      expect(notifier.state.validationError, contains('hasta 80 caracteres'));
      expect(dataSource.savedType, isNull);
    });
  });
}

OperationalSignalsNotifier _buildNotifier(_FakeDataSource dataSource) {
  final repository = OwnerOperationalSignalsRepository(dataSource: dataSource);
  return OperationalSignalsNotifier(
    repository: repository,
    scope: const OwnerOperationalSignalsScope(
      merchantId: 'm1',
      ownerUserId: 'owner-1',
    ),
  );
}

Future<void> _waitForLoad(OperationalSignalsNotifier notifier) async {
  for (var i = 0; i < 20; i++) {
    if (!notifier.state.isInitialLoading) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

class _FakeDataSource implements OwnerOperationalSignalsDataSource {
  _FakeDataSource({
    this.stored,
    this.throwOnSave = false,
    this.unauthorizedOnSave = false,
  });

  OwnerOperationalSignal? stored;
  final bool throwOnSave;
  final bool unauthorizedOnSave;
  bool clearCalled = false;
  OperationalSignalType? savedType;
  String? savedMessage;

  @override
  Future<void> clearSignal({
    required String merchantId,
    required String ownerUserId,
  }) async {
    if (unauthorizedOnSave) {
      throw const OwnerOperationalSignalsUnauthorizedException();
    }
    clearCalled = true;
    stored = OwnerOperationalSignal.empty(
      merchantId: merchantId,
      ownerUserId: ownerUserId,
    );
  }

  @override
  Future<OwnerOperationalSignal?> fetchSignal({
    required String merchantId,
  }) async {
    return stored;
  }

  @override
  Future<void> upsertSignal({
    required String merchantId,
    required String ownerUserId,
    required OperationalSignalType signalType,
    required String? message,
  }) async {
    if (unauthorizedOnSave) {
      throw const OwnerOperationalSignalsUnauthorizedException();
    }
    if (throwOnSave) {
      throw Exception('network');
    }
    savedType = signalType;
    savedMessage = message;
    stored = OwnerOperationalSignal(
      merchantId: merchantId,
      ownerUserId: ownerUserId,
      signalType: signalType,
      isActive: signalType != OperationalSignalType.none,
      message: message,
      forceClosed: signalType.forcesClosed,
      schemaVersion: operationalSignalSchemaVersion,
      updatedAt: DateTime(2026, 4, 13, 14),
      updatedByUid: ownerUserId,
    );
  }
}
