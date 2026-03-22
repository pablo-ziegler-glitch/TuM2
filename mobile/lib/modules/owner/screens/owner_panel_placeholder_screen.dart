import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/placeholder_screen.dart';

/// OWNER-01 — Panel de comercio (modal full-screen) placeholder.
/// Será reemplazada en TuM2-0064.
class OwnerPanelPlaceholderScreen extends StatelessWidget {
  const OwnerPanelPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: CloseButton(
          color: AppColors.neutral900,
          onPressed: () => context.pop(),
        ),
        title: Text('Mi comercio', style: AppTextStyles.headingSm),
        centerTitle: false,
      ),
      body: PlaceholderScreen(
        screenId: 'OWNER-01',
        label: 'Panel de comercio',
        roleRequired: 'owner',
        navActions: [
          NavAction(
            label: 'Editar perfil (OWNER-02)',
            onTap: () => context.push(AppRoutes.ownerEdit),
          ),
          NavAction(
            label: 'Productos (OWNER-03)',
            onTap: () => context.push(AppRoutes.ownerProducts),
          ),
          NavAction(
            label: 'Horarios y señales (OWNER-06)',
            onTap: () => context.push(AppRoutes.ownerSchedules),
          ),
          NavAction(
            label: 'Turnos farmacia (OWNER-09)',
            onTap: () => context.push(AppRoutes.ownerDuties),
          ),
        ],
      ),
    );
  }
}
