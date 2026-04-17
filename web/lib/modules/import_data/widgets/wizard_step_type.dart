import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/import_batch_ui.dart';

/// Paso 1 del wizard de importación — selección del tipo de importación.
class WizardStepType extends StatelessWidget {
  const WizardStepType({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final ImportType? selected;
  final void Function(ImportType) onSelect;

  static const _items = [
    _TypeItem(
      type: ImportType.officialDataset,
      icon: Icons.source_outlined,
      examples:
          'Farmacias REPES, WiFi publico, mercados municipales y clubes de barrio',
    ),
    _TypeItem(
      type: ImportType.masterCatalog,
      icon: Icons.inventory_2_outlined,
      examples: 'Codigos de barras, marcas, categorias y GTIN',
    ),
    _TypeItem(
      type: ImportType.genericInternal,
      icon: Icons.tune_outlined,
      examples:
          'Exportaciones manuales, datos de partners e importaciones puntuales',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Selecciona el tipo de importacion',
            style: AppTextStyles.headingSm),
        const SizedBox(height: 4),
        Text(
          'Elegi el tipo de datos que queres importar. Cada tipo usa un esquema, un perfil de validacion y una estrategia de deduplicacion distintos.',
          style: AppTextStyles.bodySm.copyWith(color: AppColors.neutral500),
        ),
        const SizedBox(height: 28),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _items.map((item) {
            final isSelected = selected == item.type;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: item == _items.last ? 0 : 16),
                child: _TypeCard(
                  item: item,
                  isSelected: isSelected,
                  onSelect: onSelect,
                ),
              ),
            );
          }).toList(),
        ),
        if (selected != null) ...[
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary500.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.primary500.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 16,
                  color: AppColors.primary500,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _helpText(selected!),
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.primary500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _helpText(ImportType type) => switch (type) {
        ImportType.officialDataset =>
          'Los datasets oficiales usan deduplicacion por nombre + geohash. Los registros quedan en staging oculto y requieren publicacion manual antes de quedar visibles.',
        ImportType.masterCatalog =>
          'El catalogo maestro usa deduplicacion por codigo de barras + nombre + marca. Los conflictos se marcan para revision antes de consolidar.',
        ImportType.genericInternal =>
          'Las fuentes genericas usan una deduplicacion configurable. Vas a definir los campos clave en el paso de mapeo.',
      };
}

class _TypeCard extends StatefulWidget {
  const _TypeCard({
    required this.item,
    required this.isSelected,
    required this.onSelect,
  });
  final _TypeItem item;
  final bool isSelected;
  final void Function(ImportType) onSelect;

  @override
  State<_TypeCard> createState() => _TypeCardState();
}

class _TypeCardState extends State<_TypeCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.isSelected
        ? AppColors.primary500
        : _hovered
            ? AppColors.neutral300
            : AppColors.neutral200;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => widget.onSelect(widget.item.type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppColors.primary500.withValues(alpha: 0.04)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor,
              width: widget.isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: widget.isSelected
                          ? AppColors.primary500.withValues(alpha: 0.12)
                          : AppColors.neutral100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      widget.item.icon,
                      size: 20,
                      color: widget.isSelected
                          ? AppColors.primary500
                          : AppColors.neutral600,
                    ),
                  ),
                  const Spacer(),
                  if (widget.isSelected)
                    const Icon(
                      Icons.check_circle,
                      size: 18,
                      color: AppColors.primary500,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                widget.item.type.label,
                style: AppTextStyles.labelMd.copyWith(
                  color: widget.isSelected
                      ? AppColors.primary500
                      : AppColors.neutral900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.item.type.description,
                style: AppTextStyles.bodySm.copyWith(
                  color: AppColors.neutral500,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Ejemplos:',
                style: AppTextStyles.bodyXs.copyWith(
                  color: AppColors.neutral400,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.item.examples,
                style: AppTextStyles.bodyXs.copyWith(
                  color: AppColors.neutral500,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => widget.onSelect(widget.item.type),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: widget.isSelected
                        ? AppColors.primary500
                        : AppColors.neutral700,
                    side: BorderSide(
                      color: widget.isSelected
                          ? AppColors.primary500
                          : AppColors.neutral300,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    textStyle: AppTextStyles.labelSm,
                  ),
                  child:
                      Text(widget.isSelected ? 'Seleccionado' : 'Seleccionar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeItem {
  const _TypeItem({
    required this.type,
    required this.icon,
    required this.examples,
  });
  final ImportType type;
  final IconData icon;
  final String examples;
}
