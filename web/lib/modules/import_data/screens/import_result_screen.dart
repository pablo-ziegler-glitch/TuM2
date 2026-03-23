import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/import_batch_ui.dart';
import '../widgets/revert_confirm_dialog.dart';

/// IMPORT-05 — Resultado de un batch de importación.
/// Muestra stats, próximos pasos, tabla de errores y opción de reversión.
class ImportResultScreen extends StatefulWidget {
  const ImportResultScreen({super.key, required this.batchId});
  final String batchId;

  @override
  State<ImportResultScreen> createState() => _ImportResultScreenState();
}

class _ImportResultScreenState extends State<ImportResultScreen> {
  late ImportBatchUi _batch;
  bool _reverted = false;

  @override
  void initState() {
    super.initState();
    // Busca el batch en los datos mock
    _batch = mockBatches.firstWhere(
      (b) => b.id == widget.batchId,
      orElse: () => mockBatches.first,
    );
  }

  Future<void> _handleRevert() async {
    final confirmed = await showRevertConfirmDialog(context, _batch);
    if (confirmed && mounted) {
      setState(() => _reverted = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Importación revertida. ${_batch.createdCount} establecimientos desactivados.',
            style: AppTextStyles.bodySm.copyWith(color: Colors.white),
          ),
          backgroundColor: AppColors.neutral900,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd \'de\' MMMM \'de\' yyyy — HH:mm \'hs\'', 'es').format(_batch.createdAt);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado
            _ResultHeader(batch: _batch, dateStr: dateStr, reverted: _reverted),
            const SizedBox(height: 28),
            // Stats de procesamiento
            _ProcessingStats(batch: _batch),
            const SizedBox(height: 24),
            // Fila inferior: próximos pasos + info del archivo
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _NextStepsCard(batch: _batch)),
                const SizedBox(width: 16),
                SizedBox(width: 300, child: _FileInfoCard(batch: _batch)),
              ],
            ),
            const SizedBox(height: 24),
            // Errores
            if (_batch.errors.isNotEmpty) _ErrorsSection(batch: _batch),
            const SizedBox(height: 24),
            // Botón de reversión
            if (!_reverted)
              _RevertSection(onRevert: _handleRevert)
            else
              _RevertedNotice(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/datasets/new'),
        backgroundColor: AppColors.primary500,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'Add New Commerce',
          style: AppTextStyles.labelMd.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}

// ── Encabezado ────────────────────────────────────────────────────────────────

class _ResultHeader extends StatelessWidget {
  const _ResultHeader({required this.batch, required this.dateStr, required this.reverted});
  final ImportBatchUi batch;
  final String dateStr;
  final bool reverted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Badge de estado
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: reverted ? AppColors.neutral100 : AppColors.successBg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                reverted ? Icons.undo : Icons.check_circle_outline,
                size: 14,
                color: reverted ? AppColors.neutral600 : AppColors.successFg,
              ),
              const SizedBox(width: 6),
              Text(
                reverted ? 'Importación revertida' : 'Importación completada',
                style: AppTextStyles.labelSm.copyWith(
                  color: reverted ? AppColors.neutral600 : AppColors.successFg,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Resultado del Batch #${batch.batchNumber}',
          style: AppTextStyles.headingLg,
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.neutral500),
            const SizedBox(width: 6),
            Text(dateStr, style: AppTextStyles.bodyXs),
            const SizedBox(width: 16),
            const Icon(Icons.person_outline, size: 14, color: AppColors.neutral500),
            const SizedBox(width: 6),
            Text('Farmacia ${batch.zone} — ${batch.createdBy}', style: AppTextStyles.bodyXs),
          ],
        ),
      ],
    );
  }
}

// ── Stats de procesamiento ────────────────────────────────────────────────────

class _ProcessingStats extends StatelessWidget {
  const _ProcessingStats({required this.batch});
  final ImportBatchUi batch;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _StatCard(label: 'PROCESADAS', value: batch.processedCount, icon: Icons.receipt_long_outlined, color: AppColors.neutral700)),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(label: 'CREADAS', value: batch.createdCount, icon: Icons.add_circle_outline, color: AppColors.successFg)),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(label: 'DUPLICADAS', value: batch.duplicatedCount, icon: Icons.copy_outlined, color: AppColors.tertiary500)),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(label: 'ERRORES', value: batch.errorCount, icon: Icons.error_outline, color: AppColors.errorFg)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neutral100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.labelSm.copyWith(letterSpacing: 0.8, color: AppColors.neutral500),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$value',
                style: AppTextStyles.headingLg.copyWith(color: color),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          Text('registros', style: AppTextStyles.bodyXs),
        ],
      ),
    );
  }
}

