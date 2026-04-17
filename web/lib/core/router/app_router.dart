import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

import '../../modules/auth/login_screen.dart';
import '../../shell/admin_shell.dart';
import '../../modules/import_data/screens/import_list_screen.dart';
import '../../modules/import_data/screens/import_wizard_screen.dart';
import '../../modules/import_data/screens/import_result_screen.dart';
import '../../modules/import_data/screens/import_batch_history_screen.dart';
import '../../modules/catalog_limits/screens/catalog_limits_screen.dart';
import '../../modules/merchant_claims/screens/merchant_claims_review_screen.dart';

/// Router principal del portal admin.
/// Rutas disponibles:
///   /dashboard              — panel principal (placeholder)
///   /businesses             — límites de catálogo (global/categoría/override)
///   /imports                — overview dashboard de importaciones
///   /imports/new            — wizard de nueva importación (6 pasos)
///   /imports/history        — historial de batches con filtros
///   /imports/:id            — detalle y auditoría de un batch específico
///   /claims                 — cola manual de revisión de claims (admin)
///   /templates              — plantillas de importación (placeholder)
///   /analytics              — analítica (placeholder)
///   /settings               — configuración (placeholder)
final appRouter = GoRouter(
  initialLocation: '/imports',
  refreshListenable: _AuthRefreshNotifier(),
  redirect: (context, state) {
    final isLoggedIn = FirebaseAuth.instance.currentUser != null;
    final isLoginRoute = state.matchedLocation == '/login';

    if (!isLoggedIn && !isLoginRoute) return '/login';
    if (isLoggedIn && isLoginRoute) return '/imports';
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    ShellRoute(
      builder: (context, state, child) => AdminShell(child: child),
      routes: [
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const _PlaceholderScreen(
            label: 'Panel',
            description: 'Panel principal de métricas',
            storyCardId: 'TuM2-0084',
          ),
        ),
        GoRoute(
          path: '/businesses',
          builder: (context, state) => const CatalogLimitsScreen(),
        ),
        GoRoute(
          path: '/catalog-limits',
          redirect: (context, state) => '/businesses',
        ),
        GoRoute(
          path: '/imports',
          builder: (context, state) => const ImportListScreen(),
        ),
        GoRoute(
          path: '/imports/new',
          builder: (context, state) => const ImportWizardScreen(),
        ),
        GoRoute(
          path: '/imports/history',
          builder: (context, state) => const ImportBatchHistoryScreen(),
        ),
        GoRoute(
          path: '/imports/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return ImportResultScreen(batchId: id);
          },
        ),
        GoRoute(
          path: '/claims',
          builder: (context, state) => const MerchantClaimsReviewScreen(),
        ),
        // Rutas legacy para compatibilidad con referencias anteriores
        GoRoute(path: '/datasets', redirect: (context, state) => '/imports'),
        GoRoute(
          path: '/datasets/new',
          redirect: (context, state) => '/imports/new',
        ),
        GoRoute(
          path: '/datasets/:id',
          redirect: (context, state) {
            final id = state.pathParameters['id']!;
            return '/imports/$id';
          },
        ),
        GoRoute(
          path: '/templates',
          builder: (context, state) => const _PlaceholderScreen(
            label: 'Plantillas',
            description: 'Plantillas de importación y mapeo de campos',
            storyCardId: 'TuM2-xxxx',
          ),
        ),
        GoRoute(
          path: '/analytics',
          builder: (context, state) => const _PlaceholderScreen(
            label: 'Analitica',
            description: 'Analítica de importaciones y calidad de datos',
            storyCardId: 'TuM2-0084',
          ),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const _PlaceholderScreen(
            label: 'Configuracion',
            description: 'Configuración del panel admin',
            storyCardId: 'TuM2-xxxx',
          ),
        ),
      ],
    ),
  ],
);

class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier() {
    _subscription = FirebaseAuth.instance.authStateChanges().listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<User?> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

/// Pantalla de placeholder para secciones del admin aún no implementadas.
class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({
    required this.label,
    required this.description,
    required this.storyCardId,
  });
  final String label;
  final String description;
  final String storyCardId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2EE),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.construction_outlined,
              size: 40,
              color: Color(0xFFB0AE9F),
            ),
            const SizedBox(height: 16),
            Text(
              label,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2D2D26),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(fontSize: 13, color: Color(0xFF7E7C6D)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF2FF),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Tarjeta objetivo: $storyCardId',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF1D4ED8),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
