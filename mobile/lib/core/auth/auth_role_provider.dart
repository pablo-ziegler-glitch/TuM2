import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_providers.dart';

/// Provider que lee el rol del usuario desde el custom claim del idToken.
///
/// NUNCA lee Firestore. Lee exclusivamente del idToken claim.
/// Usa forceRefresh: true para garantizar que el claim 'role' esté disponible
/// incluso en el primer login (la CF onUserCreate puede tardar unos segundos
/// en propagarlo).
///
/// Uso:
///   final role = ref.watch(authRoleProvider).valueOrNull;
final authRoleProvider = FutureProvider<String?>((ref) async {
  // Escuchar cambios de sesión para re-evaluar cuando cambia el usuario
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  // forceRefresh: true garantiza que el claim 'role' está disponible
  // incluso en el primer login (race condition post-registro).
  final idTokenResult = await user.getIdTokenResult(true);
  return idTokenResult.claims?['role'] as String?;
});
