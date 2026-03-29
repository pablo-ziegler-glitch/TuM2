import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:tum2/core/auth/auth_state.dart';
import 'package:tum2/core/router/app_routes.dart';
import 'package:tum2/core/router/router_guards.dart';

/// Fake de [User] para tests — los guards leen solo role/onboardingComplete.
class _FakeUser extends Fake implements User {}

void main() {
  late User fakeUser;

  setUp(() {
    fakeUser = _FakeUser();
  });

  // ── isPublicPath ────────────────────────────────────────────────────────────

  group('isPublicPath', () {
    test('splash es público', () {
      expect(RouterGuards.isPublicPath(AppRoutes.splash), isTrue);
    });
    test('login es público', () {
      expect(RouterGuards.isPublicPath(AppRoutes.login), isTrue);
    });
    test('onboarding es público', () {
      expect(RouterGuards.isPublicPath(AppRoutes.onboarding), isTrue);
    });
    test('email-verification es público', () {
      expect(RouterGuards.isPublicPath(AppRoutes.emailVerification), isTrue);
    });
    test('/commerce/:id es público', () {
      expect(RouterGuards.isPublicPath('/commerce/abc123'), isTrue);
    });
    test('/pharmacy/:id es público', () {
      expect(RouterGuards.isPublicPath('/pharmacy/farma-01'), isTrue);
    });
    test('/home/farmacias-de-turno es público', () {
      expect(RouterGuards.isPublicPath(AppRoutes.homeFarmacias), isTrue);
    });
    test('/home es protegido', () {
      expect(RouterGuards.isPublicPath(AppRoutes.home), isFalse);
    });
    test('/owner es protegido', () {
      expect(RouterGuards.isPublicPath(AppRoutes.owner), isFalse);
    });
    test('/admin es protegido', () {
      expect(RouterGuards.isPublicPath(AppRoutes.admin), isFalse);
    });
    test('/auth/display-name es protegido', () {
      expect(RouterGuards.isPublicPath(AppRoutes.displayName), isFalse);
    });
    test('/profile es protegido', () {
      expect(RouterGuards.isPublicPath(AppRoutes.profile), isFalse);
    });
  });

  // ── canAccessRoute ──────────────────────────────────────────────────────────

  group('canAccessRoute', () {
    test('customer puede acceder a /home', () {
      expect(RouterGuards.canAccessRoute('/home', 'customer'), isTrue);
    });
    test('customer NO puede acceder a /owner', () {
      expect(RouterGuards.canAccessRoute('/owner', 'customer'), isFalse);
    });
    test('customer NO puede acceder a /owner/products', () {
      expect(RouterGuards.canAccessRoute('/owner/products', 'customer'), isFalse);
    });
    test('owner puede acceder a /owner', () {
      expect(RouterGuards.canAccessRoute('/owner', 'owner'), isTrue);
    });
    test('owner NO puede acceder a /admin', () {
      expect(RouterGuards.canAccessRoute('/admin', 'owner'), isFalse);
    });
    test('admin puede acceder a /owner', () {
      expect(RouterGuards.canAccessRoute('/owner', 'admin'), isTrue);
    });
    test('admin puede acceder a /admin', () {
      expect(RouterGuards.canAccessRoute('/admin', 'admin'), isTrue);
    });
  });

  // ── evaluate: AuthLoading ───────────────────────────────────────────────────

  group('evaluate — AuthLoading', () {
    test('estando en splash no redirige', () {
      final result = RouterGuards.evaluate(
        authState: const AuthLoading(),
        location: AppRoutes.splash,
      );
      expect(result, isNull);
    });

    test('desde /home redirige a splash', () {
      final result = RouterGuards.evaluate(
        authState: const AuthLoading(),
        location: '/home',
      );
      expect(result, equals(AppRoutes.splash));
    });

    test('desde /login redirige a splash', () {
      final result = RouterGuards.evaluate(
        authState: const AuthLoading(),
        location: AppRoutes.login,
      );
      expect(result, equals(AppRoutes.splash));
    });

    test('desde /auth/display-name redirige a splash', () {
      final result = RouterGuards.evaluate(
        authState: const AuthLoading(),
        location: AppRoutes.displayName,
      );
      expect(result, equals(AppRoutes.splash));
    });
  });

  // ── evaluate: AuthUnauthenticated ────────────────────────────────────────────

  group('evaluate — AuthUnauthenticated', () {
    const publicPaths = [
      AppRoutes.splash,
      AppRoutes.login,
      AppRoutes.onboarding,
      AppRoutes.emailVerification,
      '/commerce/shop1',
      '/pharmacy/farma-01',
    ];

    for (final path in publicPaths) {
      test('permite ruta pública $path', () {
        final result = RouterGuards.evaluate(
          authState: const AuthUnauthenticated(),
          location: path,
        );
        expect(result, isNull);
      });
    }

    test('en /home redirige a login', () {
      final result = RouterGuards.evaluate(
        authState: const AuthUnauthenticated(),
        location: '/home',
      );
      expect(result, equals(AppRoutes.login));
    });

    test('en /owner redirige a login', () {
      final result = RouterGuards.evaluate(
        authState: const AuthUnauthenticated(),
        location: '/owner',
      );
      expect(result, equals(AppRoutes.login));
    });

    test('en /admin redirige a login', () {
      final result = RouterGuards.evaluate(
        authState: const AuthUnauthenticated(),
        location: '/admin',
      );
      expect(result, equals(AppRoutes.login));
    });

    test('en /auth/display-name redirige a login', () {
      final result = RouterGuards.evaluate(
        authState: const AuthUnauthenticated(),
        location: AppRoutes.displayName,
      );
      expect(result, equals(AppRoutes.login));
    });
  });

  // ── evaluate: AuthAuthenticated — desde ruta auth ────────────────────────────

  group('evaluate — AuthAuthenticated desde ruta auth', () {
    test('customer desde /login va a /home', () {
      final result = RouterGuards.evaluate(
        authState: AuthAuthenticated(user: fakeUser, role: 'customer'),
        location: AppRoutes.login,
      );
      expect(result, equals(AppRoutes.home));
    });

    test('owner con comercio completado desde /login va a /home', () {
      final result = RouterGuards.evaluate(
        authState: AuthAuthenticated(
          user: fakeUser,
          role: 'owner',
          merchantId: 'merchant-123',
          onboardingComplete: true, // owner que completó el alta
        ),
        location: AppRoutes.login,
      );
      expect(result, equals(AppRoutes.home));
    });

    test('owner sin comercio desde /login va a onboarding', () {
      final result = RouterGuards.evaluate(
        authState: AuthAuthenticated(
          user: fakeUser,
          role: 'owner',
          // onboardingComplete: false por defecto
        ),
        location: AppRoutes.login,
      );
      expect(result, equals(AppRoutes.onboardingOwner));
    });

    test('admin desde /login va a /home', () {
      final result = RouterGuards.evaluate(
        authState: AuthAuthenticated(user: fakeUser, role: 'admin'),
        location: AppRoutes.login,
      );
      expect(result, equals(AppRoutes.home));
    });

    test('customer desde splash va a /home', () {
      final result = RouterGuards.evaluate(
        authState: AuthAuthenticated(user: fakeUser, role: 'customer'),
        location: AppRoutes.splash,
      );
      expect(result, equals(AppRoutes.home));
    });

    test('customer desde onboarding va a /home', () {
      final result = RouterGuards.evaluate(
        authState: AuthAuthenticated(user: fakeUser, role: 'customer'),
        location: AppRoutes.onboarding,
      );
      expect(result, equals(AppRoutes.home));
    });
  });

  // ── evaluate: AuthAuthenticated — guards de rol ──────────────────────────────

  group('evaluate — AuthAuthenticated guards de rol', () {
    test('customer en /home no redirige', () {
      final result = RouterGuards.evaluate(
        authState: AuthAuthenticated(user: fakeUser, role: 'customer'),
        location: '/home',
      );
      expect(result, isNull);
    });

    test('customer en /profile no redirige', () {
      final result = RouterGuards.evaluate(
        authState: AuthAuthenticated(user: fakeUser, role: 'customer'),
        location: '/profile',
      );
      expect(result, isNull);
    });

    test('customer en /owner redirige a /profile', () {
      final result = RouterGuards.evaluate(
        authState: AuthAuthenticated(user: fakeUser, role: 'customer'),
        location: '/owner',
      );
      expect(result, equals(AppRoutes.profile));
    });

    test('customer en /owner/products redirige a /profile', () {
      final result = RouterGuards.evaluate(
        authState: AuthAuthenticated(user: fakeUser, role: 'customer'),
        location: '/owner/products',
      );
      expect(result, equals(AppRoutes.profile));
    });

    test('customer en /admin redirige a /home', () {
      final result = RouterGuards.evaluate(
        authState: AuthAuthenticated(user: fakeUser, role: 'customer'),
        location: '/admin',
      );
      expect(result, equals(AppRoutes.home));
    });

    test('owner con onboarding completo en /owner no redirige', () {
      final result = RouterGuards.evaluate(
        authState: AuthAuthenticated(
          user: fakeUser,
          role: 'owner',
          merchantId: 'merchant-123',
          onboardingComplete: true,
        ),
        location: '/owner',
      );
      expect(result, isNull);
    });

    test('owner sin onboarding en /home redirige a /onboarding/owner', () {
      final result = RouterGuards.evaluate(
        authState: AuthAuthenticated(user: fakeUser, role: 'owner'),
        location: '/home',
      );
      expect(result, equals(AppRoutes.onboardingOwner));
    });

    test('owner sin onboarding en /search redirige a /onboarding/owner', () {
      final result = RouterGuards.evaluate(
        authState: AuthAuthenticated(user: fakeUser, role: 'owner'),
        location: '/search',
      );
      expect(result, equals(AppRoutes.onboardingOwner));
    });

    test('owner sin onboarding en /onboarding/owner no redirige', () {
      final result = RouterGuards.evaluate(
        authState: AuthAuthenticated(user: fakeUser, role: 'owner'),
        location: '/onboarding/owner',
      );
      expect(result, isNull);
    });

    test('owner con onboarding en /admin redirige a /home', () {
      final result = RouterGuards.evaluate(
        authState: AuthAuthenticated(
          user: fakeUser,
          role: 'owner',
          merchantId: 'merchant-123',
          onboardingComplete: true,
        ),
        location: '/admin',
      );
      expect(result, equals(AppRoutes.home));
    });

    test('admin en /admin no redirige', () {
      final result = RouterGuards.evaluate(
        authState: AuthAuthenticated(user: fakeUser, role: 'admin'),
        location: '/admin',
      );
      expect(result, isNull);
    });

    test('admin en /owner no redirige', () {
      final result = RouterGuards.evaluate(
        authState: AuthAuthenticated(user: fakeUser, role: 'admin'),
        location: '/owner',
      );
      expect(result, isNull);
    });

    test('admin en /home no redirige', () {
      final result = RouterGuards.evaluate(
        authState: AuthAuthenticated(user: fakeUser, role: 'admin'),
        location: '/home',
      );
      expect(result, isNull);
    });
  });

  // ── evaluate: pending route (deep link pre-auth) ─────────────────────────────

  group('evaluate — pending route (deep link)', () {
    test('restaura pending route accesible post-auth (customer)', () {
      bool consumed = false;
      final result = RouterGuards.evaluate(
        authState: AuthAuthenticated(user: fakeUser, role: 'customer'),
        location: AppRoutes.login,
        pendingRoute: '/commerce/shop-123',
        consumePendingRoute: () => consumed = true,
      );
      expect(result, equals('/commerce/shop-123'));
      expect(consumed, isTrue);
    });

    test('NO restaura pending route si el rol no tiene acceso', () {
      bool consumed = false;
      final result = RouterGuards.evaluate(
        authState: AuthAuthenticated(user: fakeUser, role: 'customer'),
        location: AppRoutes.login,
        pendingRoute: '/owner',
        consumePendingRoute: () => consumed = true,
      );
      expect(result, equals(AppRoutes.home));
      expect(consumed, isFalse);
    });

    test('admin restaura pending route a /admin/merchants', () {
      bool consumed = false;
      final result = RouterGuards.evaluate(
        authState: AuthAuthenticated(user: fakeUser, role: 'admin'),
        location: AppRoutes.login,
        pendingRoute: '/admin/merchants',
        consumePendingRoute: () => consumed = true,
      );
      expect(result, equals('/admin/merchants'));
      expect(consumed, isTrue);
    });

    test('owner con onboarding restaura pending route a /owner/products', () {
      bool consumed = false;
      final result = RouterGuards.evaluate(
        authState: AuthAuthenticated(
          user: fakeUser,
          role: 'owner',
          merchantId: 'merchant-1',
          onboardingComplete: true,
        ),
        location: AppRoutes.login,
        pendingRoute: '/owner/products',
        consumePendingRoute: () => consumed = true,
      );
      expect(result, equals('/owner/products'));
      expect(consumed, isTrue);
    });

    test('customer sin pending route va a /home', () {
      final result = RouterGuards.evaluate(
        authState: AuthAuthenticated(user: fakeUser, role: 'customer'),
        location: AppRoutes.login,
      );
      expect(result, equals(AppRoutes.home));
    });

    test('owner sin onboarding ignora pending route y va a /onboarding/owner', () {
      bool consumed = false;
      // Owner que todavía no terminó el alta no debería saltar a otra ruta
      final result = RouterGuards.evaluate(
        authState: AuthAuthenticated(user: fakeUser, role: 'owner'),
        location: AppRoutes.login,
        pendingRoute: '/commerce/shop-1',
        consumePendingRoute: () => consumed = true,
      );
      // La pending route '/commerce/shop-1' es accesible para owner,
      // pero el guard de onboarding tiene prioridad en _authenticatedHome.
      // Esperamos que vaya a onboardingOwner (la pending route no restaura
      // cuando el owner aún no completó su alta).
      expect(result, equals(AppRoutes.onboardingOwner));
      expect(consumed, isFalse);
    });
  });
}
