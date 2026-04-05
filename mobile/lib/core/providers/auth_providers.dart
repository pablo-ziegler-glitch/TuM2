import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../analytics/auth_analytics.dart';

// ── Constantes ────────────────────────────────────────────────────────────────

const _kOnboardingSeenKey = 'onboarding_seen';
const _kPendingEmailLinkKey = 'pending_email_link';
const _kOnboardingOwnerDraftKey = 'onboarding_owner_draft';

/// URL base para magic links. En producción apunta al dominio real.
/// En desarrollo se puede usar el emulador de Auth.
const _kMagicLinkUrlOverride = String.fromEnvironment('MAGIC_LINK_URL');

String _resolveMagicLinkUrl() {
  if (_kMagicLinkUrlOverride.isNotEmpty) {
    return _kMagicLinkUrlOverride;
  }
  if (kIsWeb) {
    return '${Uri.base.origin}/auth/verify';
  }
  return 'https://tum2.app/auth/verify';
}

// ── Stream de sesión ──────────────────────────────────────────────────────────

/// Stream del usuario autenticado. null = sin sesión.
final authStateProvider = StreamProvider<User?>(
  (ref) => FirebaseAuth.instance.authStateChanges(),
);

/// Retorna el usuario actual o null si no hay sesión.
final currentUserProvider = Provider<User?>(
  (ref) => ref.watch(authStateProvider).valueOrNull,
);

// ── Primer lanzamiento ────────────────────────────────────────────────────────

/// true si el usuario nunca vio el onboarding de bienvenida.
final isFirstLaunchProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return !(prefs.getBool(_kOnboardingSeenKey) ?? false);
});

/// Marca el onboarding como visto. Llamar desde AUTH-02 al salir.
Future<void> markOnboardingSeen() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kOnboardingSeenKey, true);
}

// ── DisplayName micro-step ────────────────────────────────────────────────────

/// true si el usuario eligió saltar el micro-step de displayName.
/// Se reinicia en false al hacer logout.
final displayNameSkippedProvider = StateProvider<bool>((ref) => false);

// ── Pending magic link (cross-device) ─────────────────────────────────────────

/// Guarda el magic link URI cuando se recibe en un dispositivo diferente
/// al que lo solicitó (no hay pending_email_link en SharedPreferences).
/// La pantalla AUTH-04 lo consume para procesar el link con email manual.
final pendingMagicLinkProvider = StateProvider<String?>((ref) => null);

// ── Toast post-autenticación ──────────────────────────────────────────────────

/// Mensaje de toast a mostrar tras login exitoso.
/// null = no hay toast pendiente.
/// main.dart lo escucha y muestra el SnackBar.
final pendingAuthToastProvider = StateProvider<String?>((ref) => null);

/// Estado de las operaciones de autenticación (magic link, Google sign-in).
/// Distinto de [AuthState] en core/auth/auth_state.dart que modela la sesión.
class AuthOpState {
  const AuthOpState({
    this.isLoading = false,
    this.errorMessage,
    this.emailSent = false,
  });

  final bool isLoading;
  final String? errorMessage;

  /// true cuando el magic link fue enviado exitosamente.
  final bool emailSent;

  AuthOpState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    bool? emailSent,
  }) {
    return AuthOpState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      emailSent: emailSent ?? this.emailSent,
    );
  }
}

/// Notifier principal de operaciones de autenticación.
/// Maneja magic link y Google Sign-In.
class AuthOpNotifier extends Notifier<AuthOpState> {
  @override
  AuthOpState build() => const AuthOpState();

