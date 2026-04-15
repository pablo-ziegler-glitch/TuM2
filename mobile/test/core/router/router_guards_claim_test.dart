import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tum2/core/auth/auth_state.dart';
import 'package:tum2/core/router/app_routes.dart';
import 'package:tum2/core/router/router_guards.dart';

class _FakeUser extends Fake implements User {}

void main() {
  late User user;

  setUp(() {
    user = _FakeUser();
  });

  test('usuario autenticado customer puede navegar a /claim', () {
    final result = RouterGuards.evaluate(
      authState: AuthAuthenticated(
        user: user,
        role: 'customer',
      ),
      location: AppRoutes.claimIntro,
    );
    expect(result, isNull);
  });

  test('usuario sin sesión en /claim redirige a /login', () {
    final result = RouterGuards.evaluate(
      authState: const AuthUnauthenticated(),
      location: AppRoutes.claimIntro,
    );
    expect(result, AppRoutes.login);
  });

  test('owner_pending puede navegar a /claim/status', () {
    final result = RouterGuards.evaluate(
      authState: AuthAuthenticated(
        user: user,
        role: 'owner',
        ownerPending: true,
      ),
      location: AppRoutes.claimStatus,
    );
    expect(result, isNull);
  });
}
