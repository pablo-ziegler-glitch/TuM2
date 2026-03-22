import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';

/// Estado del check de duplicados.
enum DuplicateState {
  none,   // Sin duplicados
  soft,   // EX-13: warning naranja, flujo no bloqueado
  hard,   // EX-14: interstitial bloqueante
}

/// Datos de un comercio candidato a duplicado.
class DuplicateCandidate {
  final String id;
  final String name;
  final String address;
  final String? ownerUserId;

  const DuplicateCandidate({
    required this.id,
    required this.name,
    required this.address,
    this.ownerUserId,
  });
}

/// SL-05 — DuplicateCheckService
///
/// Llama la CF `checkMerchantDuplicates` con debounce de 800ms.
/// Expone el estado actual como Stream<DuplicateState>.
/// Se usa en el step 1 del onboarding al escribir el nombre del comercio.
class DuplicateCheckService {
  final FirebaseFunctions _functions;

  Timer? _debounceTimer;
  final _stateController = StreamController<DuplicateState>.broadcast();
  DuplicateState _currentState = DuplicateState.none;
  List<DuplicateCandidate> _candidates = [];

  static const Duration _debounceDuration = Duration(milliseconds: 800);

  DuplicateCheckService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  Stream<DuplicateState> get stateStream => _stateController.stream;
  DuplicateState get currentState => _currentState;
  List<DuplicateCandidate> get candidates => _candidates;

  /// Programa un check con debounce de 800ms.
  /// Llamar cada vez que el nombre cambia en el step 1.
  /// [zoneId] puede ser null si todavía no se seleccionó dirección (se omite el check).
  void checkName({
    required String name,
    required double lat,
    required double lng,
    required String zoneId,
  }) {
    _debounceTimer?.cancel();
    if (name.trim().length < 2) {
      _emit(DuplicateState.none, []);
      return;
    }

    _debounceTimer = Timer(_debounceDuration, () {
      _performCheck(name: name, lat: lat, lng: lng, zoneId: zoneId);
    });
  }

  Future<void> _performCheck({
    required String name,
    required double lat,
    required double lng,
    required String zoneId,
  }) async {
    try {
      final callable = _functions.httpsCallable('checkMerchantDuplicates');
      final result = await callable.call({
        'name': name,
        'lat': lat,
        'lng': lng,
        'zoneId': zoneId,
      });

      final data = result.data as Map<String, dynamic>;
      final hasSoft = data['hasSoftDuplicate'] == true;
      final hasHard = data['hasHardDuplicate'] == true;
      final rawCandidates = (data['candidates'] as List<dynamic>?) ?? [];

      final parsedCandidates = rawCandidates.map((c) {
        final map = c as Map<String, dynamic>;
        return DuplicateCandidate(
          id: map['id'] as String,
          name: map['name'] as String,
          address: map['address'] as String? ?? '',
          ownerUserId: map['ownerUserId'] as String?,
        );
      }).toList();

      if (hasHard) {
        _emit(DuplicateState.hard, parsedCandidates);
      } else if (hasSoft) {
        _emit(DuplicateState.soft, parsedCandidates);
      } else {
        _emit(DuplicateState.none, []);
      }
    } catch (_) {
      // En caso de error de red, no bloquear el flujo — ignorar el check
      _emit(DuplicateState.none, []);
    }
  }

  void reset() => _emit(DuplicateState.none, []);

  void _emit(DuplicateState state, List<DuplicateCandidate> candidates) {
    _currentState = state;
    _candidates = candidates;
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }

  void dispose() {
    _debounceTimer?.cancel();
    _stateController.close();
  }
}
