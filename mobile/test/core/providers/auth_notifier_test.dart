import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tum2/core/providers/auth_providers.dart';
import 'package:tum2/core/router/pending_route_provider.dart';

class _FakeUserCredential extends Fake implements UserCredential {
  @override
  User? get user => null;
}

class _FakeAuthClient implements AuthClient {
  final _authStateController = StreamController<User?>.broadcast();

  FirebaseAuthException? sendMagicLinkError;
  FirebaseAuthException? signInWithEmailLinkError;
  bool isEmailLinkValid = true;

  String? lastSentEmail;
  ActionCodeSettings? lastActionCodeSettings;
  String? lastSignInEmail;
  String? lastSignInEmailLink;
  bool signOutCalled = false;

  @override
  Stream<User?> authStateChanges() => _authStateController.stream;

  @override
  Future<void> sendSignInLinkToEmail({
    required String email,
    required ActionCodeSettings actionCodeSettings,
  }) async {
    if (sendMagicLinkError != null) throw sendMagicLinkError!;
    lastSentEmail = email;
    lastActionCodeSettings = actionCodeSettings;
  }

  @override
  bool isSignInWithEmailLink(String link) => isEmailLinkValid;

  @override
  Future<UserCredential> signInWithEmailLink({
    required String email,
    required String emailLink,
  }) async {
    if (signInWithEmailLinkError != null) throw signInWithEmailLinkError!;
    lastSignInEmail = email;
    lastSignInEmailLink = emailLink;
    return _FakeUserCredential();
  }

  @override
  Future<UserCredential> signInWithPopup(AuthProvider provider) async {
    return _FakeUserCredential();
  }

  @override
  Future<UserCredential> signInWithCredential(AuthCredential credential) async {
    return _FakeUserCredential();
  }

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }

  void dispose() {
    _authStateController.close();
  }
}

class _FakeGoogleSignInClient implements GoogleSignInClient {
  bool signOutCalled = false;

  @override
  Future<GoogleSignInAccount?> signIn() async => null;

  @override
  Future<GoogleSignInAccount?> signOut() async {
    signOutCalled = true;
    return null;
  }
}

void main() {
  late _FakeAuthClient authClient;
  late _FakeGoogleSignInClient googleSignInClient;

  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [
        authClientProvider.overrideWithValue(authClient),
        googleSignInClientProvider.overrideWithValue(googleSignInClient),
      ],
    );
    addTearDown(() {
      container.dispose();
      authClient.dispose();
    });
    return container;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    authClient = _FakeAuthClient();
    googleSignInClient = _FakeGoogleSignInClient();
  });

  group('AuthOpState.copyWith', () {
    test('mantiene defaults correctos', () {
      const state = AuthOpState();
      expect(state.isLoading, isFalse);
      expect(state.errorMessage, isNull);
      expect(state.emailSent, isFalse);
    });

    test('clearError limpia errorMessage', () {
      const state = AuthOpState(errorMessage: 'Error previo');
      final updated = state.copyWith(clearError: true);
      expect(updated.errorMessage, isNull);
      expect(updated.isLoading, isFalse);
      expect(updated.emailSent, isFalse);
    });
  });

  group('sendMagicLink', () {
    test('éxito: envía link y persiste pending_email_link', () async {
      final container = createContainer();
      final notifier = container.read(authOpProvider.notifier);

      await notifier.sendMagicLink('usuario@example.com');

      expect(authClient.lastSentEmail, 'usuario@example.com');
      expect(authClient.lastActionCodeSettings, isNotNull);
      expect(authClient.lastActionCodeSettings!.handleCodeInApp, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('pending_email_link'), 'usuario@example.com');

      final state = container.read(authOpProvider);
      expect(state.isLoading, isFalse);
      expect(state.emailSent, isTrue);
      expect(state.errorMessage, isNull);
    });

    test('error Firebase: mapea mensaje UX en español', () async {
      authClient.sendMagicLinkError =
          FirebaseAuthException(code: 'network-request-failed');

      final container = createContainer();
      final notifier = container.read(authOpProvider.notifier);

      await notifier.sendMagicLink('usuario@example.com');

      final state = container.read(authOpProvider);
      expect(state.isLoading, isFalse);
      expect(state.emailSent, isFalse);
      expect(state.errorMessage, 'Sin conexión. Revisá tu red.');
    });
  });

  group('handleEmailLink', () {
    test('same-device: usa pending_email_link y limpia estado pendiente',
        () async {
      SharedPreferences.setMockInitialValues({
        'pending_email_link': 'same-device@example.com',
      });

      final container = createContainer();
      container.read(pendingMagicLinkProvider.notifier).state =
          'https://tum2.app/auth/verify?mode=signIn&oobCode=abc';

      final notifier = container.read(authOpProvider.notifier);
      await notifier.handleEmailLink(
        'https://tum2.app/auth/verify?mode=signIn&oobCode=abc',
      );

      expect(authClient.lastSignInEmail, 'same-device@example.com');
      expect(
        authClient.lastSignInEmailLink,
        'https://tum2.app/auth/verify?mode=signIn&oobCode=abc',
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('pending_email_link'), isNull);
      expect(container.read(pendingMagicLinkProvider), isNull);
      expect(container.read(authOpProvider).errorMessage, isNull);
    });

    test('cross-device: usa emailOverride aunque no haya pending_email_link',
        () async {
      final container = createContainer();
      container.read(pendingMagicLinkProvider.notifier).state =
          'https://tum2.app/auth/verify?mode=signIn&oobCode=xyz';

      final notifier = container.read(authOpProvider.notifier);
      await notifier.handleEmailLink(
        'https://tum2.app/auth/verify?mode=signIn&oobCode=xyz',
        emailOverride: 'cross-device@example.com',
      );

      expect(authClient.lastSignInEmail, 'cross-device@example.com');
      expect(
        authClient.lastSignInEmailLink,
        'https://tum2.app/auth/verify?mode=signIn&oobCode=xyz',
      );
      expect(container.read(pendingMagicLinkProvider), isNull);
      expect(container.read(authOpProvider).errorMessage, isNull);
    });
  });

  group('signOut', () {
    test('limpia SharedPreferences y providers locales', () async {
      SharedPreferences.setMockInitialValues({
        'pending_email_link': 'logout@example.com',
        'onboarding_owner_draft': '{"step":2}',
        'onboarding_seen': true,
      });

      final container = createContainer();
      container.read(displayNameSkippedProvider.notifier).state = true;
      container.read(pendingMagicLinkProvider.notifier).state =
          'https://tum2.app/auth/verify?mode=signIn&oobCode=logout';
      container.read(pendingAuthToastProvider.notifier).state =
          '¡Hola de nuevo!';
      container.read(pendingRouteProvider.notifier).state = '/owner/products';

      final notifier = container.read(authOpProvider.notifier);
      await notifier.signOut();

      expect(authClient.signOutCalled, isTrue);
      expect(googleSignInClient.signOutCalled, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('pending_email_link'), isNull);
      expect(prefs.getString('onboarding_owner_draft'), isNull);
      expect(prefs.getBool('onboarding_seen'), isTrue);

      expect(container.read(displayNameSkippedProvider), isFalse);
      expect(container.read(pendingMagicLinkProvider), isNull);
      expect(container.read(pendingAuthToastProvider), isNull);
      expect(container.read(pendingRouteProvider), isNull);
    });
  });
}
