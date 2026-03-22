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
      // Intentar leer custom claims del token actual
      var tokenResult = await user.getIdTokenResult(forceRefresh: false);
      String? role = tokenResult.claims?['role'] as String?;
      String? merchantId = tokenResult.claims?['merchantId'] as String?;
      bool? onboardingComplete =
          tokenResult.claims?['onboardingComplete'] as bool?;

      // Race condition post-registro: si el claim no existe, forzar refresh
      if (role == null) {
        tokenResult = await user.getIdTokenResult(forceRefresh: true);
        role = tokenResult.claims?['role'] as String?;
        merchantId = tokenResult.claims?['merchantId'] as String?;
        onboardingComplete =
            tokenResult.claims?['onboardingComplete'] as bool?;
      }

      // Fallback a Firestore si los claims siguen sin estar presentes
      if (role == null) {
        role = await _fetchRoleFromFirestore(user.uid);
        merchantId = await _fetchMerchantIdFromFirestore(user.uid);
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
      );
    } catch (_) {
      if (version != _eventVersion) return;
      // Error de red o Firebase: autenticar con rol mínimo para no bloquear al usuario
      _authState = AuthAuthenticated(
        user: user,
        role: 'customer',
        merchantId: null,
        onboardingComplete: false,
      );
    }

    notifyListeners();
  }

  Future<String?> _fetchRoleFromFirestore(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.doc('users/$uid').get();
      if (!doc.exists) return null;
      return (doc.data() as Map<String, dynamic>?)?['role'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _fetchMerchantIdFromFirestore(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.doc('users/$uid').get();
      if (!doc.exists) return null;
      return (doc.data() as Map<String, dynamic>?)?['merchantId'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Fuerza el estado a [AuthUnauthenticated] e invalida cualquier lookup
  /// async en vuelo. Usado por [SplashScreen] cuando Firebase no responde
  /// en el tiempo límite.
  void forceUnauthenticated() {
    _eventVersion++;
    _authState = const AuthUnauthenticated();
    notifyListeners();
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
