import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/import_batch_ui.dart';

/// Paso 4 del wizard: Configuración del mapeo de campos, deduplicación y visibilidad.
/// Incluye columna de confianza IA y panel Source Insight lateral.
class WizardStepConfig extends StatefulWidget {
  const WizardStepConfig({
    super.key,
    required this.mappings,
    required this.deduplicationEnabled,
    required this.visibilityAfterImport,
    required this.onMappingsChanged,
    required this.onDeduplicationChanged,
    required this.onVisibilityChanged,
  });

  final List<FieldMapping> mappings;
  final bool deduplicationEnabled;
  final String visibilityAfterImport;
  final ValueChanged<List<FieldMapping>> onMappingsChanged;
  final ValueChanged<bool> onDeduplicationChanged;
  final ValueChanged<String> onVisibilityChanged;

  @override
  State<WizardStepConfig> createState() => _WizardStepConfigState();
}

class _WizardStepConfigState extends State<WizardStepConfig> {
  static const _tum2Fields = tum2AssignableFields;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Field Mapping', style: AppTextStyles.headingMd),
        const SizedBox(height: 4),
        Text(
          'Review and adjust how CSV columns map to TuM2 fields. AI confidence scores are shown for each mapping.',
          style: AppTextStyles.bodySm.copyWith(color: AppColors.neutral500),
        ),
        const SizedBox(height: 20),
        // Tabla + Source Insight panel lateral
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tabla de mapeo
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.neutral100),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    _MappingTableHeader(),
                    const Divider(height: 1, color: AppColors.neutral100),
                    ...widget.mappings.asMap().entries.map((entry) {
                      final i = entry.key;
                      final m = entry.value;
                      return Column(
                        children: [
                          _MappingRow(
                            mapping: m,
                            tum2Fields: _tum2Fields,
                            onToggle: (enabled) =>
                                _updateMapping(i, enabled: enabled),
                            onFieldChanged: (field) =>
                                _updateMapping(i, tum2Field: field),
                          ),
                          if (i < widget.mappings.length - 1)
                            const Divider(
                              height: 1,
                              color: AppColors.neutral100,
                            ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Source Insight panel
            SizedBox(
              width: 220,
              child: _SourceInsightPanel(mappings: widget.mappings),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Deduplicación y visibilidad
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _SettingsCard(
                title: 'Deduplication',
                description:
                    'Prevent duplicate entries by comparing Name and Address before creating new records.',
                child: Row(
                  children: [
                    Switch(
                      value: widget.deduplicationEnabled,
                      onChanged: widget.onDeduplicationChanged,
                      activeColor: AppColors.primary500,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.deduplicationEnabled ? 'Enabled' : 'Disabled',
                      style: AppTextStyles.labelSm,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _SettingsCard(
                title: 'Visibility after import',
                description:
                    'Records imported as hidden require review before becoming public in the app.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _RadioOption(
                      label: 'Hidden (staging)',
                      description:
                          'Records will be staged and not visible to users',
                      value: 'hidden',
                      groupValue: widget.visibilityAfterImport,
                      onChanged: widget.onVisibilityChanged,
                    ),
                    const SizedBox(height: 8),
                    _RadioOption(
                      label: 'Visible',
                      description:
                          'Records will be publicly visible immediately',
                      value: 'visible',
                      groupValue: widget.visibilityAfterImport,
                      onChanged: widget.onVisibilityChanged,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _updateMapping(int index, {bool? enabled, String? tum2Field}) {
    final updated = List<FieldMapping>.from(widget.mappings);
    final m = updated[index];
    updated[index] = FieldMapping(
      csvColumn: m.csvColumn,
      tum2Field: tum2Field ?? m.tum2Field,
      enabled: enabled ?? m.enabled,
      required: m.required,
      aiConfidence: m.aiConfidence,
      sampleValue: m.sampleValue,
    );
    widget.onMappingsChanged(updated);
  }
}

class _MappingTableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      color: AppColors.neutral500,
      letterSpacing: 0.6,
    );
    return Container(
      color: AppColors.neutral50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: const Row(
        children: [
          SizedBox(width: 48, child: Text('IMPORT', style: style)),
          Expanded(child: Text('CSV COLUMN', style: style)),
          SizedBox(width: 32),
          Expanded(child: Text('TUM2 FIELD', style: style)),
          SizedBox(width: 80, child: Text('AI CONFIDENCE', style: style)),
          SizedBox(width: 90, child: Text('STATUS', style: style)),
        ],
      ),
    );
  }
}

class _MappingRow extends StatelessWidget {
  const _MappingRow({
    required this.mapping,
    required this.tum2Fields,
    required this.onToggle,
    required this.onFieldChanged,
  });

  final FieldMapping mapping;
  final List<String> tum2Fields;
  final ValueChanged<bool> onToggle;
  final ValueChanged<String?> onFieldChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Toggle
          SizedBox(
            width: 48,
            child: Switch(
              value: mapping.enabled,
              onChanged: mapping.required ? null : onToggle,
              activeColor: AppColors.primary500,
            ),
          ),
          // Campo CSV
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.neutral100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                mapping.csvColumn,
                style: AppTextStyles.bodySm.copyWith(
                  color: mapping.enabled
                      ? AppColors.neutral900
                      : AppColors.neutral500,
                ),
              ),
            ),
          ),
          // Flecha
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Icon(
              Icons.arrow_forward,
              size: 16,
              color: mapping.enabled
                  ? AppColors.neutral600
                  : AppColors.neutral300,
            ),
          ),
          // Campo TuM2
          Expanded(
            child: mapping.enabled
                ? Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.neutral200),
                      borderRadius: BorderRadius.circular(6),
                      color: AppColors.surface,
                    ),
                    child: DropdownButton<String>(
                      value: tum2Fields.contains(mapping.tum2Field)
                          ? mapping.tum2Field
                          : null,
                      isExpanded: true,
                      underline: const SizedBox(),
                      hint: Text(
                        'Seleccionar campo...',
                        style: AppTextStyles.bodyXs.copyWith(
                          color: AppColors.neutral500,
                        ),
                      ),
                      items: tum2Fields
                          .map(
                            (f) => DropdownMenuItem(
                              value: f,
                              child: Text(f, style: AppTextStyles.bodySm),
                            ),
                          )
                          .toList(),
                      onChanged: onFieldChanged,
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.neutral900,
                      ),
                    ),
                  )
                : Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: AppColors.neutral50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        '—',
                        style: AppTextStyles.bodyXs.copyWith(
                          color: AppColors.neutral400,
                        ),
                      ),
                    ),
                  ),
          ),
          // AI Confidence
          SizedBox(
            width: 80,
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: mapping.aiConfidence != null
                  ? _ConfidenceBar(confidence: mapping.aiConfidence!)
                  : Text(
                      '—',
                      style: AppTextStyles.bodyXs.copyWith(
                        color: AppColors.neutral400,
                      ),
                    ),
            ),
          ),
          // Estado
          SizedBox(
            width: 90,
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: mapping.required
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.errorBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Required',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.errorFg,
                        ),
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: mapping.enabled
                            ? AppColors.successBg
                            : AppColors.neutral100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        mapping.enabled ? 'Optional' : 'Ignored',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: mapping.enabled
                              ? AppColors.successFg
                              : AppColors.neutral500,
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.title,
    required this.description,
    required this.child,
  });
  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.neutral100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.labelMd),
          const SizedBox(height: 6),
          Text(description, style: AppTextStyles.bodyXs),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _RadioOption extends StatelessWidget {
  const _RadioOption({
    required this.label,
    required this.description,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });
  final String label;
  final String description;
  final String value;
  final String groupValue;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final isSelected = value == groupValue;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary50 : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary200 : AppColors.neutral200,
          ),
        ),
        child: Row(
          children: [
            Radio<String>(
              value: value,
              groupValue: groupValue,
              onChanged: (v) => onChanged(v!),
              activeColor: AppColors.primary500,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.labelMd),
                Text(description, style: AppTextStyles.bodyXs),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Barra visual de confianza IA para el mapeo de campos.
class _ConfidenceBar extends StatelessWidget {
  const _ConfidenceBar({required this.confidence});
  final double confidence; // 0.0 – 1.0

  @override
  Widget build(BuildContext context) {
    final color = confidence >= 0.9
        ? AppColors.successFg
        : confidence >= 0.7
        ? AppColors.warningFg
        : AppColors.errorFg;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${(confidence * 100).toStringAsFixed(0)}%',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const SizedBox(height: 3),
        SizedBox(
          height: 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: confidence,
              backgroundColor: AppColors.neutral100,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
      ],
    );
  }
}

/// Panel lateral con información de la fuente (columnas detectadas, ejemplos).
class _SourceInsightPanel extends StatelessWidget {
  const _SourceInsightPanel({required this.mappings});
  final List<FieldMapping> mappings;

  int get _mappedCount => mappings.where((m) => m.enabled).length;
  int get _totalCount => mappings.length;
  double get _avgConfidence {
    final withConf = mappings.where((m) => m.aiConfidence != null).toList();
    if (withConf.isEmpty) return 0;
    return withConf.fold<double>(0, (s, m) => s + m.aiConfidence!) /
        withConf.length;
  }

  @override
  Widget build(BuildContext context) {
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
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_outlined,
                size: 14,
                color: AppColors.primary500,
              ),
              const SizedBox(width: 6),
              Text(
                'Source Insight',
                style: AppTextStyles.labelMd.copyWith(fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _InsightRow(label: 'Columns detected', value: '$_totalCount'),
          _InsightRow(label: 'Mapped', value: '$_mappedCount / $_totalCount'),
          _InsightRow(
            label: 'Avg AI confidence',
            value: '${(_avgConfidence * 100).toStringAsFixed(0)}%',
            valueColor: _avgConfidence >= 0.85
                ? AppColors.successFg
                : AppColors.warningFg,
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.neutral100),
          const SizedBox(height: 12),
          Text(
            'Sample values',
            style: AppTextStyles.bodyXs.copyWith(
              color: AppColors.neutral400,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ...mappings
              .where((m) => m.sampleValue != null && m.enabled)
              .map(
                (m) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.csvColumn,
                        style: AppTextStyles.bodyXs.copyWith(
                          color: AppColors.neutral400,
                        ),
                      ),
                      Text(
                        m.sampleValue!,
                        style: AppTextStyles.bodyXs.copyWith(
                          color: AppColors.neutral700,
                        ),
                        overflow: TextOverflow.ellipsis,
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

class _InsightRow extends StatelessWidget {
  const _InsightRow({
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
            child: Text(
              label,
              style: AppTextStyles.bodyXs.copyWith(color: AppColors.neutral500),
            ),
          ),
          Text(
            value,
            style: AppTextStyles.labelSm.copyWith(
              fontSize: 11,
              color: valueColor ?? AppColors.neutral800,
            ),
          ),
        ],
      ),
    );
  }
}
