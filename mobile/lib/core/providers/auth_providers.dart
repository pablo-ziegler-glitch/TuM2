import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Constantes ────────────────────────────────────────────────────────────────

const _kOnboardingSeenKey = 'onboarding_seen';

/// URL base para magic links. En producción apunta al dominio real.
/// En desarrollo se puede usar el emulador de Auth.
const _kMagicLinkUrl = 'https://tum2.app/auth/verify';

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

// ── Auth notifier ─────────────────────────────────────────────────────────────

/// Estado de las operaciones de autenticación.
class AuthState {
  const AuthState({
    this.isLoading = false,
    this.errorMessage,
    this.emailSent = false,
  });

  final bool isLoading;
  final String? errorMessage;

  /// true cuando el magic link fue enviado exitosamente.
  final bool emailSent;

  AuthState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    bool? emailSent,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      emailSent: emailSent ?? this.emailSent,
    );
  }
}

/// Notifier principal de autenticación.
/// Maneja magic link y Google Sign-In.
class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  /// Envía el magic link al email indicado.
  Future<void> sendMagicLink(String email) async {
    state = state.copyWith(isLoading: true, clearError: true, emailSent: false);

    try {
      final settings = ActionCodeSettings(
        url: _kMagicLinkUrl,
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
      await prefs.setString('pending_email_link', email);

      state = state.copyWith(isLoading: false, emailSent: true);
    } on FirebaseAuthException catch (e) {
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
  Future<void> handleEmailLink(String link) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('pending_email_link') ?? '';

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

      await FirebaseAuth.instance.signInWithEmailLink(
        email: email,
        emailLink: link,
      );

      await prefs.remove('pending_email_link');
      state = state.copyWith(isLoading: false);
    } on FirebaseAuthException catch (e) {
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

      await FirebaseAuth.instance.signInWithCredential(credential);
      state = state.copyWith(isLoading: false);
    } on FirebaseAuthException catch (e) {
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

  /// Cierra la sesión actual.
  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn().signOut();
  }

  /// Limpia el error visible sin cambiar otro estado.
  void clearError() => state = state.copyWith(clearError: true);

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

final authNotifierProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