  /// Envía el magic link al email indicado.
  /// Guarda el email en SharedPreferences para recuperarlo al procesar el link.
  Future<void> sendMagicLink(String email) async {
    state = state.copyWith(isLoading: true, clearError: true, emailSent: false);

    try {
      final settings = ActionCodeSettings(
        url: _resolveMagicLinkUrl(),
        handleCodeInApp: true,
        androidPackageName: 'com.tum2.app',
        androidInstallApp: true,
        androidMinimumVersion: '21',
        iOSBundleId: 'com.tum2.app',
      );

      await FirebaseAuth.instance.sendSignInLinkToEmail(
        email: email,
        actionCodeSettings: settings,
      );

      // Persistir el email localmente para usarlo al procesar el link
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPendingEmailLinkKey, email);

      AuthAnalytics.logMagicLinkSent().ignore();
      state = state.copyWith(isLoading: false, emailSent: true);
    } on FirebaseAuthException catch (e) {
      AuthAnalytics.logMagicLinkError(e.code).ignore();
      state = state.copyWith(
        isLoading: false,
        errorMessage: _mapFirebaseError(e),
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'No pudimos conectarnos. Revisá tu conexión.',
      );
    }
  }

  /// Procesa el magic link recibido por deep link.
  ///
  /// [emailOverride] se usa en el caso cross-device: el usuario ingresa
  /// manualmente el email con el que pidió el link en otro dispositivo.
  Future<void> handleEmailLink(String link, {String? emailOverride}) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final email =
          emailOverride ?? prefs.getString(_kPendingEmailLinkKey) ?? '';

      if (email.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'No encontramos el email. Intentá reenviar el link.',
        );
        return;
      }

      if (!FirebaseAuth.instance.isSignInWithEmailLink(link)) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'El link no es válido o ya expiró.',
        );
        return;
      }

      final credential = await FirebaseAuth.instance.signInWithEmailLink(
        email: email,
        emailLink: link,
      );

      // Limpiar link pendiente tras auth exitosa
      await prefs.remove(_kPendingEmailLinkKey);

      // Limpiar link cross-device si había uno guardado
      ref.read(pendingMagicLinkProvider.notifier).state = null;

      // Programar toast de bienvenida
      _scheduleAuthToast(credential.user);

      AuthAnalytics.logMagicLinkVerified(
        isNewUser: _isNewUser(credential.user),
        isCrossDevice: emailOverride != null,
      ).ignore();

      state = state.copyWith(isLoading: false);
    } on FirebaseAuthException catch (e) {
      AuthAnalytics.logMagicLinkError(e.code).ignore();
      state = state.copyWith(
        isLoading: false,
        errorMessage: _mapFirebaseError(e),
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'No pudimos verificar el link. Intentá de nuevo.',
      );
    }
  }

  /// Inicia sesión con Google.
  Future<void> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      UserCredential result;

      if (kIsWeb) {
        // En web usamos signInWithPopup (no requiere el paquete google_sign_in)
        result = await FirebaseAuth.instance
            .signInWithPopup(GoogleAuthProvider());
      } else {
        final googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) {
          // Usuario canceló
          state = state.copyWith(isLoading: false);
          return;
        }

        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        result = await FirebaseAuth.instance.signInWithCredential(credential);
      }

      // Programar toast de bienvenida
      _scheduleAuthToast(result.user);

      AuthAnalytics.logGoogleSignIn(
        isNewUser: _isNewUser(result.user),
      ).ignore();

      state = state.copyWith(isLoading: false);
    } on FirebaseAuthException catch (e) {
      AuthAnalytics.logGoogleSignInError(e.code).ignore();
      state = state.copyWith(
        isLoading: false,
        errorMessage: _mapFirebaseError(e),
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'No pudimos conectar con Google. Intentá de nuevo.',
      );
    }
  }

  /// Cierra la sesión actual ejecutando las 3 acciones obligatorias en orden.
  ///
  /// Si alguna acción falla, se registra el error pero se continúa con las
  /// siguientes (no hacer rollback del logout).
  Future<void> signOut() async {
    // Evento analytics antes de cerrar la sesión (el uid todavía está disponible)
    AuthAnalytics.logSignOut().ignore();

    // Acción 1: cerrar sesión en Firebase Auth
    try {
      await FirebaseAuth.instance.signOut();
      await GoogleSignIn().signOut();
    } catch (e) {
      // Loguear pero continuar
      // ignore: avoid_print
      print('[AuthNotifier.signOut] Error en Firebase signOut: $e');
    }

    // Acción 2: limpiar SharedPreferences (no limpiar onboarding_seen)
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.remove(_kPendingEmailLinkKey),
        prefs.remove(_kOnboardingOwnerDraftKey),
      ]);
    } catch (e) {
      // ignore: avoid_print
      print('[AuthNotifier.signOut] Error limpiando SharedPreferences: $e');
    }

    // Acción 3: invalidar providers de estado de usuario en Riverpod
    try {
      ref.invalidate(isOwnerProvider);
      ref.read(displayNameSkippedProvider.notifier).state = false;
      ref.read(pendingMagicLinkProvider.notifier).state = null;
      ref.read(pendingAuthToastProvider.notifier).state = null;
    } catch (e) {
      // ignore: avoid_print
      print('[AuthNotifier.signOut] Error invalidando providers: $e');
    }
  }

  /// Retorna true si existe un pending_email_link guardado en SharedPreferences.
  /// Usado para detectar el caso cross-device del magic link.
  Future<bool> hasPendingEmailLink() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_kPendingEmailLinkKey);
    return email != null && email.isNotEmpty;
  }

  /// Limpia el error visible sin cambiar otro estado.
  void clearError() => state = state.copyWith(clearError: true);

  /// Retorna true si el usuario se acaba de registrar (primer login).
  /// Aproximación: diferencia entre createdAt y lastSignInTime < 10 segundos.
  bool _isNewUser(User? user) {
    if (user == null) return false;
    final createdAt = user.metadata.creationTime;
    final lastSignIn = user.metadata.lastSignInTime;
    return createdAt != null &&
        lastSignIn != null &&
        lastSignIn.difference(createdAt).abs().inSeconds < 10;
  }

  /// Programa el toast de bienvenida según si el usuario es nuevo o existente.
  /// Aproximación: si createdAt ≈ lastSignInTime → usuario nuevo.
  void _scheduleAuthToast(User? user) {
    if (user == null) return;

    final isNewUser = _isNewUser(user);
    final name = user.displayName?.split(' ').first ?? '';
    final message = isNewUser
        ? '¡Bienvenido a TuM2!'
        : '¡Hola de nuevo${name.isNotEmpty ? ', $name' : ''}!';

    ref.read(pendingAuthToastProvider.notifier).state = message;
  }

  String _mapFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'El email no es válido.';
      case 'user-disabled':
        return 'Esta cuenta está deshabilitada.';
      case 'expired-action-code':
        return 'El link expiró. Pedí uno nuevo.';
      case 'invalid-action-code':
        return 'El link no es válido o ya fue usado.';
      case 'network-request-failed':
        return 'Sin conexión. Revisá tu red.';
      default:
        return 'Algo salió mal. Intentá de nuevo.';
    }
  }
}

final authOpProvider =
    NotifierProvider<AuthOpNotifier, AuthOpState>(AuthOpNotifier.new);

/// true si el usuario autenticado tiene el claim role='owner' en Firebase Auth.
/// Usa forceRefresh: true para garantizar datos actualizados tras asignación de rol.
final isOwnerProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;
  final result = await user.getIdTokenResult(true);
  return result.claims?['role'] == 'owner';
});

/// true si el usuario autenticado tiene el claim role='admin' o 'super_admin'.
/// Usa forceRefresh: true para garantizar datos actualizados tras asignación de rol.
final isAdminProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;
  final result = await user.getIdTokenResult(true);
  final role = result.claims?['role'] as String?;
  return role == 'admin' || role == 'super_admin';
});

// ── Provider de merchantId del owner ─────────────────────────────────────────

/// merchantId del comercio del owner autenticado.
/// Lee desde Firestore merchants collection (query por ownerUserId).
/// Null si el usuario no es owner o aún no completó el onboarding.
final ownerMerchantIdProvider = FutureProvider<String?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('merchants')
        .where('ownerUserId', isEqualTo: user.uid)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return snapshot.docs.first.id;
  } catch (_) {
    return null;
  }
});
