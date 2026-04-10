import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../models/onboarding_draft.dart';
import '../repositories/onboarding_owner_repository.dart';
import '../services/google_places_service.dart';
import '../widgets/step_indicator.dart';
import '../widgets/exit_modal.dart';
import '../widgets/inline_error.dart';
import '../analytics/onboarding_analytics.dart';

/// ONBOARDING-OWNER-02 — Paso 2: Dirección y zona
///
/// Estados:
///   Normal     — input de dirección con autocomplete (Google Places)
///   EX-09      — dirección inválida (sin número / no reconocida / sin zona)
///   EX-10      — error de red en Places API (sin conexión)
enum _AddressState { idle, searching, invalidAddress, networkError, valid }

class Step2DireccionScreen extends StatefulWidget {
  final Step2Data? initialData;
  final ValueChanged<Step2Data> onNext;
  final VoidCallback onBack;
  final VoidCallback onExit;
  final GooglePlacesService placesService;
  final OnboardingOwnerRepository ownerRepository;

  const Step2DireccionScreen({
    super.key,
    this.initialData,
    required this.onNext,
    required this.onBack,
    required this.onExit,
    required this.placesService,
    required this.ownerRepository,
  });

  @override
  State<Step2DireccionScreen> createState() => _Step2DireccionScreenState();
}

class _Step2DireccionScreenState extends State<Step2DireccionScreen> {
  final _addrCtrl = TextEditingController();
  _AddressState _addressState = _AddressState.idle;
  bool _submitted = false;

  List<PlaceSuggestion> _suggestions = [];
  Step2Data? _resolvedData;

