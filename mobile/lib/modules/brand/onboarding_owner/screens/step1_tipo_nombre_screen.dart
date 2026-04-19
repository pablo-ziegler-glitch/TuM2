import 'dart:async';

import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../models/onboarding_draft.dart';
import '../repositories/categories_repository.dart';
import '../repositories/onboarding_owner_repository.dart';
import '../services/duplicate_check_service.dart';
import '../widgets/step_indicator.dart';
import '../widgets/exit_modal.dart';
import '../widgets/category_chip.dart';
import '../widgets/inline_error.dart';
import '../analytics/onboarding_analytics.dart';

/// ONBOARDING-OWNER-01 — Paso 1: Tipo y nombre del comercio
///
/// Estados:
///   Normal     — formulario habilitado con categorías desde Firestore
///   EX-08      — intento de avanzar con campos vacíos (banner global + errores inline)
///   EX-13      — nombre duplicado soft (warning naranja, flujo no bloqueado)
///   EX-14      — comercio ya registrado hard (pantalla bloqueante interstitial)
class Step1TipoNombreScreen extends StatefulWidget {
  final Step1Data? initialData;
  final ValueChanged<Step1Data> onNext;
  final VoidCallback onExit;
  final CategoriesRepository categoriesRepository;
  final DuplicateCheckService duplicateCheckService;
  final OnboardingOwnerRepository ownerRepository;

  const Step1TipoNombreScreen({
    super.key,
    this.initialData,
    required this.onNext,
    required this.onExit,
    required this.categoriesRepository,
    required this.duplicateCheckService,
    required this.ownerRepository,
  });

  @override
  State<Step1TipoNombreScreen> createState() => _Step1TipoNombreScreenState();
}

class _Step1TipoNombreScreenState extends State<Step1TipoNombreScreen> {
  final _nameCtrl = TextEditingController();
  StreamSubscription<DuplicateState>? _duplicateSubscription;
  String? _selectedCategoryId;
  bool _submitted = false;
  DuplicateState _duplicateState = DuplicateState.none;
  DuplicateCandidate? _firstCandidate;

  // Categorías cargadas desde Firestore
  List<CategoryOption> _categoryOptions = [];
  bool _loadingCategories = true;

