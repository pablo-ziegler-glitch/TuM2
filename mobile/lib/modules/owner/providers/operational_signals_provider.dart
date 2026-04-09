import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analytics/owner_operational_signals_analytics.dart';
import '../models/operational_signals.dart';
import '../repositories/owner_operational_signals_repository.dart';

final ownerOperationalSignalsRepositoryProvider =
    Provider<OwnerOperationalSignalsRepository>((ref) {
  return OwnerOperationalSignalsRepository();
});

class OwnerOperationalSignalsScope {
  const OwnerOperationalSignalsScope({
    required this.merchantId,
    required this.ownerUserId,
  });

  final String merchantId;
  final String ownerUserId;

  @override
  bool operator ==(Object other) {
    return other is OwnerOperationalSignalsScope &&
        other.merchantId == merchantId &&
        other.ownerUserId == ownerUserId;
  }

  @override
  int get hashCode => Object.hash(merchantId, ownerUserId);
}

enum OperationalSignalsSaveStatus {
  idle,
  success,
  error,
}

class OperationalSignalsState {
  const OperationalSignalsState({
    required this.merchantId,
    required this.ownerUserId,
    this.signals = OperationalSignals.defaults,
    this.isInitialLoading = true,
    this.savingKeys = const <OperationalSignalKey>{},
    this.saveStatus = OperationalSignalsSaveStatus.idle,
    this.message,
    this.lastSuccessfulSaveAt,
    this.lastUpdatedBy,
  });

  final String merchantId;
  final String ownerUserId;
  final OperationalSignals signals;
  final bool isInitialLoading;
  final Set<OperationalSignalKey> savingKeys;
  final OperationalSignalsSaveStatus saveStatus;
  final String? message;
  final DateTime? lastSuccessfulSaveAt;
  final String? lastUpdatedBy;

  bool get isSavingAny => savingKeys.isNotEmpty;
  bool get hasError => saveStatus == OperationalSignalsSaveStatus.error;
  bool get hasSuccess => saveStatus == OperationalSignalsSaveStatus.success;

  OperationalSignalsState copyWith({
    OperationalSignals? signals,
    bool? isInitialLoading,
    Set<OperationalSignalKey>? savingKeys,
    OperationalSignalsSaveStatus? saveStatus,
    String? message,
    bool clearMessage = false,
    DateTime? lastSuccessfulSaveAt,
    String? lastUpdatedBy,
  }) {
    return OperationalSignalsState(
      merchantId: merchantId,
      ownerUserId: ownerUserId,
      signals: signals ?? this.signals,
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      savingKeys: savingKeys ?? this.savingKeys,
      saveStatus: saveStatus ?? this.saveStatus,
      message: clearMessage ? null : (message ?? this.message),
      lastSuccessfulSaveAt: lastSuccessfulSaveAt ?? this.lastSuccessfulSaveAt,
      lastUpdatedBy: lastUpdatedBy ?? this.lastUpdatedBy,
    );
  }
}

