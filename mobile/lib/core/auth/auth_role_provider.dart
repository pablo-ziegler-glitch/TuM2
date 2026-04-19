import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_providers.dart';

/// Provider que lee el rol del usuario desde el custom claim del idToken.
///
/// NUNCA lee Firestore. Lee exclusivamente del idToken claim.
/// Evita force refresh para no duplicar costo de red; el refresh forzado
/// se centraliza en AuthNotifier al cambiar la sesión.
///
/// Uso:
///   final role = ref.watch(authRoleProvider).valueOrNull;
final authRoleProvider = FutureProvider<String?>((ref) async {
  // Escuchar cambios de sesión para re-evaluar cuando cambia el usuario
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  final idTokenResult = await user.getIdTokenResult();
  return idTokenResult.claims?['role'] as String?;
});
