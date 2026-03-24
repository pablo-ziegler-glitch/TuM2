import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/import_batch_ui.dart';
import '../widgets/wizard_step_type.dart';
import '../widgets/wizard_step_template.dart';
import '../widgets/wizard_step_archivo.dart';
import '../widgets/wizard_step_config.dart';
import '../widgets/wizard_step_validation.dart';
import '../widgets/wizard_step_confirm.dart';

/// Wizard de importación de 6 pasos:
///   1. Type       — selección del tipo de importación
///   2. Template   — selección de plantilla / schema
///   3. Upload     — carga del archivo (CSV/XLSX/JSON)
///   4. Mapping    — mapeo de campos con confianza IA
///   5. Validation — preview y validación de filas
///   6. Confirm    — resumen final y confirmación
class ImportWizardScreen extends StatefulWidget {
  const ImportWizardScreen({super.key});

  @override
  State<ImportWizardScreen> createState() => _ImportWizardScreenState();
}

class _ImportWizardScreenState extends State<ImportWizardScreen> {
  int _step = 0;

  // ── Estado del wizard ──────────────────────────────────────────────────────
  ImportType? _importType;
  String? _templateName;
  String _zone = '';
  String? _fileName;
  List<FieldMapping> _mappings = List.from(
    mockBatches.first.fieldMappings.isNotEmpty
        ? mockBatches.first.fieldMappings
        : const <FieldMapping>[],
  );
  bool _deduplicationEnabled = true;
  String _visibilityAfterImport = 'hidden';

  static const _steps = [
    _WizardStep(label: 'Type', icon: Icons.category_outlined),
    _WizardStep(label: 'Template', icon: Icons.description_outlined),
    _WizardStep(label: 'Upload', icon: Icons.upload_file_outlined),
    _WizardStep(label: 'Mapping', icon: Icons.compare_arrows_outlined),
    _WizardStep(label: 'Validation', icon: Icons.fact_check_outlined),
    _WizardStep(label: 'Confirm', icon: Icons.check_circle_outline),
  ];

  bool get _canGoNext => switch (_step) {
    0 => _importType != null,
    1 => _templateName != null,
    2 => _fileName != null || true, // archivo opcional en mock
    3 => _mappings.any((m) => m.enabled),
    4 => true,
    5 => true,
    _ => false,
  };

