import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tum2/core/auth/auth_notifier.dart';
import 'package:tum2/core/auth/auth_state.dart';
import 'package:tum2/core/providers/auth_providers.dart';
import 'package:tum2/modules/auth/screens/splash_screen.dart';

class _FakeAuthNotifier extends ChangeNotifier implements AuthNotifier {
  _FakeAuthNotifier({AuthState initialState = const AuthLoading()})
      : _authState = initialState;

  AuthState _authState;
  bool forceUnauthenticatedCalled = false;

  @override
  AuthState get authState => _authState;

  @override
  void forceUnauthenticated() {
    forceUnauthenticatedCalled = true;
    _authState = const AuthUnauthenticated();
    notifyListeners();
  }

  @override
  Future<void> refreshSession({
    AuthSessionRefreshReason reason = AuthSessionRefreshReason.manualRetry,
    bool forceUserDocRead = false,
  }) async {}

  void setAuthState(AuthState state) {
    _authState = state;
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('muestra claim, loading y microcopy de splash', (tester) async {
    final notifier = _FakeAuthNotifier();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith((ref) => notifier),
        ],
        child: const MaterialApp(home: SplashScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Lo que necesitás, en tu zona.'), findsOneWidget);
    expect(find.text('Preparando tu zona...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.bySemanticsLabel('TuM2'), findsOneWidget);
  });

  testWidgets('timeout no deja usuario atrapado y ofrece CTA guest-first',
      (tester) async {
    final notifier = _FakeAuthNotifier(initialState: const AuthLoading());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith((ref) => notifier),
          isFirstLaunchProvider.overrideWith((ref) async => false),
        ],
        child: const MaterialApp(home: SplashScreen()),
      ),
    );

    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(milliseconds: 200));

    expect(notifier.forceUnauthenticatedCalled, isTrue);
    expect(
      find.text(
          'No pudimos confirmar tu sesión. Podés seguir explorando igual.'),
      findsOneWidget,
    );
    expect(find.text('Explorar sin iniciar sesión'), findsOneWidget);
  });
}
