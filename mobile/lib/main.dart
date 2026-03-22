import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'core/theme/app_colors.dart';
import 'modules/brand/onboarding_owner/models/onboarding_draft.dart';
import 'modules/brand/onboarding_owner/onboarding_owner_flow.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(
    const ProviderScope(child: TuM2App()),
  );
}

// ─── Router ──────────────────────────────────────────────────────────────────

final _router = GoRouter(
  initialLocation: '/',
  redirect: _globalRedirect,
  routes: [
    GoRoute(path: '/', builder: (_, __) => const _SplashScreen()),
    GoRoute(
      path: '/onboarding/owner',
      builder: (context, state) {
        final extra = state.extra as OnboardingDraft?;
        return OnboardingOwnerFlow(
          existingDraft: extra,
          onComplete: () => context.go('/owner'),
          onExit: () => context.go('/home'),
        );
      },
    ),
    GoRoute(
      path: '/home',
      builder: (_, __) => const _PlaceholderScreen(label: 'HOME-01'),
    ),
    GoRoute(
      path: '/owner',
      builder: (_, __) => const _PlaceholderScreen(label: 'OWNER-01'),
    ),
  ],
);

/// NAV-01: Guard global de navegación.
///
/// Después del login:
/// - Si role == 'owner' y onboardingOwnerProgress.currentStep != 'completed'
///   → redirigir a /onboarding/owner con el borrador existente (si hay).
Future<String?> _globalRedirect(BuildContext context, GoRouterState state) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null; // Sin sesión, no redirigir desde auth stack

  // Solo aplicar guard si no estamos ya en el onboarding
  if (state.matchedLocation == '/onboarding/owner') return null;

  try {
    final userDoc = await FirebaseFirestore.instance
        .doc('users/${user.uid}')
        .get();

    if (!userDoc.exists) return null;
    final data = userDoc.data() as Map<String, dynamic>;

    if (data['role'] != 'owner') return null;

    final progress = data['onboardingOwnerProgress'] as Map<String, dynamic>?;
    if (progress == null) {
      // Owner sin onboarding iniciado → enviar al flujo
      return '/onboarding/owner';
    }

    final currentStep = progress['currentStep'] as String?;
    if (currentStep == 'completed') return null;

    // Hay un borrador activo → construir OnboardingDraft y enviarlo como extra
    // go_router no soporta `extra` en redirect; navegamos via GoRouter.of
    // En su lugar, simplemente redirigimos a /onboarding/owner y el flow
    // lee el borrador desde el repositorio en initState.
    return '/onboarding/owner';
  } catch (_) {
    return null;
  }
}

// ─── App ─────────────────────────────────────────────────────────────────────

class TuM2App extends StatelessWidget {
  const TuM2App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'TuM2',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary500,
          surface: AppColors.surface,
        ),
        scaffoldBackgroundColor: AppColors.scaffoldBg,
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
    );
  }
}

// ─── NAV-02: Splash con detección de sesión activa ───────────────────────────

/// Pantalla de splash que detecta el estado de sesión y navega al destino correcto.
class _SplashScreen extends StatefulWidget {
  const _SplashScreen();

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final user = FirebaseAuth.instance.currentUser;
    if (!mounted) return;

    if (user == null) {
      // Sin sesión → home (placeholder; en prod iría a /auth/login)
      context.go('/home');
      return;
    }

    // El guard global se encargará de detectar si hay un onboarding pendiente
    // cuando navegamos a /home. Si role=='owner' y no está completo, redirige.
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: const Center(
        child: CircularProgressIndicator(color: AppColors.primary500),
      ),
    );
  }
}

// ─── Placeholders (hasta implementar las pantallas reales) ───────────────────

class _PlaceholderScreen extends StatelessWidget {
  final String label;
  const _PlaceholderScreen({required this.label});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Center(
        child: Text(
          '→ $label',
          style: const TextStyle(fontSize: 20, color: AppColors.neutral700),
        ),
      ),
    );
  }
}
