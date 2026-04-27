import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tum2/core/auth/auth_notifier.dart';
import 'package:tum2/core/auth/auth_state.dart';
import 'package:tum2/modules/owner/screens/owner_schedule_screen.dart';

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
  testWidgets('muestra bloqueo contextual cuando owner está pending',
      (tester) async {
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
        child: const MaterialApp(home: OwnerScheduleScreen()),
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
