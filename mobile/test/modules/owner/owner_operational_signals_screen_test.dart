import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tum2/core/auth/auth_notifier.dart';
import 'package:tum2/core/auth/auth_state.dart';
import 'package:tum2/modules/owner/screens/owner_operational_signals_screen.dart';

class _FakeUser extends Fake implements User {
  @override
  String get uid => 'owner-1';
}

class _FakeAuthNotifier extends ChangeNotifier implements AuthNotifier {
  _FakeAuthNotifier(this._state);

  AuthState _state;

  @override
  AuthState get authState => _state;

  @override
  void forceUnauthenticated() {
    _state = const AuthUnauthenticated();
    notifyListeners();
  }

  @override
  Future<void> refreshSession({
    AuthSessionRefreshReason reason = AuthSessionRefreshReason.manualRetry,
    bool forceUserDocRead = false,
  }) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('muestra estado de error cuando no hay sesión', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith((ref) {
            return _FakeAuthNotifier(const AuthUnauthenticated());
          }),
        ],
        child: const MaterialApp(
          home: OwnerOperationalSignalsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.text('Necesitás iniciar sesión para editar señales operativas.'),
      findsOneWidget,
    );
  });

  testWidgets('bloquea edición cuando owner está pending', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith((ref) {
            return _FakeAuthNotifier(
              AuthAuthenticated(
                user: _FakeUser(),
                role: 'owner',
                ownerPending: true,
              ),
            );
          }),
        ],
        child: const MaterialApp(
          home: OwnerOperationalSignalsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Tu comercio está en revisión'), findsOneWidget);
    expect(
      find.text(
        'Cuando se apruebe, vas a poder editar horarios y avisos operativos.',
      ),
      findsOneWidget,
    );
  });
}
