import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/import_batch_ui.dart';

/// Modal de confirmación para revertir una importación completa.
/// Patrón destructivo: botón rojo + advertencia explícita + audit log notice.
class RevertConfirmDialog extends StatelessWidget {
  const RevertConfirmDialog({
    super.key,
    required this.batch,
    required this.onConfirm,
    required this.onCancel,
  });

  final ImportBatchUi batch;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ícono de advertencia
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.warningBg,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.tertiary200),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.warningFg,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            // Título
            Text('¿Revertir?', style: AppTextStyles.headingMd),
            const SizedBox(height: 12),
            // Descripción
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: AppTextStyles.bodySm,
                children: [
                  const TextSpan(text: 'Esto desactivará los '),
                  TextSpan(
                    text: '${batch.createdCount} establecimientos',
                    style: AppTextStyles.bodySm.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.neutral900,
                    ),
                  ),
                  const TextSpan(text: ' creados en esta importación.'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Advertencia destructiva
            Text(
              'Esta acción no puede deshacerse.',
              style: AppTextStyles.bodySm.copyWith(
                color: AppColors.errorFg,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Botón de confirmar reversión
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onConfirm,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.errorFg,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'Confirmar reversión',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Botón cancelar
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onCancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.neutral700,
                  side: const BorderSide(color: AppColors.neutral300),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Cancelar'),
              ),
            ),
            const SizedBox(height: 16),
            // Nota de audit log
            Text(
              'AUDIT LOG ENTRY WILL BE CREATED',
              style: AppTextStyles.bodyXs.copyWith(
                letterSpacing: 0.8,
                color: AppColors.neutral400,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Abre el modal de confirmación de reversión y retorna true si se confirmó.
Future<bool> showRevertConfirmDialog(
  BuildContext context,
  ImportBatchUi batch,
) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) => RevertConfirmDialog(
      batch: batch,
      onConfirm: () => Navigator.of(ctx).pop(true),
      onCancel: () => Navigator.of(ctx).pop(false),
    ),
  );
  return result ?? false;
}
