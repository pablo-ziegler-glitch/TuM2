import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_notifier.dart';
import '../../../core/auth/auth_state.dart';
import '../models/owner_merchant_summary.dart';
import '../models/operational_signals.dart';
import '../repositories/owner_repository.dart';

final ownerRepositoryProvider = Provider<OwnerRepository>((ref) {
  return OwnerRepository();
});

final ownerAuthStateProvider = Provider<AuthState>((ref) {
  return ref.watch(authNotifierProvider).authState;
});

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

  if (authState.role != 'owner' || authState.ownerPending) {
    return const OwnerMerchantResolution(
      primaryMerchant: null,
      allMerchants: [],
    );
  }

  final repository = ref.watch(ownerRepositoryProvider);
  return repository.resolveOwnerMerchant(
    authState.user.uid,
    preferredMerchantId: authState.merchantId,
  );
});

final ownerOperationalSignalProvider =
    FutureProvider.autoDispose.family<OwnerOperationalSignal?, String>(
  (ref, merchantId) async {
    final repository = ref.watch(ownerRepositoryProvider);
    return repository.fetchOperationalSignal(merchantId: merchantId);
  },
);

bool _isAdminRole(String role) => role == 'admin' || role == 'super_admin';
