import 'package:flutter/material.dart';
import 'modules/brand/onboarding_owner/models/onboarding_draft.dart';
import 'modules/brand/onboarding_owner/onboarding_owner_flow.dart';
import 'core/theme/app_colors.dart';

/// Punto de entrada de la app.
///
/// En producción este archivo inicializa Firebase y usa go_router + Riverpod.
/// En esta iteración de diseño de pantallas, monta el flujo de onboarding OWNER
/// directamente para facilitar la revisión visual de todos los estados (EX-01 a EX-14).
///
/// Para probar un estado específico, modificar [_demoMode] abajo.
void main() {
  runApp(const TuM2App());
}

/// Modo de demo. Cambiar para revisar los distintos estados del flujo:
///   'fresh'    → flujo nuevo sin borrador (EX-08 visible al intentar avanzar vacío)
///   'draft'    → borrador reciente (EX-02)
///   'expiring' → borrador por vencer (EX-03)
///   'expired'  → borrador vencido (EX-04)
const _demoMode = 'fresh';

class TuM2App extends StatelessWidget {
  const TuM2App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TuM2',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary500,
          surface: AppColors.surface,
        ),
        scaffoldBackgroundColor: AppColors.scaffoldBg,
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: _DemoRoot(),
    );
  }
}

class _DemoRoot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final draft = _buildDemoDraft();

    return OnboardingOwnerFlow(
      existingDraft: draft,
      onComplete: () {
        // En producción → go_router.go('/owner/panel')
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('→ OWNER-01: Panel Mi comercio')),
        );
      },
      onExit: () {
        // En producción → go_router.go('/home')
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('→ HOME-01: salió del flujo')),
        );
      },
    );
  }

  OnboardingDraft? _buildDemoDraft() {
    switch (_demoMode) {
      case 'draft':
        return OnboardingDraft(
          draftMerchantId: 'demo-draft-001',
          currentStep: 'step_2',
          step1: const Step1Data(name: 'Farmacia del Centro', categoryId: 'pharmacy'),
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
          expiresAt: DateTime.now().add(const Duration(hours: 70)),
        );
      case 'expiring':
        return OnboardingDraft(
          draftMerchantId: 'demo-draft-002',
          currentStep: 'step_3',
          step1: const Step1Data(name: 'Farmacia del Centro', categoryId: 'pharmacy'),
          step2: const Step2Data(
            address: 'Av. Corrientes 1234, CABA',
            lat: -34.6037,
            lng: -58.3816,
            zoneId: 'almagro-norte',
          ),
          createdAt: DateTime.now().subtract(const Duration(hours: 66)),
          expiresAt: DateTime.now().add(const Duration(hours: 6)),
        );
      case 'expired':
        return OnboardingDraft(
          draftMerchantId: 'demo-draft-003',
          currentStep: 'step_2',
          step1: const Step1Data(name: 'Farmacia del Centro', categoryId: 'pharmacy'),
          createdAt: DateTime.now().subtract(const Duration(hours: 76)),
          expiresAt: DateTime.now().subtract(const Duration(hours: 4)),
        );
      case 'fresh':
      default:
        return null;
    }
  }
}
