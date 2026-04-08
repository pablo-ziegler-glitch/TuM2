import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../providers/owner_providers.dart';

/// Ruta intermedia para resolver el comercio del owner autenticado.
///
/// Evita meter consultas a Firestore en el redirect principal del router.
class OwnerResolvePage extends ConsumerStatefulWidget {
  const OwnerResolvePage({
    super.key,
    this.targetLocation,
  });

  final String? targetLocation;

  @override
  ConsumerState<OwnerResolvePage> createState() => _OwnerResolvePageState();
}

class _OwnerResolvePageState extends ConsumerState<OwnerResolvePage> {
  bool _didNavigate = false;

  @override
  Widget build(BuildContext context) {
    final resolution = ref.watch(ownerMerchantProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Mi comercio', style: AppTextStyles.headingSm),
      ),
      body: resolution.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary500),
        ),
        error: (_, __) => _ResolveErrorState(
          onRetry: () => ref.invalidate(ownerMerchantProvider),
        ),
        data: (result) {
          _scheduleNavigation(context, result.hasMerchant);
          return const Center(
            child: Text(
              'Resolviendo tu comercio...',
              style: AppTextStyles.bodySm,
            ),
          );
        },
      ),
    );
  }

  void _scheduleNavigation(BuildContext context, bool hasMerchant) {
    if (_didNavigate) return;
    _didNavigate = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!hasMerchant) {
        context.go(AppRoutes.onboardingOwner);
        return;
      }

      final target = _sanitizeOwnerTarget(widget.targetLocation);
      context.replace(target);
    });
  }

  String _sanitizeOwnerTarget(String? rawTarget) {
    if (rawTarget == null ||
        rawTarget.isEmpty ||
        rawTarget == AppRoutes.owner) {
      return AppRoutes.ownerDashboard;
    }

    final parsed = Uri.tryParse(rawTarget);
    final path = parsed?.path ?? rawTarget;
    if (!_isAllowedOwnerPath(path)) {
      return AppRoutes.ownerDashboard;
    }

    return parsed == null
        ? path
        : parsed.query.isEmpty
            ? path
            : '$path?${parsed.query}';
  }

  bool _isAllowedOwnerPath(String path) {
    return path == AppRoutes.ownerDashboard ||
        path == AppRoutes.ownerProducts ||
        path == AppRoutes.ownerSchedules ||
        path == AppRoutes.ownerSignals ||
        path == AppRoutes.ownerDuties;
  }
}

class _ResolveErrorState extends StatelessWidget {
  const _ResolveErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'No pudimos validar tu comercio.',
            style: AppTextStyles.headingSm,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Revisá tu conexión e intentá nuevamente.',
            style: AppTextStyles.bodySm,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
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
    );
  }
}