// ── Próximos pasos ────────────────────────────────────────────────────────────

class _NextStepsCard extends StatelessWidget {
  const _NextStepsCard({required this.batch});
  final ImportBatchUi batch;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neutral100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.visibility_outlined, size: 16, color: AppColors.neutral500),
              const SizedBox(width: 8),
              Text('Próximos pasos', style: AppTextStyles.headingSm),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.neutral50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Los ${batch.createdCount} establecimientos importados están ocultos. Revisalos y publicá los que sean correctos desde el listado de comercios en la app.',
              style: AppTextStyles.bodySm,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.storefront_outlined, size: 16),
              label: const Text('Ir al listado de comercios →'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary500,
                side: const BorderSide(color: AppColors.primary200),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Info del archivo ──────────────────────────────────────────────────────────

class _FileInfoCard extends StatelessWidget {
  const _FileInfoCard({required this.batch});
  final ImportBatchUi batch;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neutral100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Información del Archivo', style: AppTextStyles.labelMd),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.insert_drive_file_outlined, color: AppColors.primary500, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('farmacias_cordoba_v2.csv', style: AppTextStyles.labelSm.copyWith(color: AppColors.neutral900), overflow: TextOverflow.ellipsis),
                    Text('24 MB · formato UTF-8', style: AppTextStyles.bodyXs),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _InfoRow(label: 'Usuario', value: batch.createdBy),
          const SizedBox(height: 6),
          _InfoRow(label: 'Dataset', value: batch.datasetType.label),
          const SizedBox(height: 16),
          Text('Acciones del batch', style: AppTextStyles.labelSm.copyWith(color: AppColors.neutral500)),
          const SizedBox(height: 8),
          Text(
            'Si detectás que los datos importados son incorrectos, podés desactivar todos los registros importados y dejar el sistema como estaba antes.',
            style: AppTextStyles.bodyXs,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('$label: ', style: AppTextStyles.bodyXs.copyWith(color: AppColors.neutral500)),
        Text(value, style: AppTextStyles.bodyXs.copyWith(color: AppColors.neutral900)),
      ],
    );
  }
}

// ── Sección de errores ────────────────────────────────────────────────────────

class _ErrorsSection extends StatelessWidget {
  const _ErrorsSection({required this.batch});
  final ImportBatchUi batch;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neutral100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Text(
                  'Errores (${batch.errors.length})',
                  style: AppTextStyles.headingSm,
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.download_outlined, size: 16),
                  label: const Text('Descargar log de errores (.csv)'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.primary500),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.neutral100),
          // Encabezado de la tabla de errores
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: const [
                SizedBox(width: 70, child: _ColHeader('FILA #')),
                Expanded(child: _ColHeader('ESTABLECIMIENTO')),
                Expanded(child: _ColHeader('MOTIVO DEL ERROR')),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.neutral100),
          ...batch.errors.map((e) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 70,
                      child: Text('${e.row}', style: AppTextStyles.bodyXs.copyWith(color: AppColors.neutral500)),
                    ),
                    Expanded(
                      child: Text(e.establishmentName, style: AppTextStyles.bodySm),
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.errorBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          e.reason,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.errorFg),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.neutral100),
            ],
          )),
        ],
      ),
    );
  }
}

class _ColHeader extends StatelessWidget {
  const _ColHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.neutral500, letterSpacing: 0.6),
    );
  }
}

// ── Sección de reversión ──────────────────────────────────────────────────────

class _RevertSection extends StatelessWidget {
  const _RevertSection({required this.onRevert});
  final VoidCallback onRevert;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.errorFg.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.errorFg, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Zona de peligro', style: AppTextStyles.labelMd.copyWith(color: AppColors.errorFg)),
                const SizedBox(height: 2),
                Text(
                  'Revertir la importación desactivará todos los establecimientos creados en este batch.',
                  style: AppTextStyles.bodyXs,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          OutlinedButton.icon(
            onPressed: onRevert,
            icon: const Icon(Icons.undo, size: 16),
            label: const Text('Revertir importación completa'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.errorFg,
              side: const BorderSide(color: AppColors.errorFg),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _RevertedNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.neutral100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: AppColors.neutral600, size: 20),
          const SizedBox(width: 12),
          Text(
            'Importación revertida correctamente. Audit log generado.',
            style: AppTextStyles.bodySm.copyWith(color: AppColors.neutral700),
          ),
        ],
      ),
    );
  }
}
