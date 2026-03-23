import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/import_batch_ui.dart';
import '../widgets/wizard_step_archivo.dart';
import '../widgets/wizard_step_preview.dart';
import '../widgets/wizard_step_config.dart';

/// Wizard de importación de datasets.
/// Flujo: Archivo → Preview → Configuración → Continuar
class ImportWizardScreen extends StatefulWidget {
  const ImportWizardScreen({super.key});

  @override
  State<ImportWizardScreen> createState() => _ImportWizardScreenState();
}

class _ImportWizardScreenState extends State<ImportWizardScreen> {
  int _currentStep = 0;

  // Estado del wizard
  DatasetType? _datasetType;
  String? _zone;
  String? _fileName;
  List<FieldMapping> _fieldMappings = [
    const FieldMapping(csvColumn: 'business_name', tum2Field: 'Nombre del Negocio', enabled: true, required: true),
    const FieldMapping(csvColumn: 'phone_number', tum2Field: 'Teléfono Principal', enabled: true, required: false),
    const FieldMapping(csvColumn: 'full_address', tum2Field: 'Dirección Completa', enabled: true, required: true),
    const FieldMapping(csvColumn: 'opening_hours', tum2Field: 'Horario de Atención', enabled: false, required: false),
  ];
  bool _deduplicationEnabled = true;
  String _visibilityAfterImport = 'hidden';

  static const _stepLabels = ['Archivo', 'Preview', 'Configuración', 'Continuar'];

  bool get _canGoNext {
    return switch (_currentStep) {
      0 => _datasetType != null && _zone != null && _fileName != null,
      1 => true,
      2 => true,
      _ => false,
    };
  }

  void _onFileSelected() {
    // Simula la selección de un archivo
    setState(() {
      _fileName = 'farmacias_cordoba_v2.csv';
    });
  }

  void _goNext() {
    if (_currentStep < _stepLabels.length - 1) {
      setState(() => _currentStep++);
    } else {
      _submitImport();
    }
  }

  void _goBack() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      context.go('/datasets');
    }
  }

  void _submitImport() {
    // Simula el envío y navega al resultado
    context.go('/datasets/batch_482');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado con stepper
            Row(
              children: [
                GestureDetector(
                  onTap: () => context.go('/datasets'),
                  child: Text(
                    'Importar Nuevo Dataset',
                    style: AppTextStyles.headingMd,
                  ),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 20),
            // Stepper horizontal
            _HorizontalStepper(
              steps: _stepLabels,
              currentStep: _currentStep,
            ),
            const SizedBox(height: 28),
            // Contenido del paso actual
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.neutral100),
                ),
                padding: const EdgeInsets.all(28),
                child: _buildStepContent(),
              ),
            ),
            const SizedBox(height: 20),
            // Barra de navegación del wizard
            _WizardNav(
              canGoNext: _canGoNext,
              isLastStep: _currentStep == _stepLabels.length - 1,
              onBack: _goBack,
              onNext: _goNext,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    return switch (_currentStep) {
      0 => WizardStepArchivo(
          selectedDatasetType: _datasetType,
          selectedZone: _zone,
          fileName: _fileName,
          onDatasetTypeChanged: (t) => setState(() => _datasetType = t),
          onZoneChanged: (z) => setState(() => _zone = z),
          onFileSelected: _onFileSelected,
        ),
      1 => WizardStepPreview(rows: mockCsvPreview),
      2 => WizardStepConfig(
          mappings: _fieldMappings,
          deduplicationEnabled: _deduplicationEnabled,
          visibilityAfterImport: _visibilityAfterImport,
          onMappingsChanged: (m) => setState(() => _fieldMappings = m),
          onDeduplicationChanged: (v) => setState(() => _deduplicationEnabled = v),
          onVisibilityChanged: (v) => setState(() => _visibilityAfterImport = v),
        ),
      _ => const Center(child: Text('Procesando importación...')),
    };
  }
}

// ── Stepper horizontal ────────────────────────────────────────────────────────

class _HorizontalStepper extends StatelessWidget {
  const _HorizontalStepper({required this.steps, required this.currentStep});
  final List<String> steps;
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: steps.asMap().entries.map((entry) {
        final i = entry.key;
        final label = entry.value;
        final isDone = i < currentStep;
        final isActive = i == currentStep;

        return Expanded(
          child: Row(
            children: [
              // Círculo numerado
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isDone ? AppColors.successFg : (isActive ? AppColors.primary500 : AppColors.neutral200),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isDone
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isActive ? Colors.white : AppColors.neutral600,
                        ),
                      ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTextStyles.labelMd.copyWith(
                  color: isDone ? AppColors.successFg : (isActive ? AppColors.primary500 : AppColors.neutral500),
                ),
              ),
              // Línea conectora
              if (i < steps.length - 1)
                Expanded(
                  child: Container(
                    height: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    color: i < currentStep ? AppColors.successFg : AppColors.neutral200,
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Navegación del wizard ─────────────────────────────────────────────────────

class _WizardNav extends StatelessWidget {
  const _WizardNav({
    required this.canGoNext,
    required this.isLastStep,
    required this.onBack,
    required this.onNext,
  });
  final bool canGoNext;
  final bool isLastStep;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        OutlinedButton(
          onPressed: onBack,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.neutral700,
            side: const BorderSide(color: AppColors.neutral300),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: const Text('Atrás'),
        ),
        FilledButton.icon(
          onPressed: canGoNext ? onNext : null,
          icon: Icon(isLastStep ? Icons.check : Icons.arrow_forward, size: 16),
          label: Text(isLastStep ? 'Iniciar importación' : 'Continuar →'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary500,
            disabledBackgroundColor: AppColors.neutral200,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ],
    );
  }
}
