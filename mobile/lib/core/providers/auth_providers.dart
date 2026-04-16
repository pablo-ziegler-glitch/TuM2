import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../analytics/auth_analytics.dart';
import '../firebase/app_environment.dart';
import '../router/pending_route_provider.dart';

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

// ── Dependencias inyectables (testeables) ────────────────────────────────────

/// Cliente de Firebase Auth usado por los flujos de autenticación.
final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

/// Cliente de Google Sign-In usado en mobile.
final googleSignInProvider = Provider<GoogleSignIn>((ref) => GoogleSignIn());

/// Acceso a SharedPreferences para persistencia local del flujo auth.
final sharedPreferencesProvider = Provider<Future<SharedPreferences>>(
  (ref) => SharedPreferences.getInstance(),
);

/// Contrato mínimo de autenticación usado por la capa de lógica.
/// Permite testear flujos AUTH sin depender de Firebase real.
abstract class AuthClient {
  Stream<User?> authStateChanges();

  Future<void> sendSignInLinkToEmail({
    required String email,
    required ActionCodeSettings actionCodeSettings,
  });

  bool isSignInWithEmailLink(String link);

  Future<UserCredential> signInWithEmailLink({
    required String email,
    required String emailLink,
  });

  Future<UserCredential> signInWithPopup(AuthProvider provider);

  Future<UserCredential> signInWithCredential(AuthCredential credential);

  Future<void> signOut();
}

class FirebaseAuthClient implements AuthClient {
  FirebaseAuthClient(this._firebaseAuth);

  final FirebaseAuth _firebaseAuth;

  @override
  Stream<User?> authStateChanges() => _firebaseAuth.authStateChanges();

  @override
  Future<void> sendSignInLinkToEmail({
    required String email,
    required ActionCodeSettings actionCodeSettings,
  }) {
    return _firebaseAuth.sendSignInLinkToEmail(
      email: email,
      actionCodeSettings: actionCodeSettings,
    );
  }

  @override
  bool isSignInWithEmailLink(String link) {
    return _firebaseAuth.isSignInWithEmailLink(link);
  }

  @override
  Future<UserCredential> signInWithEmailLink({
    required String email,
    required String emailLink,
  }) {
    return _firebaseAuth.signInWithEmailLink(
      email: email,
      emailLink: emailLink,
    );
  }

  @override
  Future<UserCredential> signInWithPopup(AuthProvider provider) {
    return _firebaseAuth.signInWithPopup(provider);
  }

  @override
  Future<UserCredential> signInWithCredential(AuthCredential credential) {
    return _firebaseAuth.signInWithCredential(credential);
  }

  @override
  Future<void> signOut() => _firebaseAuth.signOut();
}

final authClientProvider = Provider<AuthClient>(
  (ref) => FirebaseAuthClient(ref.watch(firebaseAuthProvider)),
);

/// Contrato mínimo para Google Sign-In usado por la capa de lógica.
abstract class GoogleSignInClient {
  Future<GoogleSignInAccount?> signIn();

  Future<GoogleSignInAccount?> signOut();
}

class DefaultGoogleSignInClient implements GoogleSignInClient {
  DefaultGoogleSignInClient(this._googleSignIn);

  final GoogleSignIn _googleSignIn;

  @override
  Future<GoogleSignInAccount?> signIn() => _googleSignIn.signIn();

  @override
  Future<GoogleSignInAccount?> signOut() => _googleSignIn.signOut();
}

final googleSignInClientProvider = Provider<GoogleSignInClient>(
  (ref) => DefaultGoogleSignInClient(ref.watch(googleSignInProvider)),
);

// ── Stream de sesión ──────────────────────────────────────────────────────────

