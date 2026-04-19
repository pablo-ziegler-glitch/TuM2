import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/import_batch_ui.dart';

/// Paso 2 del wizard: Vista previa del archivo y resumen de validaciones.
class WizardStepPreview extends StatelessWidget {
  const WizardStepPreview({super.key, required this.rows});

  final List<CsvPreviewRow> rows;

  int get _errorCount => rows.where((r) => r.hasError).length;
  int get _warningCount => rows.where((r) => r.hasWarning).length;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Banner de detección
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.infoBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.primary100),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline,
                size: 16,
                color: AppColors.primary500,
              ),
              const SizedBox(width: 10),
              Text(
                'Detectamos ${rows.length} filas y 12 columnas.',
                style: AppTextStyles.bodySm.copyWith(
                  color: AppColors.primary700,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Separador: punto y coma (;) — El archivo parece ser un CSV estándar.',
                style: AppTextStyles.bodyXs.copyWith(
                  color: AppColors.primary600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Encabezado de la previsualización
        Row(
          children: [
            Text(
              'Vista previa (primeras 10 filas)',
              style: AppTextStyles.labelMd,
            ),
            const Spacer(),
            if (_errorCount > 0 || _warningCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warningBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.tertiary200),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber,
                      size: 14,
                      color: AppColors.warningFg,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${_errorCount + _warningCount} errores de validación',
                      style: AppTextStyles.labelSm.copyWith(
                        color: AppColors.warningFg,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        // Tabla de preview
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.neutral100),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Column(
                children: [
                  _PreviewTableHeader(),
                  Expanded(
                    child: ListView.separated(
                      itemCount: rows.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: AppColors.neutral100),
                      itemBuilder: (context, i) =>
                          _PreviewTableRow(row: rows[i]),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    color: AppColors.neutral50,
                    child: Text(
                      'Mostrando las primeras 10 de ${rows.length} filas',
                      style: AppTextStyles.bodyXs,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Tarjetas de análisis
        Row(
          children: [
            Expanded(
              child: _AnalysisCard(
                icon: Icons.text_fields_outlined,
                iconColor: AppColors.primary500,
                title: 'Encoding',
                subtitle:
                    'Detectado: UTF-8. Caracteres especiales (acentos) se muestran correctamente.',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _AnalysisCard(
                icon: Icons.grid_on_outlined,
                iconColor: AppColors.neutral700,
                title: 'Estructura',
                subtitle:
                    'Se ignora la primera fila (encabezados). El resto ingresará al proceso de importación final.',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _AnalysisCard(
                icon: Icons.rule_outlined,
                iconColor: _errorCount + _warningCount > 0
                    ? AppColors.errorFg
                    : AppColors.successFg,
                title: 'Validaciones',
                subtitle:
                    '${_errorCount + _warningCount} fila${_errorCount + _warningCount != 1 ? 's' : ''} con coordenadas erróneas. Podés corregirlas o el proceso de importación las omitirá.',
                hasAlert: _errorCount > 0,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PreviewTableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      color: AppColors.neutral500,
      letterSpacing: 0.5,
    );
    const cols = [
      'ESTABLECIMIENTO NOMBRE',
      'LOCALIDAD',
      'TIPOLOGÍA',
      'DOMICILIO',
      'LONGITUD',
      'LATITUD',
      'ESTADO',
    ];

    return Container(
      color: AppColors.neutral50,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: cols
            .map(
              (c) => Expanded(
                child: Text(c, style: style, overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _PreviewTableRow extends StatelessWidget {
  const _PreviewTableRow({required this.row});
  final CsvPreviewRow row;

  @override
  Widget build(BuildContext context) {
    final bg = row.hasError
        ? AppColors.errorBg
        : (row.hasWarning ? AppColors.warningBg : Colors.transparent);

    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              row.name,
              style: AppTextStyles.bodyXs,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(child: Text(row.locality, style: AppTextStyles.bodyXs)),
          Expanded(child: Text(row.typology, style: AppTextStyles.bodyXs)),
          Expanded(
            child: Text(
              row.address,
              style: AppTextStyles.bodyXs,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: _CoordCell(
              value: row.longitude,
              hasError: row.hasError || row.hasWarning,
            ),
          ),
          Expanded(
            child: _CoordCell(value: row.latitude, hasError: row.hasError),
          ),
          Expanded(
            child: _StatusDot(
              hasError: row.hasError,
              hasWarning: row.hasWarning,
            ),
          ),
        ],
      ),
    );
  }
}

class _CoordCell extends StatelessWidget {
  const _CoordCell({required this.value, required this.hasError});
  final String value;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      style: AppTextStyles.bodyXs.copyWith(
        color: hasError ? AppColors.errorFg : AppColors.neutral900,
        fontWeight: hasError ? FontWeight.w600 : FontWeight.w400,
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.hasError, required this.hasWarning});
  final bool hasError;
  final bool hasWarning;

  @override
  Widget build(BuildContext context) {
    if (hasError)
      return const Icon(
        Icons.warning_amber_rounded,
        size: 14,
        color: AppColors.errorFg,
      );
    if (hasWarning)
      return const Icon(
        Icons.warning_amber_rounded,
        size: 14,
        color: AppColors.warningFg,
      );
    return const Icon(
      Icons.check_circle_outline,
      size: 14,
      color: AppColors.successFg,
    );
  }
}

class _AnalysisCard extends StatelessWidget {
  const _AnalysisCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.hasAlert = false,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool hasAlert;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hasAlert ? AppColors.errorBg : AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasAlert
              ? AppColors.errorFg.withValues(alpha: 0.3)
              : AppColors.neutral100,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Text(title, style: AppTextStyles.labelMd),
            ],
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: AppTextStyles.bodyXs),
        ],
      ),
    );
  }
}
