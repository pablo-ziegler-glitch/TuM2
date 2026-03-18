import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/schedule_repository.dart';
import '../../data/signal_repository.dart';
import '../../data/store_repository.dart';
import '../../domain/store_model.dart';
import '../../domain/schedule_model.dart';
import '../../domain/signal_model.dart';

// ── Repositories ─────────────────────────────────────────────────────────────

final storeRepositoryProvider = Provider<StoreRepository>((ref) {
  return StoreRepository();
});

final scheduleRepositoryProvider = Provider<ScheduleRepository>((ref) {
  return ScheduleRepository();
});

final signalRepositoryProvider = Provider<SignalRepository>((ref) {
  return SignalRepository();
});

// ── Store streams ─────────────────────────────────────────────────────────────

/// Streams all stores for the current authenticated owner.
final ownerStoresProvider = StreamProvider<List<StoreModel>>((ref) {
  final user = ref.watch(currentFirebaseUserProvider);
  if (user == null) return Stream.value([]);

  return ref.watch(storeRepositoryProvider).watchOwnerStores(user.uid);
});

/// Streams a specific store by ID.
final storeDetailProvider =
    StreamProvider.family<StoreModel?, String>((ref, storeId) {
  return ref.watch(storeRepositoryProvider).watchStore(storeId);
});

/// Streams the weekly schedule for a store.
final scheduleProvider =
    StreamProvider.family<WeeklyScheduleModel?, String>((ref, storeId) {
  return ref.watch(scheduleRepositoryProvider).watchSchedule(storeId);
});

/// Streams operational signals for a store.
final signalsProvider =
    StreamProvider.family<List<OperationalSignalModel>, String>(
        (ref, storeId) {
  return ref.watch(signalRepositoryProvider).watchSignals(storeId);
});

// ── Store creation notifier ───────────────────────────────────────────────────

class StoreFormState {
  final String name;
  final String category;
  final String description;
  final String address;
  final double? lat;
  final double? lng;
  final String neighborhood;
  final String locality;
  final String? imageUrl;
  final bool isLoading;
  final String? error;

  const StoreFormState({
    this.name = '',
    this.category = '',
    this.description = '',
    this.address = '',
    this.lat,
    this.lng,
    this.neighborhood = '',
    this.locality = '',
    this.imageUrl,
    this.isLoading = false,
    this.error,
  });

  bool get isValid =>
      name.isNotEmpty && category.isNotEmpty && address.isNotEmpty;

  StoreFormState copyWith({
    String? name,
    String? category,
    String? description,
    String? address,
    double? lat,
    double? lng,
    String? neighborhood,
    String? locality,
    String? imageUrl,
    bool? isLoading,
    String? error,
  }) =>
      StoreFormState(
        name: name ?? this.name,
        category: category ?? this.category,
        description: description ?? this.description,
        address: address ?? this.address,
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        neighborhood: neighborhood ?? this.neighborhood,
        locality: locality ?? this.locality,
        imageUrl: imageUrl ?? this.imageUrl,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class StoreFormNotifier extends StateNotifier<StoreFormState> {
  final StoreRepository _repo;
  final String _ownerId;

  StoreFormNotifier(this._repo, this._ownerId) : super(const StoreFormState());

  void update(StoreFormState Function(StoreFormState) updater) {
    state = updater(state);
  }

  Future<String?> submit() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final now = DateTime.now();
      final store = StoreModel(
        id: '',
        ownerId: _ownerId,
        name: state.name,
        slug: '',
        category: state.category,
        description: state.description,
        imageUrl: state.imageUrl ?? '',
        address: state.address,
        geo: state.lat != null
            ? GeoPoint(state.lat!, state.lng!)
            : const GeoPoint(0, 0),
        geohash: '', // Will be set by Cloud Function
        neighborhood: state.neighborhood,
        locality: state.locality,
        visibilityStatus: 'active',
        createdAt: now,
        updatedAt: now,
      );

      final id = await _repo.createStore(store);
      state = state.copyWith(isLoading: false);
      return id;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'No se pudo guardar el comercio. Intentá de nuevo.',
      );
      return null;
    }
  }
}

final storeFormNotifierProvider =
    StateNotifierProvider.autoDispose<StoreFormNotifier, StoreFormState>((ref) {
  final user = ref.watch(currentFirebaseUserProvider);
  return StoreFormNotifier(
    ref.watch(storeRepositoryProvider),
    user?.uid ?? '',
  );
});
