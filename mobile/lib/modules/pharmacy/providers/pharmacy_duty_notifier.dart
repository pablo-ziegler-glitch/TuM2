import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/pharmacy_duty_item.dart';
import '../models/pharmacy_zone.dart';
import '../repositories/pharmacy_duty_repository.dart';
import '../repositories/zones_repository.dart';
import '../services/distance_calculator.dart';
import '../services/geo_location_service.dart';

// ── Orden de la lista ─────────────────────────────────────────────────────────

/// Criterio de ordenamiento de la lista de farmacias de turno.
enum PharmacyDutySortOrder {
  /// Ordenar por distancia al usuario (más cercana primero).
  byDistance,
  /// Ordenar por nivel de confianza (más confiable primero).
  byTrust,
}

// ── Estado del notifier ───────────────────────────────────────────────────────

/// Estado interno del [PharmacyDutyNotifier].
class PharmacyDutyState {
  /// Lista de turnos ordenada según [sortOrder].
  final AsyncValue<List<PharmacyDutyItem>> duties;

  /// Zona actualmente activa.
  final String zoneId;

  /// Criterio de ordenamiento actual.
  final PharmacyDutySortOrder sortOrder;

  /// Posición del usuario (null si no está disponible).
  final ({double lat, double lng})? userPosition;

  const PharmacyDutyState({
    required this.duties,
    required this.zoneId,
    required this.sortOrder,
    this.userPosition,
  });

  PharmacyDutyState copyWith({
    AsyncValue<List<PharmacyDutyItem>>? duties,
    String? zoneId,
    PharmacyDutySortOrder? sortOrder,
    ({double lat, double lng})? userPosition,
    bool clearUserPosition = false,
  }) {
    return PharmacyDutyState(
      duties: duties ?? this.duties,
      zoneId: zoneId ?? this.zoneId,
      sortOrder: sortOrder ?? this.sortOrder,
      userPosition: clearUserPosition ? null : (userPosition ?? this.userPosition),
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────

/// Notifier principal de la vista Farmacias de turno.
///
/// Responsabilidades:
/// - Obtener la posición GPS del usuario (con fallback a zona manual)
/// - Cargar pharmacy_duties desde Firestore para una zona dada
/// - Calcular distancias Haversine en cliente
/// - Reordenar en cliente (sin nueva query) según el criterio activo
/// - Exponer el estado para que [PharmacyDutyScreen] lo consuma
class PharmacyDutyNotifier extends StateNotifier<PharmacyDutyState> {
  final PharmacyDutyRepository _repository;
  final GeoLocationService _geoService;

  PharmacyDutyNotifier({
    PharmacyDutyRepository? repository,
    GeoLocationService? geoService,
    required String initialZoneId,
  })  : _repository = repository ?? PharmacyDutyRepository(),
        _geoService = geoService ?? GeoLocationService(),
        super(PharmacyDutyState(
          duties: const AsyncLoading(),
          zoneId: initialZoneId,
          sortOrder: PharmacyDutySortOrder.byDistance,
        ));

  // ── Carga inicial ─────────────────────────────────────────────────────────

  /// Solicita GPS y carga los turnos de la zona activa.
  ///
  /// Si el GPS no está disponible, el caller debe mostrar el selector de zona
  /// y luego llamar a [loadForZone] con el zoneId seleccionado.
  Future<GeoPositionResult> requestPositionAndLoad() async {
    final result = await _geoService.getPosition();
    if (result is GeoPositionOk) {
      state = state.copyWith(
        userPosition: (lat: result.lat, lng: result.lng),
      );
    }
    await _loadDuties();
    return result;
  }

  /// Carga los turnos para una zona específica (vía selección manual).
  Future<void> loadForZone(String zoneId) async {
    state = state.copyWith(
      zoneId: zoneId,
      duties: const AsyncLoading(),
    );
    await _loadDuties();
  }

  // ── Refresh ───────────────────────────────────────────────────────────────

  /// Recarga los datos desde Firestore sin cambiar zona ni posición.
  Future<void> refresh() async {
    state = state.copyWith(duties: const AsyncLoading());
    await _loadDuties();
  }

  // ── Ordenamiento (cliente, sin nueva query) ───────────────────────────────

  /// Reordena la lista por distancia al usuario (más cercana primero).
  /// No-op si ya está ordenado por distancia o si la lista está vacía.
  void sortByDistance() {
    if (state.sortOrder == PharmacyDutySortOrder.byDistance) return;
    final current = state.duties.valueOrNull;
    if (current == null || current.isEmpty) return;

    final sorted = List<PharmacyDutyItem>.from(current)
      ..sort((a, b) {
        final da = a.distanceMeters ?? 999999;
        final db = b.distanceMeters ?? 999999;
        return da.compareTo(db);
      });

    state = state.copyWith(
      duties: AsyncData(sorted),
      sortOrder: PharmacyDutySortOrder.byDistance,
    );
  }

  /// Reordena la lista por nivel de confianza (más confiable primero).
  /// No-op si ya está ordenado por confianza o si la lista está vacía.
  void sortByTrust() {
    if (state.sortOrder == PharmacyDutySortOrder.byTrust) return;
    final current = state.duties.valueOrNull;
    if (current == null || current.isEmpty) return;

    final sorted = List<PharmacyDutyItem>.from(current)
      ..sort((a, b) {
        final ta = _trustRank(a.trustLevel);
        final tb = _trustRank(b.trustLevel);
        return ta.compareTo(tb);
      });

    state = state.copyWith(
      duties: AsyncData(sorted),
      sortOrder: PharmacyDutySortOrder.byTrust,
    );
  }

  // ── Internos ──────────────────────────────────────────────────────────────

  Future<void> _loadDuties() async {
    try {
      final items = await _repository.getDutiesForZone(state.zoneId);

      // Calcular distancias si hay posición del usuario disponible
      final pos = state.userPosition;
      if (pos != null) {
        for (final item in items) {
          if (item.lat != null && item.lng != null) {
            item.distanceMeters = DistanceCalculator.haversine(
              lat1: pos.lat,
              lng1: pos.lng,
              lat2: item.lat!,
              lng2: item.lng!,
            ).round();
          }
        }
        // Ordenar por distancia por defecto si hay posición
        items.sort((a, b) {
          final da = a.distanceMeters ?? 999999;
          final db = b.distanceMeters ?? 999999;
          return da.compareTo(db);
        });
      }

      state = state.copyWith(duties: AsyncData(items));
    } catch (e, st) {
      state = state.copyWith(duties: AsyncError(e, st));
    }
  }

  static int _trustRank(PharmacyTrustLevel level) {
    switch (level) {
      case PharmacyTrustLevel.official:
        return 0;
      case PharmacyTrustLevel.verified:
        return 1;
      case PharmacyTrustLevel.community:
        return 2;
      case PharmacyTrustLevel.unverified:
        return 3;
    }
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

/// Provider del notifier de farmacias de turno, parametrizado por zoneId.
///
/// El caller debe conocer el zoneId antes de crear este provider.
/// Para obtenerlo: usar [GeoLocationService] + lógica de zona, o selector manual.
final pharmacyDutyNotifierProvider = StateNotifierProvider.autoDispose
    .family<PharmacyDutyNotifier, PharmacyDutyState, String>(
  (ref, zoneId) => PharmacyDutyNotifier(initialZoneId: zoneId),
);

/// Provider de zonas activas para el selector manual.
final activeZonesProvider =
    FutureProvider.autoDispose<List<PharmacyZone>>((ref) async {
  return ZonesRepository().getActiveZones();
});
