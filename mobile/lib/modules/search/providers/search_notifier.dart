import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/merchant_search_repository.dart';
import '../repositories/zone_search_repository.dart';

final searchNotifierProvider =
    StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  return SearchNotifier(
    merchantRepository: MerchantSearchRepository(),
    zoneRepository: ZoneSearchRepository(),
  );
});

class SearchState {
  const SearchState({
    this.activeZoneId = '',
    this.error,
  });

  final String activeZoneId;
  final Object? error;

  SearchState copyWith({
    String? activeZoneId,
    Object? error,
    bool clearError = false,
  }) {
    return SearchState(
      activeZoneId: activeZoneId ?? this.activeZoneId,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class SearchNotifier extends StateNotifier<SearchState> {
  SearchNotifier({
    required MerchantSearchRepository merchantRepository,
    required ZoneSearchRepository zoneRepository,
  })  : _merchantRepository = merchantRepository,
        _zoneRepository = zoneRepository,
        super(const SearchState());

  final MerchantSearchRepository _merchantRepository;
  final ZoneSearchRepository _zoneRepository;

  Future<void> ensureInitialized() async {
    await _bootstrapZoneAndCorpus();
  }

  Future<void> _bootstrapZoneAndCorpus() async {
    state = state.copyWith(clearError: true);

    try {
      final zones = await _zoneRepository.fetchAvailableZones();
      if (zones.isNotEmpty) {
        state = state.copyWith(activeZoneId: zones.first.zoneId);
      } else {
        state = state.copyWith(error: StateError('No hay zonas disponibles.'));
        return;
      }
    } catch (error) {
      state = state.copyWith(error: error);
      return;
    }

    try {
      await _merchantRepository.fetchZoneCorpus(zoneId: state.activeZoneId);
    } catch (error) {
      state = state.copyWith(error: error);
    }
  }
}
