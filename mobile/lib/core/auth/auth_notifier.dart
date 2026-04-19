import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_state.dart';

/// Notifier reactivo sobre el estado de autenticación de Firebase.
///
/// Extiende [ChangeNotifier] para ser compatible como [GoRouter.refreshListenable].
/// Escucha [FirebaseAuth.authStateChanges] y extrae el rol del usuario
/// desde los custom claims del JWT. Si los claims no están disponibles
/// (race condition post-registro), fuerza un refresh del token. Como
/// último recurso, lee el rol desde Firestore.
class AuthNotifier extends ChangeNotifier {
  AuthState _authState = const AuthLoading();
  AuthState get authState => _authState;

  /// Contador de versión para descartar resultados de eventos de auth obsoletos.
  int _eventVersion = 0;

  StreamSubscription<User?>? _authSub;

  AuthNotifier() {
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onUserChanged);
  }

  Future<void> _onUserChanged(User? user) async {
    final version = ++_eventVersion;

    if (user == null) {
      _authState = const AuthUnauthenticated();
      notifyListeners();
      return;
    }

    try {
      // Forzar refresh para garantizar claims actualizados post-login.
      final tokenResult = await user.getIdTokenResult(true);
      String? role = (tokenResult.claims?['role'] as String?)?.toLowerCase();
      String? merchantId = tokenResult.claims?['merchantId'] as String?;
      bool? onboardingComplete =
          tokenResult.claims?['onboardingComplete'] as bool?;
      final ownerPendingClaimAvailable =
          tokenResult.claims?.containsKey('owner_pending') == true;
      var ownerPending =
          _parseOwnerPending(tokenResult.claims?['owner_pending']);

      // Fallback a Firestore si los claims vienen parciales.
      if (role == null || merchantId == null || !ownerPendingClaimAvailable) {
        final data = await _fetchUserDataFromFirestore(user.uid);
        role ??= data.role?.toLowerCase();
        merchantId ??= data.merchantId;
        if (!ownerPendingClaimAvailable && data.ownerPending != null) {
          ownerPending = data.ownerPending!;
        }
      }

      // Descartar resultado si llegó un evento de auth más reciente durante los awaits
      if (version != _eventVersion) return;

      // Principio de menor privilegio: rol desconocido → customer
      // onboardingComplete: usar claim si existe, fallback a merchantId != null
      _authState = AuthAuthenticated(
        user: user,
        role: role ?? 'customer',
        merchantId: merchantId,
        onboardingComplete: onboardingComplete ?? (merchantId != null),
        ownerPending: ownerPending,
      );
    } catch (_) {
      if (version != _eventVersion) return;
      // Error de red o Firebase: autenticar con rol mínimo para no bloquear al usuario
      _authState = AuthAuthenticated(
        user: user,
        role: 'customer',
        merchantId: null,
        onboardingComplete: false,
        ownerPending: false,
      );
    }

    notifyListeners();
  }

  /// Lee role y merchantId del documento users/$uid en una sola lectura.
  Future<({String? role, String? merchantId, bool? ownerPending})>
      _fetchUserDataFromFirestore(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.doc('users/$uid').get();
      if (!doc.exists) {
        return (role: null, merchantId: null, ownerPending: null);
      }
      final data = doc.data();
      final ownerPendingRaw = data?['ownerPending'];
      final ownerPending = ownerPendingRaw is bool
          ? ownerPendingRaw
          : ownerPendingRaw is String
              ? ownerPendingRaw.toLowerCase() == 'true'
              : null;
      return (
        role: data?['role'] as String?,
        merchantId: data?['merchantId'] as String?,
        ownerPending: ownerPending,
      );
    } catch (_) {
      return (role: null, merchantId: null, ownerPending: null);
    }
  }

  bool _parseOwnerPending(Object? rawValue) {
    if (rawValue is bool) return rawValue;
    if (rawValue is String) {
      return rawValue.toLowerCase() == 'true';
    }
    return false;
  }

  /// Fuerza el estado a [AuthUnauthenticated] e invalida cualquier lookup
  /// async en vuelo. Usado por [SplashScreen] cuando Firebase no responde
  /// en el tiempo límite.
  void forceUnauthenticated() {
    _eventVersion++;
    _authState = const AuthUnauthenticated();
    notifyListeners();
  }

  /// Fuerza una relectura del token/claims del usuario actual.
  /// Útil para transiciones de acceso sin relogin manual.
  Future<void> refreshSession() async {
    final user = FirebaseAuth.instance.currentUser;
    await _onUserChanged(user);
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}

/// Provider global del estado de autenticación.
/// No se descarta automáticamente (vive durante toda la sesión de la app).
final authNotifierProvider = ChangeNotifierProvider<AuthNotifier>((ref) {
  return AuthNotifier();
});
