import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../store/domain/store_model.dart';
import '../../data/discover_repository.dart';
import '../../domain/discover_filters.dart';

final discoverRepositoryProvider = Provider<DiscoverRepository>((ref) {
  return DiscoverRepository();
});

/// Current filter state for the discover screen.
final discoverFiltersProvider =
    StateProvider<DiscoverFilters>((ref) => const DiscoverFilters());

/// Stream of stores matching current filters.
final discoverStoresProvider = StreamProvider<List<StoreModel>>((ref) {
  final filters = ref.watch(discoverFiltersProvider);
  return ref.watch(discoverRepositoryProvider).watchStores(filters);
});
