import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_notifier.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/providers/auth_providers.dart';
import '../models/owner_merchant_summary.dart';
import '../models/operational_signals.dart';
import '../repositories/owner_repository.dart';

final ownerRepositoryProvider = Provider<OwnerRepository>((ref) {
  return OwnerRepository();
});

final ownerAuthStateProvider = Provider<AuthState>((ref) {
  return ref.watch(authNotifierProvider).authState;
});

const _ownerSelectedMerchantPrefsKey = 'owner_selected_merchant_id';

final ownerSelectedMerchantIdProvider =
    AsyncNotifierProvider<OwnerSelectedMerchantIdNotifier, String?>(
  OwnerSelectedMerchantIdNotifier.new,
);

class OwnerSelectedMerchantIdNotifier extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async {
    try {
      final prefs = await ref.read(sharedPreferencesProvider);
      final value = prefs.getString(_ownerSelectedMerchantPrefsKey)?.trim();
      if (value == null || value.isEmpty) return null;
      return value;
    } catch (_) {
      return null;
    }
  }

  Future<void> setSelectedMerchantId(String? merchantId) async {
    final normalized = merchantId?.trim();
    state = AsyncData(
      (normalized == null || normalized.isEmpty) ? null : normalized,
    );
    final prefs = await ref.read(sharedPreferencesProvider);
    if (normalized == null || normalized.isEmpty) {
      await prefs.remove(_ownerSelectedMerchantPrefsKey);
      return;
    }
    await prefs.setString(_ownerSelectedMerchantPrefsKey, normalized);
  }
}

/// Comercio privado del owner autenticado.
///
/// - Consulta exclusivamente `merchants`
/// - Resuelve por `ownerUserId == auth.uid`
/// - No depende de parámetros de ruta ni merchantId inyectado por cliente
final ownerMerchantProvider =
    FutureProvider<OwnerMerchantResolution>((ref) async {
  final authState = ref.watch(ownerAuthStateProvider);
  if (authState is! AuthAuthenticated) {
    return const OwnerMerchantResolution(
      primaryMerchant: null,
      allMerchants: [],
    );
  }

  // Admin/super_admin no dependen de merchant propio para navegar OWNER.
  if (_isAdminRole(authState.role)) {
    return const OwnerMerchantResolution(
      primaryMerchant: null,
      allMerchants: [],
    );
  }

  if (authState.role != 'owner') {
    return const OwnerMerchantResolution(
      primaryMerchant: null,
      allMerchants: [],
    );
  }

  final accessSummary = authState.ownerAccessSummary;
  final hasApprovedMerchants =
      (accessSummary?.approvedMerchantIdsCount ?? 0) > 0 ||
          authState.merchantId != null;
  if (!hasApprovedMerchants) {
    return const OwnerMerchantResolution(
      primaryMerchant: null,
      allMerchants: [],
    );
  }
  if (accessSummary?.restrictionActive == true) {
    return const OwnerMerchantResolution(
      primaryMerchant: null,
      allMerchants: [],
    );
  }

  String? selectedMerchantId;
  try {
    selectedMerchantId =
        await ref.watch(ownerSelectedMerchantIdProvider.future);
  } catch (_) {
    selectedMerchantId = null;
  }

  final repository = ref.watch(ownerRepositoryProvider);
  final resolution = await repository.resolveOwnerMerchant(
    authState.user.uid,
    preferredMerchantId: selectedMerchantId ??
        accessSummary?.defaultMerchantId ??
        authState.merchantId,
  );
  final resolvedPrimaryId = resolution.primaryMerchant?.id;
  if (resolvedPrimaryId != null && resolvedPrimaryId != selectedMerchantId) {
    unawaited(
      ref
          .read(ownerSelectedMerchantIdProvider.notifier)
          .setSelectedMerchantId(resolvedPrimaryId),
    );
  }
  return resolution;
});

final ownerOperationalSignalProvider =
    FutureProvider.autoDispose.family<OwnerOperationalSignal?, String>(
  (ref, merchantId) async {
    final repository = ref.watch(ownerRepositoryProvider);
    return repository.fetchOperationalSignal(merchantId: merchantId);
  },
);

bool _isAdminRole(String role) => role == 'admin' || role == 'super_admin';
