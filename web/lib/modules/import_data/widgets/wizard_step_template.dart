import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/import_batch_ui.dart';

/// Paso 2 del wizard — selección de plantilla de importación.
class WizardStepTemplate extends StatelessWidget {
  const WizardStepTemplate({
    super.key,
    required this.importType,
    required this.selectedTemplate,
    required this.onSelect,
  });

  final ImportType importType;
  final String? selectedTemplate;
  final void Function(String) onSelect;

  List<_TemplateItem> get _templates => switch (importType) {
    ImportType.officialDataset => [
      const _TemplateItem(
        name: 'REPES oficial v2.1',
        description: 'Ministerio de Salud · Farmacias',
        fields: 18,
        lastUpdated: '2026-02',
        icon: Icons.local_pharmacy_outlined,
      ),
      const _TemplateItem(
        name: 'BA Data WiFi v1.3',
        description: 'Buenos Aires Data · Puntos WiFi',
        fields: 12,
        lastUpdated: '2025-11',
        icon: Icons.wifi_outlined,
      ),
      const _TemplateItem(
        name: 'Municipios v1.0',
        description: 'Datos abiertos municipales genéricos',
        fields: 15,
        lastUpdated: '2025-09',
        icon: Icons.location_city_outlined,
      ),
      const _TemplateItem(
        name: 'Esquema personalizado',
        description: 'Defini tu propio mapeo de columnas',
        fields: 0,
        lastUpdated: null,
        icon: Icons.tune_outlined,
        isCustom: true,
      ),
    ],
    ImportType.masterCatalog => [
      const _TemplateItem(
        name: 'GS1 estandar v3.0',
        description: 'GTIN · EAN13 · barcode + brand',
        fields: 24,
        lastUpdated: '2026-01',
        icon: Icons.qr_code_outlined,
      ),
      const _TemplateItem(
        name: 'Catalogo interno v1.0',
        description: 'Formato interno TuM2 productos',
        fields: 16,
        lastUpdated: '2025-12',
        icon: Icons.inventory_2_outlined,
      ),
      const _TemplateItem(
        name: 'Esquema personalizado',
        description: 'Defini tu propio mapeo de columnas',
        fields: 0,
        lastUpdated: null,
        icon: Icons.tune_outlined,
        isCustom: true,
      ),
    ],
    ImportType.genericInternal => [
      const _TemplateItem(
        name: 'Comercios genericos v1.0',
        description: 'Comercios genéricos — nombre + dirección + categoría',
        fields: 10,
        lastUpdated: '2025-10',
        icon: Icons.storefront_outlined,
      ),
      const _TemplateItem(
        name: 'Esquema personalizado',
        description: 'Defini tu propio mapeo de columnas',
        fields: 0,
        lastUpdated: null,
        icon: Icons.tune_outlined,
        isCustom: true,
      ),
    ],
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selecciona una plantilla',
                  style: AppTextStyles.headingSm,
                ),
                const SizedBox(height: 4),
                Text(
                  'Elegi un esquema preconfigurado para ${importType.label}',
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.neutral500,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary500.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.label_outline,
                    size: 13,
                    color: AppColors.primary500,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    importType.label,
                    style: AppTextStyles.labelSm.copyWith(
                      color: AppColors.primary500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        ..._templates.map(
          (t) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _TemplateCard(
              item: t,
              isSelected: selectedTemplate == t.name,
              onSelect: () => onSelect(t.name),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.neutral50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.neutral200),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.lightbulb_outline,
                size: 15,
                color: AppColors.neutral500,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Las plantillas definen mapeos de campos, reglas de validacion y claves de deduplicacion. Podes revisar y ajustar todo en el siguiente paso.',
                  style: AppTextStyles.bodyXs.copyWith(
                    color: AppColors.neutral500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TemplateCard extends StatefulWidget {
  const _TemplateCard({
    required this.item,
    required this.isSelected,
    required this.onSelect,
  });
  final _TemplateItem item;
  final bool isSelected;
  final VoidCallback onSelect;

  @override
  State<_TemplateCard> createState() => _TemplateCardState();
}

class _TemplateCardState extends State<_TemplateCard> {
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
        onTap: widget.onSelect,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppColors.primary500.withValues(alpha: 0.04)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: borderColor,
              width: widget.isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: widget.item.isCustom
                      ? AppColors.neutral100
                      : widget.isSelected
                      ? AppColors.primary500.withValues(alpha: 0.12)
                      : AppColors.neutral100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  widget.item.icon,
                  size: 18,
                  color: widget.isSelected
                      ? AppColors.primary500
                      : AppColors.neutral600,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          widget.item.name,
                          style: AppTextStyles.labelMd.copyWith(fontSize: 13),
                        ),
                        if (widget.item.isCustom)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.neutral200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'personalizada',
                                style: AppTextStyles.bodyXs.copyWith(
                                  color: AppColors.neutral600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.item.description,
                      style: AppTextStyles.bodyXs.copyWith(
                        color: AppColors.neutral500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (widget.item.fields > 0)
                    Text(
                      '${widget.item.fields} campos',
                      style: AppTextStyles.bodyXs.copyWith(
                        color: AppColors.neutral400,
                      ),
                    ),
                  if (widget.item.lastUpdated != null)
                    Text(
                      'Actualizada ${widget.item.lastUpdated}',
                      style: AppTextStyles.bodyXs.copyWith(
                        color: AppColors.neutral400,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              if (widget.isSelected)
                const Icon(
                  Icons.check_circle,
                  size: 18,
                  color: AppColors.primary500,
                )
              else
                const Icon(
                  Icons.radio_button_unchecked,
                  size: 18,
                  color: AppColors.neutral300,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TemplateItem {
  const _TemplateItem({
    required this.name,
    required this.description,
    required this.fields,
    required this.lastUpdated,
    required this.icon,
    this.isCustom = false,
  });
  final String name;
  final String description;
  final int fields;
  final String? lastUpdated;
  final IconData icon;
  final bool isCustom;
}