  void _next() {
    if (_step < _steps.length - 1) {
      setState(() => _step++);
    } else {
      _submitImport();
    }
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  void _submitImport() {
    // En producción aquí se dispara la Cloud Function de importación.
    // En mock navegamos al detalle del primer batch.
    context.go('/imports/batch_482');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(
        children: [
          _buildTopBar(context),
          _buildStepProgress(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(40, 28, 40, 28),
              child: _buildCurrentStep(),
            ),
          ),
          _buildBottomBar(context),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.neutral100)),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => context.go('/imports'),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                children: [
                  const Icon(Icons.arrow_back, size: 16, color: AppColors.neutral500),
                  const SizedBox(width: 6),
                  Text('Import Management', style: AppTextStyles.bodySm.copyWith(color: AppColors.neutral500)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Text('/', style: TextStyle(color: AppColors.neutral300)),
          const SizedBox(width: 12),
          Text('New Import', style: AppTextStyles.labelMd),
          const Spacer(),
          if (_importType != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary500.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(_importType!.label, style: AppTextStyles.labelSm.copyWith(color: AppColors.primary500, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _buildStepProgress() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
      child: Row(
        children: _steps.asMap().entries.map((entry) {
          final i = entry.key;
          final step = entry.value;
          final isDone = i < _step;
          final isActive = i == _step;
          final isUpcoming = i > _step;

          return Expanded(
            child: Row(
              children: [
                // Ícono del paso
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone
                        ? AppColors.successFg
                        : isActive
                            ? AppColors.primary500
                            : AppColors.neutral100,
                  ),
                  child: Icon(
                    isDone ? Icons.check : step.icon,
                    size: 14,
                    color: isUpcoming ? AppColors.neutral400 : Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                // Etiqueta
                Expanded(
                  child: Text(
                    step.label,
                    style: AppTextStyles.labelSm.copyWith(
                      fontSize: 11,
                      color: isActive
                          ? AppColors.primary500
                          : isDone
                              ? AppColors.successFg
                              : AppColors.neutral400,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Conector
                if (i < _steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      color: isDone ? AppColors.successFg : AppColors.neutral200,
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCurrentStep() {
    return switch (_step) {
      0 => WizardStepType(
          selected: _importType,
          onSelect: (t) => setState(() {
            _importType = t;
            _templateName = null; // resetear template al cambiar tipo
          }),
        ),
      1 => WizardStepTemplate(
          importType: _importType ?? ImportType.officialDataset,
          selectedTemplate: _templateName,
          onSelect: (t) => setState(() {
            _templateName = t;
            // Si seleccionó un template conocido, pre-cargar los mappings del mock
            if (mockBatches.first.fieldMappings.isNotEmpty) {
              _mappings = List.from(mockBatches.first.fieldMappings);
            }
          }),
        ),
      2 => WizardStepArchivo(
          selectedDatasetType: null,
          selectedZone: _zone.isEmpty ? null : _zone,
          fileName: _fileName,
          onDatasetTypeChanged: (_) {},
          onZoneChanged: (z) => setState(() => _zone = z ?? ''),
          onFileSelected: () => setState(() => _fileName = 'dataset_import.csv'),
        ),
      3 => WizardStepConfig(
          mappings: _mappings,
          deduplicationEnabled: _deduplicationEnabled,
          visibilityAfterImport: _visibilityAfterImport,
          onMappingsChanged: (m) => setState(() => _mappings = m),
          onDeduplicationChanged: (v) => setState(() => _deduplicationEnabled = v),
          onVisibilityChanged: (v) => setState(() => _visibilityAfterImport = v),
        ),
      4 => WizardStepValidation(previewRows: mockCsvPreview),
      5 => WizardStepConfirm(
          importType: _importType ?? ImportType.officialDataset,
          templateName: _templateName,
          zone: _zone,
          fileName: _fileName,
          totalRows: mockCsvPreview.length,
          validRows: mockCsvPreview.where((r) => !r.hasError && !r.hasWarning).length,
          warningRows: mockCsvPreview.where((r) => r.hasWarning && !r.hasError).length,
          errorRows: mockCsvPreview.where((r) => r.hasError).length,
          fieldMappings: _mappings,
          deduplicationEnabled: _deduplicationEnabled,
          visibilityAfterImport: _visibilityAfterImport,
        ),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _buildBottomBar(BuildContext context) {
    final isLastStep = _step == _steps.length - 1;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 40),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.neutral100)),
      ),
      child: Row(
        children: [
          // Indicador de paso
          Text(
            'Step ${_step + 1} of ${_steps.length}',
            style: AppTextStyles.bodyXs.copyWith(color: AppColors.neutral400),
          ),
          const Spacer(),
          if (_step > 0)
            OutlinedButton(
              onPressed: _back,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.neutral700,
                side: const BorderSide(color: AppColors.neutral300),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                textStyle: AppTextStyles.labelSm,
              ),
              child: const Text('Back'),
            ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: _canGoNext ? _next : null,
            style: FilledButton.styleFrom(
              backgroundColor: isLastStep ? AppColors.successFg : AppColors.primary500,
              disabledBackgroundColor: AppColors.neutral200,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              textStyle: AppTextStyles.labelSm,
            ),
            child: Text(isLastStep ? 'Start Import' : 'Continue'),
          ),
        ],
      ),
    );
  }
}

class _WizardStep {
  const _WizardStep({required this.label, required this.icon});
  final String label;
  final IconData icon;
}
