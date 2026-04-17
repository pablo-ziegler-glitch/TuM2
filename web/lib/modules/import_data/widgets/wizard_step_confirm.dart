import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/import_batch_ui.dart';

/// Paso 6 del wizard — Confirmación final de la importación.
/// Muestra resumen completo antes de iniciar el proceso.
class WizardStepConfirm extends StatelessWidget {
  const WizardStepConfirm({
    super.key,
    required this.importType,
    required this.templateName,
    required this.zone,
    required this.fileName,
    required this.totalRows,
    required this.validRows,
    required this.warningRows,
    required this.errorRows,
    required this.fieldMappings,
    required this.deduplicationEnabled,
    required this.visibilityAfterImport,
  });

  final ImportType importType;
  final String? templateName;
  final String zone;
  final String? fileName;
  final int totalRows;
  final int validRows;
  final int warningRows;
  final int errorRows;
  final List<FieldMapping> fieldMappings;
  final bool deduplicationEnabled;
  final String visibilityAfterImport;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Confirmar importacion', style: AppTextStyles.headingSm),
        const SizedBox(height: 4),
        Text(
          'Revisa la configuracion completa antes de iniciar el proceso de importacion.',
          style: AppTextStyles.bodySm.copyWith(color: AppColors.neutral500),
        ),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Panel izquierdo — resumen del import
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionCard(
                    title: 'Configuracion de importacion',
                    icon: Icons.settings_outlined,
                    children: [
                      _SummaryRow(
                        label: 'Tipo de importacion',
                        value: importType.label,
                      ),
                      _SummaryRow(
                        label: 'Template',
                        value: templateName ?? 'Esquema personalizado',
                      ),
                      _SummaryRow(
                        label: 'Zona / fuente',
                        value: zone.isEmpty ? '—' : zone,
                      ),
                      _SummaryRow(
                        label: 'Archivo',
                        value: fileName ?? 'Sin archivo seleccionado',
                      ),
                      _SummaryRow(
                        label: 'Deduplicacion',
                        value: deduplicationEnabled ? 'Activa' : 'Desactivada',
                      ),
                      _SummaryRow(
                        label: 'Visibilidad despues de importar',
                        value: visibilityAfterImport == 'visible'
                            ? 'Publica'
                            : 'Oculto (staging)',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Resumen de validacion',
                    icon: Icons.fact_check_outlined,
                    children: [
                      _SummaryRow(label: 'Filas totales', value: '$totalRows'),
                      _SummaryRow(
                        label: 'Filas validas',
                        value: '$validRows',
                        valueColor: AppColors.successFg,
                      ),
                      _SummaryRow(
                        label: 'Filas con advertencias',
                        value: '$warningRows',
                        valueColor: AppColors.warningFg,
                      ),
                      _SummaryRow(
                        label: 'Filas con error (omitidas)',
                        value: '$errorRows',
                        valueColor: AppColors.errorFg,
                      ),
                    ],
                  ),
                  if (fieldMappings.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _SectionCard(
                      title: 'Mapeos de campos',
                      icon: Icons.compare_arrows_outlined,
                      children: fieldMappings
                          .map(
                            (m) => _SummaryRow(
                              label: m.csvColumn,
                              value: m.enabled ? m.tum2Field : 'Desactivado',
                              valueColor: m.enabled
                                  ? null
                                  : AppColors.neutral400,
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 20),
            // Panel derecho — alertas y acciones
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildReadyBanner(),
                  const SizedBox(height: 16),
                  _buildPipelineInfo(),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReadyBanner() {
    final hasIssues = errorRows > 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasIssues
            ? AppColors.warningFg.withValues(alpha: 0.07)
            : AppColors.successFg.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasIssues
              ? AppColors.warningFg.withValues(alpha: 0.25)
              : AppColors.successFg.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasIssues
                    ? Icons.warning_amber_outlined
                    : Icons.check_circle_outline,
                size: 18,
                color: hasIssues ? AppColors.warningFg : AppColors.successFg,
              ),
              const SizedBox(width: 8),
              Text(
                hasIssues ? 'Lista con advertencias' : 'Lista para importar',
                style: AppTextStyles.labelMd.copyWith(fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hasIssues
                ? '$validRows filas se importaran. $errorRows filas se omitiran por errores de validacion.'
                : 'Las $validRows filas validas quedaron listas para pasar a staging.',
            style: AppTextStyles.bodyXs.copyWith(color: AppColors.neutral600),
          ),
        ],
      ),
    );
  }

  Widget _buildPipelineInfo() {
    const stages = [
      ('Parsear y normalizar', Icons.transform_outlined),
      ('Deduplicar', Icons.merge_type_outlined),
      ('Enviar a Firestore', Icons.storage_outlined),
      ('Registrar auditoria', Icons.history_outlined),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pasos del proceso',
            style: AppTextStyles.labelMd.copyWith(
              fontSize: 12,
              color: AppColors.neutral500,
            ),
          ),
          const SizedBox(height: 12),
          ...stages.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(s.$2, size: 15, color: AppColors.primary500),
                  const SizedBox(width: 10),
                  Text(
                    s.$1,
                    style: AppTextStyles.bodySm.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });
  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Icon(icon, size: 15, color: AppColors.neutral500),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: AppTextStyles.labelMd.copyWith(
                    fontSize: 12,
                    color: AppColors.neutral600,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.neutral100),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
  });
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: AppTextStyles.bodyXs.copyWith(color: AppColors.neutral500),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: AppTextStyles.labelSm.copyWith(
                fontSize: 12,
                color: valueColor ?? AppColors.neutral800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
