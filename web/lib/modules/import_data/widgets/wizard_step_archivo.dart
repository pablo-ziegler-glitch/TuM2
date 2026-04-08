import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/import_data_repository.dart';
import '../models/import_batch_ui.dart';

/// Paso 1 del wizard: Configuración del tipo de dataset y carga del archivo.
class WizardStepArchivo extends StatefulWidget {
  const WizardStepArchivo({
    super.key,
    required this.selectedDatasetType,
    required this.selectedZoneId,
    required this.zoneOptions,
    required this.zonesLoading,
    required this.zonesError,
    required this.fileName,
    required this.onDatasetTypeChanged,
    required this.onZoneChanged,
    required this.onFileSelected,
  });

  final DatasetType? selectedDatasetType;
  final String? selectedZoneId;
  final List<ZoneOption> zoneOptions;
  final bool zonesLoading;
  final String? zonesError;
  final String? fileName;
  final ValueChanged<DatasetType?> onDatasetTypeChanged;
  final ValueChanged<String?> onZoneChanged;
  final VoidCallback onFileSelected;

  @override
  State<WizardStepArchivo> createState() => _WizardStepArchivoState();
}

class _WizardStepArchivoState extends State<WizardStepArchivo> {
  bool _isDragOver = false;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Panel de configuración izquierdo
        SizedBox(
          width: 260,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Configuración',
                style: AppTextStyles.headingSm,
              ),
              const SizedBox(height: 20),
              // Tipo de dataset
              _FieldLabel(label: 'TIPOS DE DATASET'),
              const SizedBox(height: 6),
              _StyledDropdown<DatasetType>(
                value: widget.selectedDatasetType,
                hint: 'Seleccionar tipo...',
                items: DatasetType.values
                    .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(t.label, style: AppTextStyles.bodySm),
                        ))
                    .toList(),
                onChanged: widget.onDatasetTypeChanged,
              ),
              const SizedBox(height: 20),
              // Zona destino
              _FieldLabel(label: 'ZONA DESTINO'),
              const SizedBox(height: 6),
              if (widget.zonesLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(minHeight: 2),
                )
              else
                _StyledDropdown<String>(
                  value: widget.selectedZoneId,
                  hint: 'Seleccionar zona...',
                  items: widget.zoneOptions
                      .map((zone) => DropdownMenuItem(
                            value: zone.zoneId,
                            child: Text(zone.label,
                                style: AppTextStyles.bodySm,
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: widget.onZoneChanged,
                ),
              if (widget.zonesError != null) ...[
                const SizedBox(height: 6),
                Text(
                  widget.zonesError!,
                  style:
                      AppTextStyles.bodyXs.copyWith(color: AppColors.errorFg),
                ),
              ],
              const SizedBox(height: 24),
              // Info de configuración completa
              if (widget.selectedDatasetType != null &&
                  widget.selectedZoneId != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.successBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.secondary200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline,
                          color: AppColors.successFg, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Configuración de origen completa',
                          style: AppTextStyles.bodyXs
                              .copyWith(color: AppColors.successFg),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 32),
        // Área de carga de archivo
        Expanded(
          child: Column(
            children: [
              // Drag & drop zone
              GestureDetector(
                onTap: widget.onFileSelected,
                child: MouseRegion(
                  onEnter: (_) => setState(() => _isDragOver = true),
                  onExit: (_) => setState(() => _isDragOver = false),
                  cursor: SystemMouseCursors.click,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: 280,
                    decoration: BoxDecoration(
                      color: _isDragOver
                          ? AppColors.primary50
                          : AppColors.neutral50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _isDragOver
                            ? AppColors.primary500
                            : AppColors.neutral200,
                        width: _isDragOver ? 2 : 1.5,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: _isDragOver
                                ? AppColors.primary100
                                : AppColors.neutral100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.upload_file_outlined,
                            size: 32,
                            color: _isDragOver
                                ? AppColors.primary500
                                : AppColors.neutral500,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.fileName != null
                              ? widget.fileName!
                              : 'Arrastrá el archivo CSV aquí',
                          style: widget.fileName != null
                              ? AppTextStyles.labelMd
                                  .copyWith(color: AppColors.primary500)
                              : AppTextStyles.bodyMd,
                        ),
                        const SizedBox(height: 6),
                        if (widget.fileName == null)
                          Text(
                            'o hacé clic para seleccionarlo desde tu computadora',
                            style: AppTextStyles.bodySm,
                          ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed: widget.onFileSelected,
                              icon: const Icon(Icons.table_chart_outlined,
                                  size: 16),
                              label: const Text('CSV / JSON'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.neutral700,
                                side: const BorderSide(
                                    color: AppColors.neutral300),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                              ),
                            ),
                            const SizedBox(width: 10),
                            OutlinedButton.icon(
                              onPressed: widget.onFileSelected,
                              icon:
                                  const Icon(Icons.storage_outlined, size: 16),
                              label: const Text('Max 50MB'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.neutral700,
                                side: const BorderSide(
                                    color: AppColors.neutral300),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Reglas del archivo
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.infoBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline,
                        size: 16, color: AppColors.primary500),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Asegurate de que el archivo tenga columnas clave para facilitar el mapeo automático en el siguiente paso.',
                        style: AppTextStyles.bodyXs
                            .copyWith(color: AppColors.primary600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTextStyles.labelSm.copyWith(
        letterSpacing: 0.8,
        color: AppColors.neutral500,
      ),
    );
  }
}

class _StyledDropdown<T> extends StatelessWidget {
  const _StyledDropdown({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  final T? value;
  final String hint;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.neutral200),
        borderRadius: BorderRadius.circular(8),
        color: AppColors.surface,
      ),
      child: DropdownButton<T>(
        value: value,
        isExpanded: true,
        underline: const SizedBox(),
        hint: Text(hint,
            style: AppTextStyles.bodySm.copyWith(color: AppColors.neutral500)),
        items: items,
        onChanged: onChanged,
        style: AppTextStyles.bodySm.copyWith(color: AppColors.neutral900),
      ),
    );
  }
}
