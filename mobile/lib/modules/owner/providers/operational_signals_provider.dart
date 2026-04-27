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
    required this.currentSignal,
    required this.draftSignalType,
    required this.draftMessage,
    this.validationError,
    this.message,
    this.lastSuccessfulSaveAt,
    this.isInitialLoading = true,
    this.isSaving = false,
    this.saveStatus = OperationalSignalsSaveStatus.idle,
  });

  final String merchantId;
  final String ownerUserId;
  final OwnerOperationalSignal currentSignal;
  final OperationalSignalType draftSignalType;
  final String draftMessage;
  final String? validationError;
  final String? message;
  final DateTime? lastSuccessfulSaveAt;
  final bool isInitialLoading;
  final bool isSaving;
  final OperationalSignalsSaveStatus saveStatus;

  bool get hasError => saveStatus == OperationalSignalsSaveStatus.error;
  bool get hasSuccess => saveStatus == OperationalSignalsSaveStatus.success;
  bool get hasActiveSignal => currentSignal.hasActiveSignal;

  OperationalSignalsState copyWith({
    OwnerOperationalSignal? currentSignal,
    OperationalSignalType? draftSignalType,
    String? draftMessage,
    String? validationError,
    bool clearValidationError = false,
    String? message,
    bool clearMessage = false,
    DateTime? lastSuccessfulSaveAt,
    bool? isInitialLoading,
    bool? isSaving,
    OperationalSignalsSaveStatus? saveStatus,
  }) {
    return OperationalSignalsState(
      merchantId: merchantId,
      ownerUserId: ownerUserId,
      currentSignal: currentSignal ?? this.currentSignal,
      draftSignalType: draftSignalType ?? this.draftSignalType,
      draftMessage: draftMessage ?? this.draftMessage,
      validationError: clearValidationError
          ? null
          : (validationError ?? this.validationError),
      message: clearMessage ? null : (message ?? this.message),
      lastSuccessfulSaveAt: lastSuccessfulSaveAt ?? this.lastSuccessfulSaveAt,
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      isSaving: isSaving ?? this.isSaving,
      saveStatus: saveStatus ?? this.saveStatus,
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
            currentSignal: OwnerOperationalSignal.empty(
              merchantId: scope.merchantId,
              ownerUserId: scope.ownerUserId,
            ),
            draftSignalType: OperationalSignalType.none,
            draftMessage: '',
          ),
        ) {
    unawaited(load());
  }

  final OwnerOperationalSignalsRepository _repository;

  Future<void> load() async {
    state = state.copyWith(
      isInitialLoading: true,
      saveStatus: OperationalSignalsSaveStatus.idle,
      clearValidationError: true,
      clearMessage: true,
    );

    try {
      final signal =
          await _repository.fetchSignal(merchantId: state.merchantId);
      final resolved = signal ??
          OwnerOperationalSignal.empty(
            merchantId: state.merchantId,
            ownerUserId: state.ownerUserId,
          );
      state = state.copyWith(
        currentSignal: resolved,
        draftSignalType: resolved.hasActiveSignal
            ? resolved.signalType
            : OperationalSignalType.none,
        draftMessage: resolved.message ?? '',
        isInitialLoading: false,
        lastSuccessfulSaveAt: resolved.updatedAt,
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
        message: 'No pudimos cargar la señal operativa. Intentá nuevamente.',
      );
    }
  }

  void setDraftSignalType(OperationalSignalType type) {
    final previousType = state.draftSignalType;
    state = state.copyWith(
      draftSignalType: type,
      saveStatus: OperationalSignalsSaveStatus.idle,
      clearValidationError: true,
      clearMessage: true,
    );
    if (type != OperationalSignalType.none && type != previousType) {
      unawaited(OwnerOperationalSignalsAnalytics.logCreateStarted(
        merchantId: state.merchantId,
        signalType: type,
      ));
    }
  }

  void setDraftMessage(String value) {
    final trimmed = value.trimLeft();
    state = state.copyWith(
      draftMessage: trimmed,
      saveStatus: OperationalSignalsSaveStatus.idle,
      clearValidationError: true,
      clearMessage: true,
    );
  }

  Future<void> saveDraft() async {
    if (state.isSaving || state.isInitialLoading) return;

    final signalType = state.draftSignalType;
    final message = state.draftMessage.trim();

    if (signalType == OperationalSignalType.none) {
      state = state.copyWith(
        saveStatus: OperationalSignalsSaveStatus.error,
        validationError: 'Elegí una señal operativa para guardar.',
      );
      return;
    }
    if (message.length > operationalSignalMaxMessageLength) {
      state = state.copyWith(
        saveStatus: OperationalSignalsSaveStatus.error,
        validationError:
            'El mensaje puede tener hasta $operationalSignalMaxMessageLength caracteres.',
      );
      return;
    }

    state = state.copyWith(
      isSaving: true,
      saveStatus: OperationalSignalsSaveStatus.idle,
      clearValidationError: true,
      clearMessage: true,
    );

    try {
      await _repository.upsertSignal(
        merchantId: state.merchantId,
        ownerUserId: state.ownerUserId,
        signalType: signalType,
        message: message.isEmpty ? null : message,
      );
      final resolved = state.currentSignal.copyWith(
        signalType: signalType,
        isActive: true,
        message: message.isEmpty ? null : message,
        clearMessage: message.isEmpty,
        forceClosed: signalType.forcesClosed,
        schemaVersion: operationalSignalSchemaVersion,
        updatedAt: DateTime.now(),
        updatedByUid: state.ownerUserId,
      );
      state = state.copyWith(
        currentSignal: resolved,
        draftSignalType: resolved.signalType,
        draftMessage: resolved.message ?? '',
        isInitialLoading: false,
        isSaving: false,
        saveStatus: OperationalSignalsSaveStatus.success,
        message: 'Aviso activo para los Vecinos.',
        lastSuccessfulSaveAt: resolved.updatedAt,
      );
      unawaited(OwnerOperationalSignalsAnalytics.logSaved(
        merchantId: state.merchantId,
        payload: OperationalSignalsAnalyticsPayload(
          signalType: signalType,
          hasMessage: message.isNotEmpty,
          hasEndDate: false,
        ),
      ));
      unawaited(_refreshSignalFromRepositoryBestEffort());
    } on OwnerOperationalSignalsUnauthorizedException {
      _setSaveError(
        message: 'Tu sesión no puede editar este comercio.',
        reason: 'permission_denied',
      );
    } catch (_) {
      _setSaveError(
        message:
            'No pudimos guardar los cambios. Revisá tu conexión y probá de nuevo.',
        reason: 'network_or_backend_error',
      );
    }
  }

  Future<void> clearSignal() async {
    if (state.isSaving || state.isInitialLoading || !state.hasActiveSignal) {
      return;
    }
    state = state.copyWith(
      isSaving: true,
      saveStatus: OperationalSignalsSaveStatus.idle,
      clearValidationError: true,
      clearMessage: true,
    );

    try {
      await _repository.clearSignal(
        merchantId: state.merchantId,
        ownerUserId: state.ownerUserId,
      );
      final resolved = state.currentSignal.copyWith(
        signalType: OperationalSignalType.none,
        isActive: false,
        clearMessage: true,
        forceClosed: false,
        schemaVersion: operationalSignalSchemaVersion,
        updatedAt: DateTime.now(),
        updatedByUid: state.ownerUserId,
      );
      state = state.copyWith(
        currentSignal: resolved,
        draftSignalType: OperationalSignalType.none,
        draftMessage: '',
        isInitialLoading: false,
        isSaving: false,
        saveStatus: OperationalSignalsSaveStatus.success,
        message: 'Aviso desactivado.',
        lastSuccessfulSaveAt: resolved.updatedAt,
      );
      unawaited(OwnerOperationalSignalsAnalytics.logDisabled(
        merchantId: state.merchantId,
      ));
      unawaited(_refreshSignalFromRepositoryBestEffort());
    } on OwnerOperationalSignalsUnauthorizedException {
      _setSaveError(
        message: 'Tu sesión no puede editar este comercio.',
        reason: 'permission_denied',
      );
    } catch (_) {
      _setSaveError(
        message:
            'No pudimos guardar los cambios. Revisá tu conexión y probá de nuevo.',
        reason: 'network_or_backend_error',
      );
    }
  }

  void clearFeedback() {
    state = state.copyWith(
      saveStatus: OperationalSignalsSaveStatus.idle,
      clearMessage: true,
      clearValidationError: true,
    );
  }

  void _setSaveError({
    required String message,
    required String reason,
  }) {
    state = state.copyWith(
      isSaving: false,
      saveStatus: OperationalSignalsSaveStatus.error,
      message: message,
    );
    unawaited(OwnerOperationalSignalsAnalytics.logSaveFailed(
      merchantId: state.merchantId,
      reason: reason,
      payload: OperationalSignalsAnalyticsPayload(
        signalType: state.draftSignalType,
        hasMessage: state.draftMessage.trim().isNotEmpty,
        hasEndDate: false,
      ),
    ));
  }

  Future<void> _refreshSignalFromRepositoryBestEffort() async {
    try {
      final refreshed =
          await _repository.fetchSignal(merchantId: state.merchantId);
      if (refreshed == null) return;
      state = state.copyWith(
        currentSignal: refreshed,
        draftSignalType: refreshed.hasActiveSignal
            ? refreshed.signalType
            : OperationalSignalType.none,
        draftMessage: refreshed.message ?? '',
        lastSuccessfulSaveAt: refreshed.updatedAt ?? state.lastSuccessfulSaveAt,
      );
    } on OwnerOperationalSignalsUnauthorizedException {
      // No degradamos el save si falla el refresh post-write.
    } catch (_) {
      // Best-effort: evita falsos negativos de guardado por fallas de lectura.
    }
  }
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
