import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';

/// EX-01 · Modal de salida
/// Bottom sheet con 3 opciones de jerarquía diferente.
/// Disparador: botón X en cualquier paso del flujo.
Future<ExitAction?> showExitModal(BuildContext context) {
  return showModalBottomSheet<ExitAction>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const _ExitModalContent(),
  );
}

enum ExitAction { saveDraft, discard, keepGoing }

class _ExitModalContent extends StatelessWidget {
  const _ExitModalContent();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.neutral300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            const Text('¿Salir del registro?', style: AppTextStyles.headingMd),
            const SizedBox(height: 8),
            const Text(
              'Tenés información ingresada. Guardamos un borrador por 72 hs para que puedas retomar después.',
              style: AppTextStyles.bodySm,
            ),
            const SizedBox(height: 24),

            // CTA primario — outline azul (acción promovida por el sistema)
            OutlinedButton(
              onPressed: () => Navigator.pop(context, ExitAction.saveDraft),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary500,
                side: const BorderSide(color: AppColors.primary500),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Guardar borrador y salir'),
            ),
            const SizedBox(height: 10),

            // CTA secundario — fondo rojo claro (visible pero sin prominencia)
            TextButton(
              onPressed: () => Navigator.pop(context, ExitAction.discard),
              style: TextButton.styleFrom(
                backgroundColor: AppColors.errorBg,
                foregroundColor: AppColors.errorFg,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Descartar y salir'),
            ),
            const SizedBox(height: 10),

            // Terciario — texto puro (menor peso)
            TextButton(
              onPressed: () => Navigator.pop(context, ExitAction.keepGoing),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary500,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Seguir completando'),
            ),
          ],
        ),
      ),
    );
  }
}
