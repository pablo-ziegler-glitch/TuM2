import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../shared/widgets/placeholder_screen.dart';

/// HOME-01 — Pantalla principal (tab Inicio) placeholder.
/// Será reemplazada en TuM2-0055.
class HomePlaceholderScreen extends StatelessWidget {
  const HomePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderScreen(
      screenId: 'HOME-01',
      label: 'Inicio',
      navActions: [
        NavAction(
          label: 'Abierto ahora (HOME-02)',
          onTap: () => context.push(AppRoutes.homeAbiertoAhora),
        ),
        NavAction(
          label: 'Farmacias de turno (HOME-03)',
          onTap: () => context.push(AppRoutes.homeFarmacias),
        ),
        NavAction(
          label: 'Detalle comercio (DETAIL-01)',
          onTap: () => context.push(AppRoutes.commerceDetailPath('demo-001')),
        ),
      ],
    );
  }
}
