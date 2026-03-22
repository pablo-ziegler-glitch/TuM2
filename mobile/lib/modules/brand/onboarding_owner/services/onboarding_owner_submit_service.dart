import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';

import '../repositories/onboarding_owner_repository.dart';

/// Estados del submit del onboarding.
enum SubmitState { idle, loading, success, networkError }

/// SL-02 — OnboardingOwnerSubmitService
///
/// Llama la CF `onboardingOwnerSubmit` vía Firebase Callable Functions.
/// Gestiona los estados: idle → loading (EX-05) → success (EX-06) | networkError (EX-07).
/// En éxito: llama `OnboardingOwnerRepository.markCompleted()`.
class OnboardingOwnerSubmitService {
  final FirebaseFunctions _functions;
  final OnboardingOwnerRepository _repository;

  final _stateController = StreamController<SubmitState>.broadcast();

  SubmitState _currentState = SubmitState.idle;

  OnboardingOwnerSubmitService({
    FirebaseFunctions? functions,
    required OnboardingOwnerRepository repository,
  })  : _functions = functions ?? FirebaseFunctions.instance,
        _repository = repository;

  Stream<SubmitState> get stateStream => _stateController.stream;
  SubmitState get currentState => _currentState;

  /// Llama la CF onboardingOwnerSubmit y maneja el ciclo de vida del submit.
  Future<void> submit(String draftMerchantId) async {
    if (_currentState == SubmitState.loading) return;

    _emit(SubmitState.loading);

    try {
      final callable = _functions.httpsCallable('onboardingOwnerSubmit');
      await callable.call({'draftMerchantId': draftMerchantId});

      await _repository.markCompleted();
      _emit(SubmitState.success);
    } on FirebaseFunctionsException catch (e) {
      // Errores de validación/lógica de negocio (not network)
      if (e.code == 'invalid-argument' ||
          e.code == 'failed-precondition' ||
          e.code == 'permission-denied') {
        rethrow;
      }
      _emit(SubmitState.networkError);
    } catch (_) {
      _emit(SubmitState.networkError);
    }
  }

  void reset() => _emit(SubmitState.idle);

  void _emit(SubmitState state) {
    _currentState = state;
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }

  void dispose() => _stateController.close();
}
