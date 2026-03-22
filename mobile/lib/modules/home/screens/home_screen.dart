import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// HOME-01 — Home placeholder
///
/// Pantalla de destino post-login. Placeholder hasta que se implemente
/// el módulo home completo (TuM2-0055).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text('TuM2', style: AppTextStyles.headingSm),
        actions: [
          TextButton(
            onPressed: () =>
                ref.read(authNotifierProvider.notifier).signOut(),
            child: Text(
              'Salir',
              style: AppTextStyles.labelSm.copyWith(
                color: AppColors.primary500,
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.storefront_outlined,
              size: 64,
              color: AppColors.primary300,
            ),
            const SizedBox(height: 16),
            Text('Bienvenido a TuM2', style: AppTextStyles.headingMd),
            if (user?.email != null) ...[
              const SizedBox(height: 8),
              Text(user!.email!, style: AppTextStyles.bodySm),
            ],
            const SizedBox(height: 8),
            Text(
              'HOME-01 — próximamente',
              style: AppTextStyles.bodyXs,
            ),
          ],
        ),
      ),
    );
  }
}
