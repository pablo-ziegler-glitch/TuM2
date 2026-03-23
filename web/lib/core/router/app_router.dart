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
      ],
    ),
  ],
);
