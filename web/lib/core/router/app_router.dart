import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

import '../../shell/admin_shell.dart';
import '../../modules/import_data/screens/import_list_screen.dart';
import '../../modules/import_data/screens/import_wizard_screen.dart';
import '../../modules/import_data/screens/import_result_screen.dart';

/// Router principal del portal admin.
/// Rutas disponibles:
///   /datasets           — lista de importaciones (vacío o con datos)
///   /datasets/new       — wizard de nueva importación
///   /datasets/:id       — resultado de un batch específico
///   /commerces          — placeholder hasta implementar TuM2-0078
///   /settings           — placeholder hasta implementar configuración admin
final appRouter = GoRouter(
  initialLocation: '/datasets',
  routes: [
    ShellRoute(
      builder: (context, state, child) => AdminShell(child: child),
      routes: [
        GoRoute(
          path: '/datasets',
          builder: (context, state) => const ImportListScreen(),
        ),
        GoRoute(
          path: '/datasets/new',
          builder: (context, state) => const ImportWizardScreen(),
        ),
        GoRoute(
          path: '/datasets/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return ImportResultScreen(batchId: id);
          },
        ),
        GoRoute(
          path: '/commerces',
          builder: (context, state) => const _PlaceholderScreen(
            label: 'Comercios',
            description: 'Listado y moderación de comercios — TuM2-0078',
          ),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const _PlaceholderScreen(
            label: 'Configuración',
            description: 'Configuración del panel admin',
          ),
        ),
      ],
    ),
  ],
);

/// Pantalla de placeholder para secciones del admin aún no implementadas.
class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.label, required this.description});
  final String label;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2EE),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.construction_outlined, size: 40, color: Color(0xFFB0AE9F)),
            const SizedBox(height: 16),
            Text(
              label,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF2D2D26)),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(fontSize: 13, color: Color(0xFF7E7C6D)),
            ),
          ],
        ),
      ),
    );
  }
}
