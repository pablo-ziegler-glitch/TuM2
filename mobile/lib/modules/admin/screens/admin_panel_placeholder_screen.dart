import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/placeholder_screen.dart';

/// ADMIN-01 — Panel de administración (modal full-screen) placeholder.
/// Será reemplazado en TuM2-0077.
class AdminPanelPlaceholderScreen extends StatelessWidget {
  const AdminPanelPlaceholderScreen({super.key});

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
        title: const Text('Panel de administración',
            style: AppTextStyles.headingSm),
        centerTitle: false,
      ),
      body: PlaceholderScreen(
        screenId: 'ADMIN-01',
        label: 'Administración',
        roleRequired: 'admin',
        navActions: [
          NavAction(
            label: 'Comercios (ADMIN-02)',
            onTap: () => context.push(AppRoutes.adminMerchants),
          ),
          NavAction(
            label: 'Señales reportadas (ADMIN-04)',
            onTap: () => context.push(AppRoutes.adminSignals),
          ),
        ],
      ),
    );
  }
}
