import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../models/onboarding_draft.dart';
import '../widgets/step_indicator.dart';
import '../widgets/exit_modal.dart';
import '../widgets/category_chip.dart';
import '../widgets/inline_error.dart';

/// ONBOARDING-OWNER-01 — Paso 1: Tipo y nombre del comercio
///
/// Estados:
///   Normal     — formulario vacío habilitado
///   EX-08      — intento de avanzar con campos vacíos (banner global + errores inline)
///   EX-13      — nombre duplicado soft (warning, el flujo no se bloquea)
///   EX-14      — comercio ya registrado hard (pantalla bloqueante interstitial)
class Step1TipoNombreScreen extends StatefulWidget {
  final Step1Data? initialData;
  final ValueChanged<Step1Data> onNext;
  final VoidCallback onExit;

  const Step1TipoNombreScreen({
    super.key,
    this.initialData,
    required this.onNext,
    required this.onExit,
  });

  @override
  State<Step1TipoNombreScreen> createState() => _Step1TipoNombreScreenState();
}

class _Step1TipoNombreScreenState extends State<Step1TipoNombreScreen> {
  final _nameCtrl = TextEditingController();
  String? _selectedCategoryId;
  bool _submitted = false;
  bool _showDuplicateWarning = false; // EX-13
  bool _showAlreadyRegistered = false; // EX-14

  bool get _nameEmpty => _nameCtrl.text.trim().isEmpty;
  bool get _categoryEmpty => _selectedCategoryId == null;
  bool get _hasErrors => _submitted && (_nameEmpty || _categoryEmpty);

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _nameCtrl.text = widget.initialData!.name;
      _selectedCategoryId = widget.initialData!.categoryId;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _onNameChanged(String value) {
    setState(() {});
    // Simular check de duplicado (en producción: debounced Firestore query)
    if (value.toLowerCase().contains('farmacia del centro')) {
      setState(() => _showDuplicateWarning = true);
    } else {
      setState(() => _showDuplicateWarning = false);
    }
  }

  void _onNext() {
    setState(() => _submitted = true);
    if (_nameEmpty || _categoryEmpty) return;

    widget.onNext(Step1Data(
      name: _nameCtrl.text.trim(),
      categoryId: _selectedCategoryId!,
    ));
  }

  Future<void> _onExitTap() async {
    final action = await showExitModal(context);
    if (action == ExitAction.saveDraft || action == ExitAction.discard) {
      widget.onExit();
    }
  }