  bool get _nameEmpty => _nameCtrl.text.trim().isEmpty;
  bool get _categoryEmpty => _selectedCategoryId == null;
  bool get _hasErrors => _submitted && (_nameEmpty || _categoryEmpty);

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _nameCtrl.text = widget.initialData!.name;
      _selectedCategoryId = canonicalCategoryId(widget.initialData!.categoryId);
    }
    _loadCategories();
    _subscribeToDuplicates();
  }

  Future<void> _loadCategories() async {
    final cats = await widget.categoriesRepository.getCategories();
    if (!mounted) return;
    setState(() {
      _categoryOptions = cats
          .map((c) => CategoryOption(
                id: c.id,
                label: c.label,
                icon: _iconForName(c.iconName),
              ))
          .toList();
      _loadingCategories = false;
    });
  }

  IconData _iconForName(String iconName) {
    const map = <String, IconData>{
      'local_pharmacy': Icons.local_pharmacy_outlined,
      'storefront': Icons.store_outlined,
      'shopping_basket': Icons.shopping_basket_outlined,
      'pets': Icons.pets_outlined,
      'bakery_dining': Icons.bakery_dining_outlined,
      'store': Icons.more_horiz,
    };
    return map[iconName] ?? Icons.store_outlined;
  }

  void _subscribeToDuplicates() {
    _duplicateSubscription =
        widget.duplicateCheckService.stateStream.listen((state) {
      if (!mounted) return;
      setState(() {
        _duplicateState = state;
        _firstCandidate = widget.duplicateCheckService.candidates.isNotEmpty
            ? widget.duplicateCheckService.candidates.first
            : null;
      });
      if (state == DuplicateState.soft) OnboardingAnalytics.logDuplicateSoft();
      if (state == DuplicateState.hard) OnboardingAnalytics.logDuplicateHard();
    });
  }

  @override
  void dispose() {
    _duplicateSubscription?.cancel();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _onNameChanged(String value) {
    setState(() {});
    // Chequeo de duplicados solo por nombre (sin filtro de zona ni coordenadas).
    // Se omite la llamada al server si el nombre es muy corto para evitar
    // errores de validación innecesarios.
    if (value.trim().length < 3) return;
    widget.duplicateCheckService.checkName(
      name: value,
    );
  }

  Future<void> _onNext() async {
    setState(() => _submitted = true);
    if (_nameEmpty || _categoryEmpty) return;

    // Si es hard duplicate, mostrar interstitial en lugar de avanzar
    if (_duplicateState == DuplicateState.hard) return;

    try {
      await widget.ownerRepository.saveStep1(Step1Data(
        name: _nameCtrl.text.trim(),
        categoryId: canonicalCategoryId(_selectedCategoryId!),
      ));
    } catch (_) {
      // Error de red al guardar: continuar de todos modos (se reintentará)
    }

    widget.onNext(Step1Data(
      name: _nameCtrl.text.trim(),
      categoryId: canonicalCategoryId(_selectedCategoryId!),
    ));
  }

  Future<void> _onExitTap() async {
    final action = await showExitModal(context);
    if (action == ExitAction.saveDraft) {
      await widget.ownerRepository.abandonDraft();
      OnboardingAnalytics.logExited('step_1');
      widget.onExit();
    } else if (action == ExitAction.discard) {
      await widget.ownerRepository.discardDraft();
      OnboardingAnalytics.logDraftDiscarded();
      widget.onExit();
    }
  }

  // EX-14 — pantalla interstitial bloqueante
  Widget _buildAlreadyRegisteredInterstitial() {
    final candidate = _firstCandidate;
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
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
              const Text('Este comercio ya existe',
                  style: AppTextStyles.headingLg, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'Encontramos "${candidate?.name ?? _nameCtrl.text}" ya registrado en TuM2.',
                style: AppTextStyles.bodySm,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              if (candidate != null)
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
                      Text(candidate.name, style: AppTextStyles.headingSm),
                      const SizedBox(height: 4),
                      Text(candidate.address, style: AppTextStyles.bodySm),
                    ],
                  ),
                ),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  // → flujo de claim (TuM2-0037), pendiente de implementar
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
              OutlinedButton(
                onPressed: () {
                  widget.duplicateCheckService.reset();
                  setState(() => _duplicateState = DuplicateState.none);
                },
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
              const Text(
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
    if (_duplicateState == DuplicateState.hard) {
      return _buildAlreadyRegisteredInterstitial();
    }

    final nameHasError = _submitted && _nameEmpty;
    final categoryHasError = _submitted && _categoryEmpty;
    final showDuplicateWarning = _duplicateState == DuplicateState.soft;

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
                  const Expanded(
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
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
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
                    // EX-08: banner global
                    if (_hasErrors) ...[
                      const ValidationBanner(
                        title: 'Revisá los campos',
                        body:
                            'Completá el nombre y seleccioná una categoría para continuar.',
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Campo nombre
                    Text(
                      'Nombre del comercio *',
                      style: AppTextStyles.labelMd.copyWith(
                        color: nameHasError
                            ? AppColors.errorFg
                            : AppColors.neutral900,
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
                                : showDuplicateWarning
                                    ? AppColors.warningFg
                                    : AppColors.neutral300,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: nameHasError
                                ? AppColors.errorFg
                                : showDuplicateWarning
                                    ? AppColors.warningFg
                                    : AppColors.primary500,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    if (nameHasError)
                      const InlineError(
                          message: 'Ingresá el nombre del comercio'),
                    // EX-13: warning soft duplicate
                    if (showDuplicateWarning && !nameHasError) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.warningBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color:
                                  AppColors.warningFg.withValues(alpha: 0.4)),
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
                    _loadingCategories
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : CategoryGrid(
                            selectedId: _selectedCategoryId,
                            onSelect: (id) => setState(() =>
                                _selectedCategoryId = canonicalCategoryId(id)),
                            hasError: categoryHasError,
                            categories: _categoryOptions.isNotEmpty
                                ? _categoryOptions
                                : null,
                          ),
                    if (categoryHasError)
                      const InlineError(message: 'Seleccioná una categoría'),

                    // EX-13: CTA continuar de todos modos
                    if (showDuplicateWarning) ...[
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
                      const Text(
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

            // ── Footer CTA ─────────────────────────────────────────────
            if (!showDuplicateWarning)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: ElevatedButton(
                  onPressed: _onNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        (_submitted && (_nameEmpty || _categoryEmpty))
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
