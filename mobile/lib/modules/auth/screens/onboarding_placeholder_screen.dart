import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../shared/widgets/placeholder_screen.dart';

/// AUTH-02 — Placeholder de bienvenida inicial.
/// Será reemplazada en TuM2-0029.
class OnboardingPlaceholderScreen extends StatelessWidget {
  const OnboardingPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderScreen(
      screenId: 'AUTH-02',
      label: 'Bienvenida inicial',
      navActions: [
        NavAction(
          label: 'Ir a acceso (AUTH-03)',
          onTap: () => context.go(AppRoutes.login),
        ),
      ],
    );
  }
}
