import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_notifier.dart';
import '../../../core/auth/auth_state.dart';
import '../models/owner_merchant_summary.dart';
import '../repositories/owner_repository.dart';

final ownerRepositoryProvider = Provider<OwnerRepository>((ref) {
  return OwnerRepository();
});

/// Comercio privado del owner autenticado.
///
/// - Consulta exclusivamente `merchants`
/// - Resuelve por `ownerUserId == auth.uid`
/// - No depende de parámetros de ruta ni merchantId inyectado por cliente
final ownerMerchantProvider =
    FutureProvider<OwnerMerchantResolution>((ref) async {
  final authState = ref.watch(authNotifierProvider).authState;
  if (authState is! AuthAuthenticated) {
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
  return repository.resolveOwnerMerchant(authState.user.uid);
});
