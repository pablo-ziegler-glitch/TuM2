import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../models/onboarding_draft.dart';
import '../widgets/step_indicator.dart';
import '../widgets/exit_modal.dart';
import '../widgets/inline_error.dart';

/// ONBOARDING-OWNER-02 — Paso 2: Dirección y zona
///
/// Estados:
///   Normal     — input de dirección con autocomplete (Google Places)
///   EX-09      — dirección inválida (sin número de puerta / no reconocida)
///   EX-10      — error de red en Places API (sin conexión)
enum _AddressState { idle, searching, invalidAddress, networkError, valid }

class Step2DireccionScreen extends StatefulWidget {
  final Step2Data? initialData;
  final ValueChanged<Step2Data> onNext;
  final VoidCallback onBack;
  final VoidCallback onExit;

  const Step2DireccionScreen({
    super.key,
    this.initialData,
    required this.onNext,
    required this.onBack,
    required this.onExit,
  });

  @override
  State<Step2DireccionScreen> createState() => _Step2DireccionScreenState();
}

class _Step2DireccionScreenState extends State<Step2DireccionScreen> {
  final _addrCtrl = TextEditingController();
  _AddressState _addressState = _AddressState.idle;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _addrCtrl.text = widget.initialData!.address;
      _addressState = _AddressState.valid;
    }
  }

  @override
  void dispose() {
    _addrCtrl.dispose();
    super.dispose();
  }

  void _onAddressChanged(String value) {
    setState(() {
      _submitted = false;
      if (value.isEmpty) {
        _addressState = _AddressState.idle;
      } else {
        _addressState = _AddressState.searching;
      }
    });

    // Simular validación de autocomplete
    if (value.toLowerCase().contains('s/n') ||
        (value.isNotEmpty && !RegExp(r'\d').hasMatch(value))) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => _addressState = _AddressState.invalidAddress);
      });
    } else if (value.toLowerCase().contains('santa fe')) {
      // Simular EX-10: Places sin red
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => _addressState = _AddressState.networkError);
      });
    } else if (value.length > 5 && RegExp(r'\d').hasMatch(value)) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => _addressState = _AddressState.valid);
      });
    }
  }

  void _onNext() {
    setState(() => _submitted = true);
    if (_addressState != _AddressState.valid) return;
    widget.onNext(Step2Data(
      address: _addrCtrl.text.trim(),
      lat: -34.6037,
      lng: -58.3816,
      zoneId: 'almagro-norte',
    ));
  }

  Future<void> _onExitTap() async {
    final action = await showExitModal(context);
    if (action == ExitAction.saveDraft || action == ExitAction.discard) {
      widget.onExit();
    }
  }

  bool get _isNetworkError => _addressState == _AddressState.networkError;
  bool get _isInvalidAddress => _addressState == _AddressState.invalidAddress ||
      (_submitted && _addressState != _AddressState.valid && !_isNetworkError);

  @override
  Widget build(BuildContext context) {
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
                    child: Text('¿Dónde está\ntu comercio?',
                        style: AppTextStyles.headingMd),
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
                child: Text('Paso 2 de 4', style: AppTextStyles.bodySm),
              ),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: StepIndicator(currentStep: 2),
            ),
            const SizedBox(height: 20),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // EX-10: banner warning sin conexión
                    if (_isNetworkError) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.warningBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.warningFg.withOpacity(0.4)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                color: AppColors.warningFg, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Sin conexión a internet',
                                    style: AppTextStyles.labelSm.copyWith(
                                      color: AppColors.warningFg,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'El buscador requiere conexión. Revisá tu red e intentá de nuevo.',
                                    style: AppTextStyles.bodyXs
                                        .copyWith(color: AppColors.warningFg),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Campo dirección
                    Text('Dirección *', style: AppTextStyles.labelMd),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _addrCtrl,
                      onChanged: _onAddressChanged,
                      decoration: InputDecoration(
                        hintText: _isNetworkError
                            ? 'Buscando "Av. Santa Fe 2..."'
                            : 'Ej: Av. Corrientes 1234, CABA',
                        hintStyle: AppTextStyles.bodyMd
                            .copyWith(color: AppColors.neutral500),
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: AppColors.neutral300,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        filled: true,
                        fillColor: AppColors.surface,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: _isInvalidAddress
                                ? AppColors.errorFg
                                : _isNetworkError
                                    ? AppColors.warningFg
                                    : AppColors.neutral300,
                            width: (_isInvalidAddress || _isNetworkError) ? 1.5 : 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: _isInvalidAddress
                                ? AppColors.errorFg
                                : _isNetworkError
                                    ? AppColors.warningFg
                                    : AppColors.primary500,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),

                    // EX-09: error inline dirección sin número
                    if (_isInvalidAddress && !_isNetworkError)
                      InlineError(message: 'La dirección debe incluir número de puerta'),

                    // EX-09: card de error "Dirección no reconocida"
                    if (_isInvalidAddress && !_isNetworkError) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.errorBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.errorFg.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.error_outline,
                                    color: AppColors.errorFg, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  'Dirección no reconocida',
                                  style: AppTextStyles.labelSm.copyWith(
                                    color: AppColors.errorFg,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Buscá con número de puerta para asignar la zona correcta.',
                              style: AppTextStyles.bodyXs
                                  .copyWith(color: AppColors.errorFg),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Mapa placeholder
                    // EX-09: "Seleccioná una dirección válida" — mapa no oculto (evita layout jump)
                    // EX-10: "Mapa no disponible sin conexión"
                    _MapPlaceholder(
                      isNetworkError: _isNetworkError,
                      isInvalidAddress: _isInvalidAddress,
                      isValid: _addressState == _AddressState.valid,
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),

            // ── Footer ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // EX-10: "Reintentar búsqueda" reemplaza "Siguiente"
                  if (_isNetworkError)
                    OutlinedButton(
                      onPressed: () => _onAddressChanged(_addrCtrl.text),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary500,
                        side: const BorderSide(color: AppColors.primary500),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Reintentar búsqueda'),
                    )
                  else
                    ElevatedButton(
                      onPressed: _addressState == _AddressState.valid
                          ? _onNext
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary500,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.neutral300,
                        disabledForegroundColor: AppColors.neutral600,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Siguiente'),
                    ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: widget.onBack,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.neutral700,
                    ),
                    child: const Text('← Atrás'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapPlaceholder extends StatelessWidget {
  final bool isNetworkError;
  final bool isInvalidAddress;
  final bool isValid;

  const _MapPlaceholder({
    required this.isNetworkError,
    required this.isInvalidAddress,
    required this.isValid,
  });

  @override
  Widget build(BuildContext context) {
    String label;
    Color borderColor;
    Color bgColor;

    if (isNetworkError) {
      label = 'Mapa no disponible sin conexión';
      borderColor = AppColors.neutral300;
      bgColor = AppColors.neutral100;
    } else if (isInvalidAddress) {
      label = 'Seleccioná una dirección válida';
      borderColor = AppColors.neutral300;
      bgColor = AppColors.neutral100;
    } else if (isValid) {
      label = 'Mapa cargado';
      borderColor = AppColors.secondary500;
      bgColor = AppColors.secondary50;
    } else {
      label = 'El mapa aparecerá aquí';
      borderColor = AppColors.neutral300;
      bgColor = AppColors.neutral100;
    }

    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
          style: isInvalidAddress && !isNetworkError
              ? BorderStyle.solid
              : BorderStyle.solid,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isValid ? Icons.location_on : Icons.map_outlined,
              color: isValid ? AppColors.secondary500 : AppColors.neutral500,
              size: 28,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTextStyles.bodySm.copyWith(
                color: isValid ? AppColors.secondary500 : AppColors.neutral500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