  // Session token: regenerado al seleccionar un lugar
  String _sessionToken = DateTime.now().millisecondsSinceEpoch.toString();

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _addrCtrl.text = widget.initialData!.address;
      _resolvedData = widget.initialData;
      _addressState = _AddressState.valid;
    }
  }

  @override
  void dispose() {
    _addrCtrl.dispose();
    super.dispose();
  }

  Future<void> _onAddressChanged(String value) async {
    setState(() {
      _submitted = false;
      _resolvedData = null;
      if (value.isEmpty) {
        _addressState = _AddressState.idle;
        _suggestions = [];
      } else {
        _addressState = _AddressState.searching;
      }
    });

    if (value.trim().length < 3) return;

    try {
      final suggestions = await widget.placesService.getAddressSuggestions(
        value,
        _sessionToken,
      );
      if (!mounted) return;
      setState(() {
        _suggestions = suggestions;
        _addressState = _AddressState.searching;
      });
    } on PlacesNetworkException {
      if (!mounted) return;
      setState(() {
        _addressState = _AddressState.networkError;
        _suggestions = [];
      });
      OnboardingAnalytics.logError('step_2', 'places_network_error');
    }
  }

  Future<void> _onSuggestionSelected(PlaceSuggestion suggestion) async {
    setState(() {
      _addrCtrl.text = suggestion.description;
      _suggestions = [];
      _addressState = _AddressState.searching;
    });

    try {
      final details = await widget.placesService.getPlaceDetails(
        suggestion.placeId,
        _sessionToken,
      );

      final zone = await widget.placesService.resolveZone(
        details.lat,
        details.lng,
      );

      // Regenerar session token para la próxima sesión
      _sessionToken = (DateTime.now().millisecondsSinceEpoch + 1).toString();

      if (!mounted) return;
      setState(() {
        _resolvedData = Step2Data(
          address: details.formattedAddress,
          lat: details.lat,
          lng: details.lng,
          geohash: '', // computado server-side en CF-01
          zoneId: zone.zoneId,
          cityId: zone.cityId,
          provinceId: zone.provinceId,
        );
        _addrCtrl.text = details.formattedAddress;
        _addressState = _AddressState.valid;
      });
    } on ZoneNotFoundException {
      if (!mounted) return;
      setState(() => _addressState = _AddressState.invalidAddress);
      OnboardingAnalytics.logError('step_2', 'zone_not_found');
    } on PlacesNetworkException {
      if (!mounted) return;
      setState(() => _addressState = _AddressState.networkError);
      OnboardingAnalytics.logError('step_2', 'places_network_error');
    }
  }

  Future<void> _onNext() async {
    setState(() => _submitted = true);
    if (_addressState != _AddressState.valid || _resolvedData == null) return;

    try {
      await widget.ownerRepository.saveStep2(_resolvedData!);
    } catch (_) {
      // Error de red al guardar: continuar de todos modos
    }

    widget.onNext(_resolvedData!);
  }

  Future<void> _onExitTap() async {
    final action = await showExitModal(context);
    if (action == ExitAction.saveDraft) {
      await widget.ownerRepository.abandonDraft();
      OnboardingAnalytics.logExited('step_2');
      widget.onExit();
    } else if (action == ExitAction.discard) {
      await widget.ownerRepository.discardDraft();
      OnboardingAnalytics.logDraftDiscarded();
      widget.onExit();
    }
  }

  bool get _isNetworkError => _addressState == _AddressState.networkError;
  bool get _isInvalidAddress =>
      _addressState == _AddressState.invalidAddress ||
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
                  const Expanded(
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
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
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
                    // EX-10: banner sin conexión
                    if (_isNetworkError) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.warningBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.warningFg.withValues(alpha: 0.4)),
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

                    // Campo dirección con autocomplete
                    const Text('Dirección *', style: AppTextStyles.labelMd),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _addrCtrl,
                      onChanged: _onAddressChanged,
                      decoration: InputDecoration(
                        hintText: 'Ej: Av. Corrientes 1234, CABA',
                        hintStyle: AppTextStyles.bodyMd
                            .copyWith(color: AppColors.neutral500),
                        prefixIcon: const Icon(Icons.search,
                            color: AppColors.neutral500, size: 20),
                        suffixIcon: _addressState == _AddressState.searching
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primary500),
                                ),
                              )
                            : null,
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
                            width: (_isInvalidAddress || _isNetworkError)
                                ? 1.5
                                : 1,
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

                    // Dropdown de sugerencias Places
                    if (_suggestions.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.neutral200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _suggestions.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, color: AppColors.neutral200),
                          itemBuilder: (_, i) {
                            final s = _suggestions[i];
                            return InkWell(
                              onTap: () => _onSuggestionSelected(s),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                child: Row(
                                  children: [
                                    const Icon(Icons.location_on_outlined,
                                        size: 16, color: AppColors.neutral500),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(s.mainText,
                                              style: AppTextStyles.bodySm
                                                  .copyWith(
                                                      fontWeight:
                                                          FontWeight.w500)),
                                          if (s.secondaryText.isNotEmpty)
                                            Text(s.secondaryText,
                                                style: AppTextStyles.bodyXs
                                                    .copyWith(
                                                        color: AppColors
                                                            .neutral500)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                    // EX-09: error inline + card
                    if (_isInvalidAddress && !_isNetworkError) ...[
                      const InlineError(
                          message:
                              'No pudimos identificar la zona. Intentá con otra dirección.'),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.errorBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.errorFg.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: AppColors.errorFg, size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Dirección no reconocida. Buscá con número de puerta para asignar la zona correcta.',
                                style: AppTextStyles.bodyXs
                                    .copyWith(color: AppColors.errorFg),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Zona asignada (cuando es válida)
                    if (_addressState == _AddressState.valid &&
                        _resolvedData != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.secondary50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.secondary500),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle,
                                color: AppColors.secondary500, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'Zona: ${_resolvedData!.zoneId}',
                              style: AppTextStyles.bodySm.copyWith(
                                  color: AppColors.secondary500,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Mapa placeholder
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
                      onPressed:
                          _addressState == _AddressState.valid ? _onNext : null,
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
                        foregroundColor: AppColors.neutral700),
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
        border: Border.all(color: borderColor),
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
