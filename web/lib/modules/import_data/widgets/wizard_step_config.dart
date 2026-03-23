import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/import_batch_ui.dart';

/// Paso 3 del wizard: Configuración del mapeo de campos, deduplicación y visibilidad.
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
  static const _tum2Fields = [
    'Nombre del Negocio',
    'Teléfono Principal',
    'Dirección Completa',
    'Horario de Atención',
    'Categoría Principal',
    'Descripción',
    'Sitio Web',
    'Email de Contacto',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Importar Datos', style: AppTextStyles.headingMd),
        const SizedBox(height: 4),
        Text(
          'Configurá la correspondencia de tus datos y las opciones de importación.',
          style: AppTextStyles.bodySm,
        ),
        const SizedBox(height: 24),
        // Sección de mapeo de campos
        _SectionHeader(
          number: '7',
          title: 'Mapeo de Campos',
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.neutral100),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              // Header de la tabla de mapeo
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
                      onToggle: (enabled) => _updateMapping(i, enabled: enabled),
                      onFieldChanged: (field) => _updateMapping(i, tum2Field: field),
                    ),
                    if (i < widget.mappings.length - 1)
                      const Divider(height: 1, color: AppColors.neutral100),
                  ],
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Sección inferior: deduplicación y visibilidad
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Deduplicación
            Expanded(
              child: _SettingsCard(
                title: 'Deduplicación',
                description: 'Evitá entradas duplicadas comparando el Nombre y Teléfono antes de crear nuevos registros.',
                child: Row(
                  children: [
                    Switch(
                      value: widget.deduplicationEnabled,
                      onChanged: widget.onDeduplicationChanged,
                      activeColor: AppColors.primary500,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.deduplicationEnabled ? 'Activada' : 'Desactivada',
                      style: AppTextStyles.labelSm,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Visibilidad post-importación
            Expanded(
              child: _SettingsCard(
                title: 'Visibilidad post-importación',
                description: 'Los registros importados como ocultos requieren revisión antes de ser públicos en la app.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _RadioOption(
                      label: 'Oculto',
                      description: 'Los registros de importación serán ocultos para todos los usuarios',
                      value: 'hidden',
                      groupValue: widget.visibilityAfterImport,
                      onChanged: widget.onVisibilityChanged,
                    ),
                    const SizedBox(height: 8),
                    _RadioOption(
                      label: 'Visible',
                      description: 'Los registros serán visibles inmediatamente después de la importación',
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
    );
    widget.onMappingsChanged(updated);
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.number, required this.title});
  final String number;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: AppColors.primary500,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(title, style: AppTextStyles.headingSm),
      ],
    );
  }
}

class _MappingTableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.neutral500, letterSpacing: 0.6);
    return Container(
      color: AppColors.neutral50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: const Row(
        children: [
          SizedBox(width: 48, child: Text('IMPORTAR', style: style)),
          Expanded(child: Text('CAMPO CSV', style: style)),
          SizedBox(width: 32),
          Expanded(child: Text('CAMPO TUM2', style: style)),
          SizedBox(width: 100, child: Text('ESTADO', style: style)),
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
                  color: mapping.enabled ? AppColors.neutral900 : AppColors.neutral500,
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
              color: mapping.enabled ? AppColors.neutral600 : AppColors.neutral300,
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
                    value: tum2Fields.contains(mapping.tum2Field) ? mapping.tum2Field : null,
                    isExpanded: true,
                    underline: const SizedBox(),
                    hint: Text('Seleccionar campo...', style: AppTextStyles.bodyXs.copyWith(color: AppColors.neutral500)),
                    items: tum2Fields.map((f) => DropdownMenuItem(
                      value: f,
                      child: Text(f, style: AppTextStyles.bodySm),
                    )).toList(),
                    onChanged: onFieldChanged,
                    style: AppTextStyles.bodySm.copyWith(color: AppColors.neutral900),
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
                    child: Text('—', style: AppTextStyles.bodyXs.copyWith(color: AppColors.neutral400)),
                  ),
                ),
          ),
          // Estado
          SizedBox(
            width: 100,
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: mapping.required
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.errorBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('Requerido', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.errorFg)),
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: mapping.enabled ? AppColors.successBg : AppColors.neutral100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      mapping.enabled ? 'Opcional' : 'Ignorado',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: mapping.enabled ? AppColors.successFg : AppColors.neutral500),
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