  // EX-14 — pantalla interstitial bloqueante
  Widget _buildAlreadyRegisteredInterstitial() {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Ícono "?" naranja grande
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.warningBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.warningFg, width: 2),
                  ),
                  child: const Center(
                    child: Text('?',
                        style: TextStyle(
                          fontSize: 32,
                          color: AppColors.warningFg,
                          fontWeight: FontWeight.w700,
                        )),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Este comercio ya existe',
                style: AppTextStyles.headingLg,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Encontramos "Farmacia del Centro" en Almagro Norte ya registrada en TuM2.',
                style: AppTextStyles.bodySm,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Card del comercio existente
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.neutral200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Farmacia del Centro',
                        style: AppTextStyles.headingSm),
                    const SizedBox(height: 4),
                    Text('Av. Corrientes 1234, CABA',
                        style: AppTextStyles.bodySm),
                    Text('Zona: Almagro Norte',
                        style: AppTextStyles.bodySm),
                  ],
                ),
              ),
              const Spacer(),

              // CTA primario: reclamar
              ElevatedButton(
                onPressed: () {
                  // → flujo externo de claim (TuM2-0037)
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary500,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Soy el dueño — reclamar'),
              ),
              const SizedBox(height: 10),

              // CTA secundario: registrar otro
              OutlinedButton(
                onPressed: () => setState(() => _showAlreadyRegistered = false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary500,
                  side: const BorderSide(color: AppColors.primary500),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Registrar otro comercio'),
              ),
              const SizedBox(height: 12),
              Text(
                'Si reclamás, verificamos tu identidad en 24 hs.',
                style: AppTextStyles.bodyXs,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // EX-14: interstitial bloqueante
    if (_showAlreadyRegistered) return _buildAlreadyRegisteredInterstitial();

    final nameHasError = _submitted && _nameEmpty;
    final categoryHasError = _submitted && _categoryEmpty;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Tu comercio', style: AppTextStyles.headingMd),
                  ),
                  IconButton(
                    onPressed: _onExitTap,
                    icon: const Icon(Icons.close),
                    color: AppColors.neutral700,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Paso 1 de 4', style: AppTextStyles.bodySm),
              ),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: StepIndicator(currentStep: 1),
            ),
            const SizedBox(height: 20),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // EX-08: banner global cuando hay errores al intentar avanzar
                    if (_hasErrors) ...[
                      ValidationBanner(
                        title: 'Revisá los campos',
                        body: 'Completá el nombre y seleccioná una categoría para continuar.',
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Campo nombre
                    Text(
                      'Nombre del comercio *',
                      style: AppTextStyles.labelMd.copyWith(
                        color: nameHasError ? AppColors.errorFg : AppColors.neutral900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _nameCtrl,
                      onChanged: _onNameChanged,
                      decoration: InputDecoration(
                        hintText: 'Ej: Farmacia del Centro',
                        hintStyle: AppTextStyles.bodyMd
                            .copyWith(color: AppColors.neutral500),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        filled: true,
                        fillColor: AppColors.surface,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: nameHasError
                                ? AppColors.errorFg
                                : _showDuplicateWarning
                                    ? AppColors.warningFg
                                    : AppColors.neutral300,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: nameHasError
                                ? AppColors.errorFg
                                : _showDuplicateWarning
                                    ? AppColors.warningFg
                                    : AppColors.primary500,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    // EX-08: error inline nombre
                    if (nameHasError)
                      InlineError(message: 'Ingresá el nombre del comercio'),
                    // EX-13: warning de nombre duplicado (soft)
                    if (_showDuplicateWarning && !nameHasError) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.warningBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.warningFg.withOpacity(0.4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ya existe un comercio con este nombre en tu zona',
                              style: AppTextStyles.bodyXs.copyWith(
                                  color: AppColors.warningFg,
                                  fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            RichText(
                              text: TextSpan(
                                style: AppTextStyles.bodyXs
                                    .copyWith(color: AppColors.neutral700),
                                children: const [
                                  TextSpan(text: '¿Es el mismo local? '),
                                  TextSpan(
                                    text: 'Contactá soporte',
                                    style: TextStyle(
                                      color: AppColors.primary500,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                  TextSpan(
                                      text:
                                          '. Si es otro, usá un nombre diferente.'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Campo categoría
                    Text(
                      'Categoría *',
                      style: AppTextStyles.labelMd.copyWith(
                        color: categoryHasError
                            ? AppColors.errorFg
                            : AppColors.neutral900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    CategoryGrid(
                      selectedId: _selectedCategoryId,
                      onSelect: (id) =>
                          setState(() => _selectedCategoryId = id),
                      hasError: categoryHasError,
                    ),
                    // EX-08: error inline categoría
                    if (categoryHasError)
                      InlineError(message: 'Seleccioná una categoría'),

                    // EX-13: CTA continuar de todos modos (cuando hay duplicado soft)
                    if (_showDuplicateWarning) ...[
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _categoryEmpty ? null : _onNext,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary500,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppColors.neutral300,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Continuar de todos modos'),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Podés aclarar la situación durante la revisión.',
                        style: AppTextStyles.bodyXs,
                        textAlign: TextAlign.center,
                      ),
                    ],

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),

            // ── Footer con CTA ─────────────────────────────────────────
            if (!_showDuplicateWarning)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: ElevatedButton(
                  onPressed: _onNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (_submitted && (_nameEmpty || _categoryEmpty))
                        ? AppColors.neutral300
                        : AppColors.primary500,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Siguiente'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
