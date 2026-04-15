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
    required this.applyDestinationZone,
    required this.zoneOptions,
    required this.zonesLoading,
    required this.zonesError,
    required this.fileName,
    required this.onDatasetTypeChanged,
    required this.onApplyDestinationZoneChanged,
    required this.onZoneChanged,
    required this.onFileSelected,
    required this.onDownloadCsvTemplate,
    required this.onDownloadExcelTemplate,
  });

  final DatasetType? selectedDatasetType;
  final String? selectedZoneId;
  final bool applyDestinationZone;
  final List<ZoneOption> zoneOptions;
  final bool zonesLoading;
  final String? zonesError;
  final String? fileName;
  final ValueChanged<DatasetType?> onDatasetTypeChanged;
  final ValueChanged<bool> onApplyDestinationZoneChanged;
  final ValueChanged<String?> onZoneChanged;
  final VoidCallback onFileSelected;
  final VoidCallback onDownloadCsvTemplate;
  final VoidCallback onDownloadExcelTemplate;

  @override
  State<WizardStepArchivo> createState() => _WizardStepArchivoState();
}

class _WizardStepArchivoState extends State<WizardStepArchivo> {
  bool _isDragOver = false;
  String _country = 'Argentina';
  String? _province;

  List<String> get _countries {
    final countries = widget.zoneOptions
        .map((zone) => zone.countryName.trim())
        .where((country) => country.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    if (countries.isEmpty) return const ['Argentina'];
    return countries;
  }

  List<String> get _provinces {
    final provinces = widget.zoneOptions
        .where((zone) => zone.countryName == _country)
        .map((zone) => zone.provinceName.trim())
        .where((province) => province.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return provinces;
  }

  List<ZoneOption> get _localities {
    return widget.zoneOptions.where((zone) {
      final sameCountry = zone.countryName == _country;
      if (!sameCountry) return false;
      if (_province == null || _province!.isEmpty) return true;
      return zone.provinceName == _province;
    }).toList()
      ..sort(
        (a, b) => a.localityName
            .toLowerCase()
            .compareTo(b.localityName.toLowerCase()),
      );
  }

  @override
  void initState() {
    super.initState();
    _syncFiltersWithSelection();
  }

  @override
  void didUpdateWidget(covariant WizardStepArchivo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.zoneOptions != widget.zoneOptions ||
        oldWidget.selectedZoneId != widget.selectedZoneId) {
      _syncFiltersWithSelection();
    }
  }

  void _syncFiltersWithSelection() {
    final selected = widget.zoneOptions.where((zone) {
      return zone.zoneId == widget.selectedZoneId;
    });
    if (selected.isNotEmpty) {
      final current = selected.first;
      _country = current.countryName.trim().isEmpty
          ? 'Argentina'
          : current.countryName.trim();
      _province = current.provinceName.trim().isEmpty
          ? null
          : current.provinceName.trim();
      return;
    }

    final argentina = widget.zoneOptions.where(
      (zone) => zone.countryName == 'Argentina',
    );
    if (argentina.isNotEmpty) {
      _country = 'Argentina';
      final provinces = argentina
          .map((zone) => zone.provinceName.trim())
          .where((province) => province.isNotEmpty)
          .toSet()
          .toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      _province = provinces.isEmpty ? null : provinces.first;
      return;
    }

    final countries = _countries;
    _country = countries.first;
    _province = _provinces.isEmpty ? null : _provinces.first;
  }

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
              Text('Configuración', style: AppTextStyles.headingSm),
              const SizedBox(height: 20),
              // Tipo de dataset
              _FieldLabel(label: 'TIPOS DE DATASET'),
              const SizedBox(height: 6),
              _StyledDropdown<DatasetType>(
                value: widget.selectedDatasetType,
                hint: 'Seleccionar tipo...',
                items: DatasetType.values
                    .map(
                      (t) => DropdownMenuItem(
                        value: t,
                        child: Text(t.label, style: AppTextStyles.bodySm),
                      ),
                    )
                    .toList(),
                onChanged: widget.onDatasetTypeChanged,
              ),
              const SizedBox(height: 20),
              // Zona destino
              _FieldLabel(label: 'ZONA DESTINO'),
              const SizedBox(height: 4),
              Text(
                'Usala cuando querés forzar una zona para todos los registros importados.',
                style: AppTextStyles.bodyXs.copyWith(
                  color: AppColors.neutral500,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: Checkbox(
                      value: widget.applyDestinationZone,
                      onChanged: (value) =>
                          widget.onApplyDestinationZoneChanged(value ?? false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Aplicar zona destino (opcional)',
                      style: AppTextStyles.bodySm,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (widget.zonesLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(minHeight: 2),
                )
              else
                Column(
                  children: [
                    _StyledDropdown<String>(
                      value: _country,
                      hint: 'Seleccionar país...',
                      items: _countries
                          .map(
                            (country) => DropdownMenuItem(
                              value: country,
                              child: Text(country, style: AppTextStyles.bodySm),
                            ),
                          )
                          .toList(),
                      onChanged: widget.applyDestinationZone
                          ? (country) {
                              if (country == null) return;
                              setState(() {
                                _country = country;
                                final provinces = _provinces;
                                _province =
                                    provinces.isEmpty ? null : provinces.first;
                              });
                              final localities = _localities;
                              widget.onZoneChanged(
                                localities.isEmpty
                                    ? null
                                    : localities.first.zoneId,
                              );
                            }
                          : (_) {},
                      enabled: widget.applyDestinationZone,
                    ),
                    const SizedBox(height: 8),
                    _StyledDropdown<String>(
                      value: _province,
                      hint: 'Seleccionar provincia...',
                      items: _provinces
                          .map(
                            (province) => DropdownMenuItem(
                              value: province,
                              child: Text(
                                province,
                                style: AppTextStyles.bodySm,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: widget.applyDestinationZone
                          ? (province) {
                              setState(() => _province = province);
                              final localities = _localities;
                              widget.onZoneChanged(
                                localities.isEmpty
                                    ? null
                                    : localities.first.zoneId,
                              );
                            }
                          : (_) {},
                      enabled: widget.applyDestinationZone,
                    ),
                    const SizedBox(height: 8),
                    _StyledDropdown<String>(
                      value: widget.selectedZoneId,
                      hint: 'Seleccionar localidad...',
                      items: _localities
                          .map(
                            (zone) => DropdownMenuItem(
                              value: zone.zoneId,
                              child: Text(
                                '${zone.localityName} (${zone.zoneId})',
                                style: AppTextStyles.bodySm,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: widget.applyDestinationZone
                          ? widget.onZoneChanged
                          : (_) {},
                      enabled: widget.applyDestinationZone,
                    ),
                  ],
                ),
              if (widget.zonesError != null) ...[
                const SizedBox(height: 6),
                Text(
                  widget.zonesError!,
                  style: AppTextStyles.bodyXs.copyWith(
                    color: AppColors.errorFg,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              // Info de configuración completa
              if (widget.selectedDatasetType != null &&
                  (!widget.applyDestinationZone ||
                      widget.selectedZoneId != null))
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.successBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.secondary200),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        color: AppColors.successFg,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.applyDestinationZone
                              ? 'Configuración de origen completa'
                              : 'Zona destino desactivada (importación sin zona fija)',
                          style: AppTextStyles.bodyXs.copyWith(
                            color: AppColors.successFg,
                          ),
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
                              ? AppTextStyles.labelMd.copyWith(
                                  color: AppColors.primary500,
                                )
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
                              icon: const Icon(
                                Icons.table_chart_outlined,
                                size: 16,
                              ),
                              label: const Text('CSV / JSON'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.neutral700,
                                side: const BorderSide(
                                  color: AppColors.neutral300,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            OutlinedButton.icon(
                              onPressed: widget.onFileSelected,
                              icon: const Icon(
                                Icons.storage_outlined,
                                size: 16,
                              ),
                              label: const Text('Max 50MB'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.neutral700,
                                side: const BorderSide(
                                  color: AppColors.neutral300,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
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
                    const Icon(
                      Icons.info_outline,
                      size: 16,
                      color: AppColors.primary500,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Asegurate de que el archivo tenga columnas clave para facilitar el mapeo automático en el siguiente paso.',
                        style: AppTextStyles.bodyXs.copyWith(
                          color: AppColors.primary600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: widget.onDownloadCsvTemplate,
                    icon: const Icon(Icons.download_outlined, size: 16),
                    label: const Text('Plantilla CSV'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary500,
                      side: const BorderSide(color: AppColors.primary500),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: widget.onDownloadExcelTemplate,
                    icon: const Icon(Icons.grid_on_outlined, size: 16),
                    label: const Text('Plantilla Excel'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary500,
                      side: const BorderSide(color: AppColors.primary500),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                ],
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
    this.enabled = true,
  });

  final T? value;
  final String hint;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(
          color: enabled ? AppColors.neutral200 : AppColors.neutral100,
        ),
        borderRadius: BorderRadius.circular(8),
        color: enabled ? AppColors.surface : AppColors.neutral50,
      ),
      child: DropdownButton<T>(
        value: items.any((item) => item.value == value) ? value : null,
        isExpanded: true,
        underline: const SizedBox(),
        hint: Text(
          hint,
          style: AppTextStyles.bodySm.copyWith(color: AppColors.neutral500),
        ),
        items: items,
        onChanged: enabled ? onChanged : null,
        style: AppTextStyles.bodySm.copyWith(
          color: enabled ? AppColors.neutral900 : AppColors.neutral500,
        ),
      ),
    );
  }
}