class OperationalSignalsNotifier
    extends StateNotifier<OperationalSignalsState> {
  OperationalSignalsNotifier({
    required OwnerOperationalSignalsRepository repository,
    required OwnerOperationalSignalsScope scope,
  })  : _repository = repository,
        super(
          OperationalSignalsState(
            merchantId: scope.merchantId,
            ownerUserId: scope.ownerUserId,
          ),
        ) {
    unawaited(_load());
  }

  final OwnerOperationalSignalsRepository _repository;

  Future<void> _load() async {
    state = state.copyWith(
      isInitialLoading: true,
      saveStatus: OperationalSignalsSaveStatus.idle,
      clearMessage: true,
    );

    try {
      final snapshot = await _repository.fetchSignals(
        merchantId: state.merchantId,
        ownerUserId: state.ownerUserId,
      );
      state = state.copyWith(
        signals: snapshot.signals,
        isInitialLoading: false,
        lastSuccessfulSaveAt: snapshot.updatedAt,
        lastUpdatedBy: snapshot.updatedBy,
      );
    } on OwnerOperationalSignalsUnauthorizedException {
      state = state.copyWith(
        isInitialLoading: false,
        saveStatus: OperationalSignalsSaveStatus.error,
        message: 'No tenés permisos para editar este comercio.',
      );
    } catch (_) {
      state = state.copyWith(
        isInitialLoading: false,
        saveStatus: OperationalSignalsSaveStatus.error,
        message:
            'No pudimos cargar las señales operativas. Intentá nuevamente.',
      );
    }
  }

  Future<void> updateSignal({
    required OperationalSignalKey key,
    required bool value,
  }) async {
    if (state.isInitialLoading) return;
    if (state.savingKeys.contains(key)) return;

    if (key == OperationalSignalKey.openNowManualOverride &&
        value &&
        state.signals.temporaryClosed) {
      state = state.copyWith(
        saveStatus: OperationalSignalsSaveStatus.error,
        message:
            'No podés marcar "Abierto ahora" mientras esté activo "Cerrado temporalmente".',
      );
      return;
    }

    final previousSignals = state.signals;
    var nextSignals = state.signals.withValue(key, value);
    final payload = <OperationalSignalKey, bool>{key: value};
    if (key == OperationalSignalKey.temporaryClosed && value) {
      // Regla de conflicto MVP: si hay cierre temporal, se apaga "abierto ahora".
      nextSignals = nextSignals.copyWith(openNowManualOverride: false);
      if (previousSignals.openNowManualOverride) {
        payload[OperationalSignalKey.openNowManualOverride] = false;
      }
    }

    final nextSavingKeys = {...state.savingKeys, key};
    if (payload.containsKey(OperationalSignalKey.openNowManualOverride)) {
      nextSavingKeys.add(OperationalSignalKey.openNowManualOverride);
    }

    // Optimistic update: se refleja en UI antes de persistir en Firestore.
    state = state.copyWith(
      signals: nextSignals,
      savingKeys: nextSavingKeys,
      saveStatus: OperationalSignalsSaveStatus.idle,
      clearMessage: true,
    );

    try {
      await _repository.updateSignals(
        merchantId: state.merchantId,
        ownerUserId: state.ownerUserId,
        values: payload,
      );

      final remainingSavingKeys = {...state.savingKeys}
        ..removeAll(payload.keys);
      final hasRemainingPendingWrites = remainingSavingKeys.isNotEmpty;
      state = state.copyWith(
        signals: state.signals,
        savingKeys: remainingSavingKeys,
        saveStatus: hasRemainingPendingWrites
            ? OperationalSignalsSaveStatus.idle
            : OperationalSignalsSaveStatus.success,
        message: hasRemainingPendingWrites ? null : 'Cambios guardados.',
        clearMessage: hasRemainingPendingWrites,
        lastSuccessfulSaveAt: DateTime.now(),
        lastUpdatedBy: state.ownerUserId,
      );
      unawaited(OwnerOperationalSignalsAnalytics.logSaved(
        merchantId: state.merchantId,
        payload: _payloadFromSignals(state.signals),
      ));
    } on OwnerOperationalSignalsUnauthorizedException {
      _rollbackAndTrackFailure(
        previousSignals: previousSignals,
        payloadKeys: payload.keys,
        message: 'Tu sesión no puede editar este comercio.',
        reason: 'unauthorized',
      );
    } catch (_) {
      _rollbackAndTrackFailure(
        previousSignals: previousSignals,
        payloadKeys: payload.keys,
        message: 'No pudimos guardar el cambio. Revisá tu conexión.',
        reason: 'save_failed',
      );
    }
  }

  Future<void> retryLoad() => _load();

  void clearFeedback() {
    state = state.copyWith(
      saveStatus: OperationalSignalsSaveStatus.idle,
      clearMessage: true,
    );
  }

  void _rollbackAndTrackFailure({
    required OperationalSignals previousSignals,
    required Iterable<OperationalSignalKey> payloadKeys,
    required String message,
    required String reason,
  }) {
    final remainingSavingKeys = {...state.savingKeys}..removeAll(payloadKeys);
    // Rollback: si falla la persistencia, restauramos el estado previo.
    state = state.copyWith(
      signals: previousSignals,
      savingKeys: remainingSavingKeys,
      saveStatus: OperationalSignalsSaveStatus.error,
      message: message,
    );
    unawaited(OwnerOperationalSignalsAnalytics.logSaveFailed(
      merchantId: state.merchantId,
      reason: reason,
      payload: _payloadFromSignals(previousSignals),
    ));
  }
}

OperationalSignalsAnalyticsPayload _payloadFromSignals(
  OperationalSignals signals,
) {
  return OperationalSignalsAnalyticsPayload(
    temporaryClosed: signals.temporaryClosed,
    hasDelivery: signals.hasDelivery,
    acceptsWhatsappOrders: signals.acceptsWhatsappOrders,
    openNowManualOverride: signals.openNowManualOverride,
  );
}

final operationalSignalsNotifierProvider = StateNotifierProvider.autoDispose
    .family<OperationalSignalsNotifier, OperationalSignalsState,
        OwnerOperationalSignalsScope>((ref, scope) {
  final repository = ref.watch(ownerOperationalSignalsRepositoryProvider);
  return OperationalSignalsNotifier(
    repository: repository,
    scope: scope,
  );
});