/// Stream del usuario autenticado. null = sin sesión.
final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(authClientProvider).authStateChanges(),
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
      final authClient = ref.read(authClientProvider);
      final settings = ActionCodeSettings(
        url: _resolveMagicLinkUrl(),
        handleCodeInApp: true,
        androidPackageName: AppEnvironmentConfig.androidApplicationId,
        androidInstallApp: true,
        androidMinimumVersion: '21',
        iOSBundleId: AppEnvironmentConfig.iosBundleId,
      );

      await authClient.sendSignInLinkToEmail(
        email: email,
        actionCodeSettings: settings,
      );

      // Persistir el email localmente para usarlo al procesar el link
      final prefs = await ref.read(sharedPreferencesProvider);
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
      final authClient = ref.read(authClientProvider);
      final prefs = await ref.read(sharedPreferencesProvider);
      final email =
          emailOverride ?? prefs.getString(_kPendingEmailLinkKey) ?? '';

      if (email.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'No encontramos el email. Intentá reenviar el link.',
        );
        return;
      }

      if (!authClient.isSignInWithEmailLink(link)) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'El link no es válido o ya expiró.',
        );
        return;
      }

      final credential = await authClient.signInWithEmailLink(
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
      final authClient = ref.read(authClientProvider);
      final googleSignInClient = ref.read(googleSignInClientProvider);
      UserCredential result;

      if (kIsWeb) {
        // En web usamos signInWithPopup (no requiere el paquete google_sign_in)
        result = await authClient.signInWithPopup(GoogleAuthProvider());
      } else {
        final googleUser = await googleSignInClient.signIn();
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

        result = await authClient.signInWithCredential(credential);
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
      await ref.read(authClientProvider).signOut();
      await ref.read(googleSignInClientProvider).signOut();
    } catch (e) {
      // Loguear pero continuar
      // ignore: avoid_print
      print('[AuthNotifier.signOut] Error en Firebase signOut: $e');
    }

    // Acción 2: limpiar SharedPreferences (no limpiar onboarding_seen)
    try {
      final prefs = await ref.read(sharedPreferencesProvider);
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
      ref.invalidate(authClaimsProvider);
      ref.invalidate(isOwnerProvider);
      ref.invalidate(isAdminProvider);
      ref.read(displayNameSkippedProvider.notifier).state = false;
      ref.read(pendingMagicLinkProvider.notifier).state = null;
      ref.read(pendingAuthToastProvider.notifier).state = null;
      ref.read(pendingRouteProvider.notifier).state = null;
    } catch (e) {
      // ignore: avoid_print
      print('[AuthNotifier.signOut] Error invalidando providers: $e');
    }
  }

  /// Retorna true si existe un pending_email_link guardado en SharedPreferences.
  /// Usado para detectar el caso cross-device del magic link.
  Future<bool> hasPendingEmailLink() async {
    final prefs = await ref.read(sharedPreferencesProvider);
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

class AuthClaimsSnapshot {
  const AuthClaimsSnapshot({
    required this.role,
    required this.ownerPending,
    required this.merchantId,
    required this.onboardingComplete,
  });

  final String? role;
  final bool ownerPending;
  final String? merchantId;
  final bool onboardingComplete;
}

/// Claims de autenticación leídos desde el ID token.
/// Evita force refresh para no duplicar costo de red; el refresh forzado
/// se centraliza en AuthNotifier al cambiar la sesión.
final authClaimsProvider = FutureProvider<AuthClaimsSnapshot?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  final result = await user.getIdTokenResult();
  final claims = result.claims ?? const <String, dynamic>{};
  String? role = (claims['role'] as String?)?.toLowerCase();
  String? merchantId = claims['merchantId'] as String?;
  final ownerPendingRaw = claims['owner_pending'];
  var ownerPending = ownerPendingRaw == true ||
      (ownerPendingRaw is String && ownerPendingRaw.toLowerCase() == 'true');
  var onboardingComplete = claims['onboardingComplete'] == true;

  final ownerPendingInClaims = claims.containsKey('owner_pending');
  if (role == null || merchantId == null || !ownerPendingInClaims) {
    try {
      final userDoc =
          await FirebaseFirestore.instance.doc('users/${user.uid}').get();
      if (userDoc.exists) {
        final data = userDoc.data() ?? const <String, dynamic>{};
        role ??= (data['role'] as String?)?.toLowerCase();
        merchantId ??= data['merchantId'] as String?;
        if (!ownerPendingInClaims) {
          final ownerPendingDocRaw = data['ownerPending'];
          ownerPending = ownerPendingDocRaw == true ||
              (ownerPendingDocRaw is String &&
                  ownerPendingDocRaw.toLowerCase() == 'true');
        }
        if (!onboardingComplete) {
          onboardingComplete = data['onboardingComplete'] == true;
        }
      }
    } catch (_) {
      // fallback silencioso a claims
    }
  }

  return AuthClaimsSnapshot(
    role: role,
    ownerPending: ownerPending,
    merchantId: merchantId,
    onboardingComplete: onboardingComplete,
  );
});

/// true si el usuario autenticado tiene el claim role='owner' en Firebase Auth.
final isOwnerProvider = FutureProvider<bool>((ref) async {
  final claims = await ref.watch(authClaimsProvider.future);
  if (claims == null) return false;
  return claims.role == 'owner' && !claims.ownerPending;
});

/// true si el usuario autenticado tiene el claim role='admin' o 'super_admin'.
final isAdminProvider = FutureProvider<bool>((ref) async {
  final claims = await ref.watch(authClaimsProvider.future);
  if (claims == null) return false;
  final role = claims.role;
  return role == 'admin' || role == 'super_admin';
});

// ── Provider de merchantId del owner ─────────────────────────────────────────

/// merchantId del comercio del owner autenticado.
/// Prioriza custom claims (sin lecturas Firestore).
/// Solo usa fallback a Firestore merchants por ownerUserId si el claim no está.
/// Null si el usuario no es owner o aún no completó el onboarding.
final ownerMerchantIdProvider = FutureProvider<String?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  final claims = await ref.watch(authClaimsProvider.future);
  final merchantIdFromClaims = claims?.merchantId?.trim();
  if (merchantIdFromClaims != null && merchantIdFromClaims.isNotEmpty) {
    return merchantIdFromClaims;
  }

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
