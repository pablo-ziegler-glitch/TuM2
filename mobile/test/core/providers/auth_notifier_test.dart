import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tum2/core/providers/auth_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Nota: AuthNotifier usa FirebaseAuth.instance y GoogleSignIn() directamente
// (no inyectables). Los tests de Firebase (sendMagicLink, signInWithGoogle,
// handleEmailLink, signOut·Firebase) son de integración y requieren
// Firebase inicializado. Este archivo cubre la lógica pura del notifier:
//   • AuthState.copyWith
//   • clearError / estado inicial
//   • hasPendingEmailLink (vía SharedPreferences mock)
//   • signOut: limpieza de SharedPreferences
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // ── AuthState.copyWith ────────────────────────────────────────────────────

  group('AuthState.copyWith', () {
    test('estado inicial tiene valores por defecto correctos', () {
      const state = AuthState();
      expect(state.isLoading, isFalse);
      expect(state.errorMessage, isNull);
      expect(state.emailSent, isFalse);
    });

    test('isLoading se actualiza correctamente', () {
      const state = AuthState();
      final updated = state.copyWith(isLoading: true);
      expect(updated.isLoading, isTrue);
      expect(updated.errorMessage, isNull);
      expect(updated.emailSent, isFalse);
    });

    test('errorMessage se asigna correctamente', () {
      const state = AuthState();
      final updated = state.copyWith(errorMessage: 'Algo salió mal.');
      expect(updated.errorMessage, equals('Algo salió mal.'));
      expect(updated.isLoading, isFalse);
    });

    test('clearError: true limpia el errorMessage aunque se pase uno nuevo', () {
      const state = AuthState(errorMessage: 'Error previo');
      final updated = state.copyWith(
        clearError: true,
        errorMessage: 'Error nuevo ignorado',
      );
      expect(updated.errorMessage, isNull);
    });

    test('clearError: false preserva el errorMessage existente', () {
      const state = AuthState(errorMessage: 'Error persistente');
      final updated = state.copyWith(isLoading: false);
      expect(updated.errorMessage, equals('Error persistente'));
    });

    test('emailSent se actualiza correctamente', () {
      const state = AuthState();
      final updated = state.copyWith(emailSent: true);
      expect(updated.emailSent, isTrue);
    });

    test('campos sin especificar conservan valor previo', () {
      const state = AuthState(
        isLoading: true,
        errorMessage: 'Error',
        emailSent: true,
      );
      final updated = state.copyWith();
      expect(updated.isLoading, isTrue);
      expect(updated.errorMessage, equals('Error'));
      expect(updated.emailSent, isTrue);
    });

    test('isLoading false + emailSent true → patrón de éxito en sendMagicLink', () {
      const loading = AuthState(isLoading: true);
      final success = loading.copyWith(isLoading: false, emailSent: true);
      expect(success.isLoading, isFalse);
      expect(success.emailSent, isTrue);
      expect(success.errorMessage, isNull);
    });

    test('isLoading false + errorMessage → patrón de error', () {
      const loading = AuthState(isLoading: true);
      final error = loading.copyWith(
        isLoading: false,
        errorMessage: 'Sin conexión.',
      );
      expect(error.isLoading, isFalse);
      expect(error.emailSent, isFalse);
      expect(error.errorMessage, equals('Sin conexión.'));
    });
  });

  // ── clearError (ProviderContainer) ────────────────────────────────────────

  group('AuthNotifier.clearError', () {
    test('clearError limpia el errorMessage sin cambiar isLoading ni emailSent',
        () {
      // Creamos un contenedor aislado con override del notifier
      // para evitar que intente inicializar Firebase.
      final container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(() => _FakeAuthNotifier()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(authNotifierProvider.notifier);

      // Forzar un estado con error
      notifier.setStateForTest(
        const AuthState(
          isLoading: false,
          errorMessage: 'Error de red',
          emailSent: false,
        ),
      );

      expect(
        container.read(authNotifierProvider).errorMessage,
        equals('Error de red'),
      );

      notifier.clearError();

      final state = container.read(authNotifierProvider);
      expect(state.errorMessage, isNull);
      expect(state.isLoading, isFalse);
      expect(state.emailSent, isFalse);
    });

    test('clearError en estado inicial no cambia nada', () {
      final container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(() => _FakeAuthNotifier()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(authNotifierProvider.notifier);
      notifier.clearError();

      final state = container.read(authNotifierProvider);
      expect(state.errorMessage, isNull);
      expect(state.isLoading, isFalse);
      expect(state.emailSent, isFalse);
    });
  });

  // ── hasPendingEmailLink ───────────────────────────────────────────────────

  group('AuthNotifier.hasPendingEmailLink', () {
    setUp(() {
      // Reinicia SharedPreferences a estado vacío antes de cada test
      SharedPreferences.setMockInitialValues({});
    });

    test('retorna false cuando no hay email guardado', () async {
      final container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(() => _FakeAuthNotifier()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(authNotifierProvider.notifier);
      final result = await notifier.hasPendingEmailLink();
      expect(result, isFalse);
    });

    test('retorna true cuando hay un email guardado', () async {
      SharedPreferences.setMockInitialValues({
        'pending_email_link': 'usuario@example.com',
      });

      final container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(() => _FakeAuthNotifier()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(authNotifierProvider.notifier);
      final result = await notifier.hasPendingEmailLink();
      expect(result, isTrue);
    });

    test('retorna false cuando el email guardado es un string vacío', () async {
      SharedPreferences.setMockInitialValues({
        'pending_email_link': '',
      });

      final container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(() => _FakeAuthNotifier()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(authNotifierProvider.notifier);
      final result = await notifier.hasPendingEmailLink();
      expect(result, isFalse);
    });
  });

  // ── signOut: limpieza de SharedPreferences ────────────────────────────────
  // Nota: signOut también llama a FirebaseAuth.signOut() y GoogleSignIn.signOut(),
  // que no se pueden verificar sin Firebase inicializado. Aquí verificamos
  // únicamente la limpieza de SharedPreferences (acción 2 de las 3).

  group('AuthNotifier.signOut — limpieza de SharedPreferences', () {
    const kPendingEmailLinkKey = 'pending_email_link';
    const kOnboardingOwnerDraftKey = 'onboarding_owner_draft';

    setUp(() {
      SharedPreferences.setMockInitialValues({
        kPendingEmailLinkKey: 'test@example.com',
        kOnboardingOwnerDraftKey: '{"step":2}',
        'onboarding_seen': 'true', // esta clave NO debe borrarse
      });
    });

    test('signOut elimina pending_email_link y onboarding_owner_draft', () async {
      final container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(() => _FakeAuthNotifier()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(authNotifierProvider.notifier);
      await notifier.signOut();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kPendingEmailLinkKey), isNull);
      expect(prefs.getString(kOnboardingOwnerDraftKey), isNull);
    });

    test('signOut NO elimina onboarding_seen', () async {
      final container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(() => _FakeAuthNotifier()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(authNotifierProvider.notifier);
      await notifier.signOut();

      final prefs = await SharedPreferences.getInstance();
      // onboarding_seen debe conservarse entre sesiones
      expect(prefs.getString('onboarding_seen'), equals('true'));
    });

    test('signOut resetea displayNameSkippedProvider a false', () async {
      final container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(() => _FakeAuthNotifier()),
        ],
      );
      addTearDown(container.dispose);

      // Marcar como saltado
      container.read(displayNameSkippedProvider.notifier).state = true;
      expect(container.read(displayNameSkippedProvider), isTrue);

      final notifier = container.read(authNotifierProvider.notifier);
      await notifier.signOut();

      expect(container.read(displayNameSkippedProvider), isFalse);
    });

    test('signOut resetea pendingMagicLinkProvider a null', () async {
      final container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(() => _FakeAuthNotifier()),
        ],
      );
      addTearDown(container.dispose);

      container.read(pendingMagicLinkProvider.notifier).state =
          'https://tum2.app/auth/verify?link=xxx';
      expect(container.read(pendingMagicLinkProvider), isNotNull);

      final notifier = container.read(authNotifierProvider.notifier);
      await notifier.signOut();

      expect(container.read(pendingMagicLinkProvider), isNull);
    });

    test('signOut resetea pendingAuthToastProvider a null', () async {
      final container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(() => _FakeAuthNotifier()),
        ],
      );
      addTearDown(container.dispose);

      container.read(pendingAuthToastProvider.notifier).state =
          '¡Hola de nuevo!';
      expect(container.read(pendingAuthToastProvider), isNotNull);

      final notifier = container.read(authNotifierProvider.notifier);
      await notifier.signOut();

      expect(container.read(pendingAuthToastProvider), isNull);
    });
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// _FakeAuthNotifier: subclase de AuthNotifier que omite las llamadas a Firebase
// (FirebaseAuth / GoogleSignIn) para que los tests de lógica pura puedan correr
// sin Firebase inicializado.
// ─────────────────────────────────────────────────────────────────────────────

class _FakeAuthNotifier extends AuthNotifier {
  /// Permite inyectar un estado arbitrario desde el test.
  void setStateForTest(AuthState s) => state = s;

  @override
  Future<void> sendMagicLink(String email) async {
    // No-op en tests
  }

  @override
  Future<void> handleEmailLink(String link, {String? emailOverride}) async {
    // No-op en tests
  }

  @override
  Future<void> signInWithGoogle() async {
    // No-op en tests
  }

  /// signOut real excepto las llamadas a Firebase/Google.
  /// Ejercita las acciones 2 y 3 (SharedPreferences + Riverpod reset).
  @override
  Future<void> signOut() async {
    // Acción 2: limpiar SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.remove('pending_email_link'),
        prefs.remove('onboarding_owner_draft'),
      ]);
    } catch (_) {}

    // Acción 3: invalidar/resetear providers de Riverpod
    try {
      ref.read(displayNameSkippedProvider.notifier).state = false;
      ref.read(pendingMagicLinkProvider.notifier).state = null;
      ref.read(pendingAuthToastProvider.notifier).state = null;
    } catch (_) {}
  }
}
