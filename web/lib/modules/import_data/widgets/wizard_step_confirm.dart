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
        Text('Confirm Import', style: AppTextStyles.headingSm),
        const SizedBox(height: 4),
        Text(
          'Review the full configuration before starting the import process.',
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
                    title: 'Import Configuration',
                    icon: Icons.settings_outlined,
                    children: [
                      _SummaryRow(
                        label: 'Import Type',
                        value: importType.label,
                      ),
                      _SummaryRow(
                        label: 'Template',
                        value: templateName ?? 'Custom Schema',
                      ),
                      _SummaryRow(
                        label: 'Zone / Source',
                        value: zone.isEmpty ? '—' : zone,
                      ),
                      _SummaryRow(
                        label: 'File',
                        value: fileName ?? 'No file selected',
                      ),
                      _SummaryRow(
                        label: 'Deduplication',
                        value: deduplicationEnabled ? 'Enabled' : 'Disabled',
                      ),
                      _SummaryRow(
                        label: 'Visibility after import',
                        value: visibilityAfterImport == 'visible'
                            ? 'Public'
                            : 'Hidden (staging)',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Validation Summary',
                    icon: Icons.fact_check_outlined,
                    children: [
                      _SummaryRow(label: 'Total rows', value: '$totalRows'),
                      _SummaryRow(
                        label: 'Valid rows',
                        value: '$validRows',
                        valueColor: AppColors.successFg,
                      ),
                      _SummaryRow(
                        label: 'Warning rows',
                        value: '$warningRows',
                        valueColor: AppColors.warningFg,
                      ),
                      _SummaryRow(
                        label: 'Error rows (skipped)',
                        value: '$errorRows',
                        valueColor: AppColors.errorFg,
                      ),
                    ],
                  ),
                  if (fieldMappings.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _SectionCard(
                      title: 'Field Mappings',
                      icon: Icons.compare_arrows_outlined,
                      children: fieldMappings
                          .map(
                            (m) => _SummaryRow(
                              label: m.csvColumn,
                              value: m.enabled ? m.tum2Field : 'Disabled',
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
                hasIssues ? 'Ready with warnings' : 'Ready to import',
                style: AppTextStyles.labelMd.copyWith(fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hasIssues
                ? '$validRows rows will be imported. $errorRows rows will be skipped due to validation errors.'
                : 'All $validRows rows passed validation and are ready for staging.',
            style: AppTextStyles.bodyXs.copyWith(color: AppColors.neutral600),
          ),
        ],
      ),
    );
  }

  Widget _buildPipelineInfo() {
    const stages = [
      ('Parse & Normalize', Icons.transform_outlined),
      ('Deduplicate', Icons.merge_type_outlined),
      ('Stage to Firestore', Icons.storage_outlined),
      ('Audit Log Entry', Icons.history_outlined),
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
            'Pipeline Steps',
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
