import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../providers/owner_providers.dart';

/// Guard visual para rutas hijas OWNER.
///
/// Si el owner no tiene merchant asociado, redirige obligatoriamente
/// a `/onboarding/owner`.
class OwnerAccessGuardPage extends ConsumerStatefulWidget {
  const OwnerAccessGuardPage({
    super.key,
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  ConsumerState<OwnerAccessGuardPage> createState() => _OwnerAccessGuardState();
}

class _OwnerAccessGuardState extends ConsumerState<OwnerAccessGuardPage> {
  bool _redirectedToOnboarding = false;

  @override
  Widget build(BuildContext context) {
    final resolution = ref.watch(ownerMerchantProvider);
    return resolution.when(
      loading: () => _GuardScaffold(
        title: widget.title,
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.primary500),
        ),
      ),
      error: (_, __) => _GuardScaffold(
        title: widget.title,
        child: _GuardError(
          onRetry: () => ref.invalidate(ownerMerchantProvider),
        ),
      ),
      data: (result) {
        if (!result.hasMerchant) {
          _redirectToOnboarding(context);
          return _GuardScaffold(
            title: widget.title,
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        return widget.child;
      },
    );
  }

  void _redirectToOnboarding(BuildContext context) {
    if (_redirectedToOnboarding) return;
    _redirectedToOnboarding = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.go(AppRoutes.onboardingOwner);
    });
  }
}

class _GuardScaffold extends StatelessWidget {
  const _GuardScaffold({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(title, style: AppTextStyles.headingSm),
      ),
      body: child,
    );
  }
}

class _GuardError extends StatelessWidget {
  const _GuardError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'No pudimos validar tu comercio.',
              style: AppTextStyles.headingSm,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'Intentá nuevamente para continuar.',
              style: AppTextStyles.bodySm,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary500,
                foregroundColor: Colors.white,
              ),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
