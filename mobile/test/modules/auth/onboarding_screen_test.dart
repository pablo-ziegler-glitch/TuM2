import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tum2/core/router/app_routes.dart';
import 'package:tum2/modules/auth/screens/onboarding_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpOnboarding(WidgetTester tester, {String? source}) async {
    final initial = source == null
        ? AppRoutes.onboarding
        : AppRoutes.onboardingPath(source: source);
    final router = GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(
          path: AppRoutes.onboarding,
          builder: (_, state) => OnboardingScreen(
            source: state.uri.queryParameters['source'] ?? 'first_launch',
          ),
        ),
        GoRoute(
          path: AppRoutes.home,
          builder: (_, __) => const Scaffold(body: Text('HOME_SCREEN')),
        ),
        GoRoute(
          path: AppRoutes.login,
          builder: (_, __) => const Scaffold(body: Text('LOGIN_SCREEN')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renderiza 3 slides con copy esperado', (tester) async {
    await pumpOnboarding(tester);

    expect(find.text('Encontrá comercios abiertos ahora en tu cuadra'),
        findsOneWidget);
    expect(find.text('Omitir'), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Farmacias de turno al instante'), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Tené tus lugares de siempre más cerca'), findsOneWidget);
  });

  testWidgets('último CTA muestra Empezar y no navega automático a login',
      (tester) async {
    await pumpOnboarding(tester);

    expect(find.text('LOGIN_SCREEN'), findsNothing);

    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();

    expect(find.text('Empezar'), findsOneWidget);
    expect(find.text('LOGIN_SCREEN'), findsNothing);
  });

  testWidgets('tap en Omitir guarda onboarding_seen y navega a Home',
      (tester) async {
    await pumpOnboarding(tester);

    await tester.tap(find.text('Omitir'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_seen'), isTrue);
    expect(find.text('HOME_SCREEN'), findsOneWidget);
    expect(find.text('LOGIN_SCREEN'), findsNothing);
  });

  testWidgets('tap en Empezar guarda onboarding_seen y navega a Home',
      (tester) async {
    await pumpOnboarding(tester);

    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Empezar'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_seen'), isTrue);
    expect(find.text('HOME_SCREEN'), findsOneWidget);
    expect(find.text('LOGIN_SCREEN'), findsNothing);
  });

  testWidgets('acepta source=profile_help sin romper navegación',
      (tester) async {
    await pumpOnboarding(tester, source: 'profile_help');

    await tester.tap(find.text('Omitir'));
    await tester.pumpAndSettle();

    expect(find.text('HOME_SCREEN'), findsOneWidget);
  });
}
