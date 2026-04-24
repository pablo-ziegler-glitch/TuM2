import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/auth/auth_notifier.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/providers/feature_flags_provider.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_text_input.dart';
import '../application/merchant_claim_flow_controller.dart';
import '../models/merchant_claim_models.dart';

class ClaimIntroScreen extends ConsumerWidget {
  const ClaimIntroScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final email = user?.email ?? 'Sin email';
    final claimEnabled =
        ref.watch(merchantClaimFlowEnabledProvider).valueOrNull ?? true;
    return _ClaimScaffold(
      title: 'Reclamá tu comercio',
      step: 1,
      totalSteps: 5,
      subtitle:
          'Gestioná cómo ven tu comercio en TuM2. El reclamo inicia validación y revisión.',
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: !claimEnabled
                  ? null
                  : () {
                      ref
                          .read(merchantClaimFlowControllerProvider.notifier)
                          .startClaim()
                          .ignore();
                      context.push(AppRoutes.claimSelect);
                    },
              icon: const Icon(Icons.arrow_forward_rounded),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary500,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(54),
              ),
              label: const Text('Empezar'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: !claimEnabled
                  ? null
                  : () => context.push(AppRoutes.claimStatus),
              child: const Text('Ver estado de mi reclamo'),
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!claimEnabled) ...[
            const _ClaimErrorBanner(
              message:
                  'El flujo de reclamos está deshabilitado temporalmente. Probá nuevamente más tarde.',
            ),
            const SizedBox(height: 12),
          ],
          _InfoCard(
            icon: Icons.alternate_email_rounded,
            title: 'Usaremos el email de tu cuenta actual',
            subtitle: email,
          ),
          const SizedBox(height: 10),
          const _InfoCard(
            icon: Icons.photo_camera_outlined,
            title: 'Subí una foto del frente y una prueba de vínculo',
            subtitle:
                'La revisión inicial combina controles automáticos y humanos.',
          ),
          const SizedBox(height: 10),
          const _InfoCard(
            icon: Icons.hourglass_bottom_rounded,
            title: 'Todavía no tenés acceso completo al panel de tu comercio',
            subtitle: 'Vamos a revisar tu solicitud antes de habilitar OWNER.',
          ),
        ],
      ),
    );
  }
}

class ClaimSelectMerchantScreen extends ConsumerWidget {
  const ClaimSelectMerchantScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(merchantClaimFlowControllerProvider);
    final controller = ref.read(merchantClaimFlowControllerProvider.notifier);
    final zonesAsync = ref.watch(claimActiveZonesProvider);

    return _ClaimScaffold(
      title: 'Seleccioná el comercio',
      step: 2,
      totalSteps: 5,
      subtitle: 'Elegí zona y comercio para asociar un reclamo concreto.',
      footer: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: state.selectedMerchant == null
              ? null
              : () async {
                  await controller.trackStepCompleted('select_merchant');
                  if (!context.mounted) return;
                  context.push(AppRoutes.claimApplicant);
                },
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary500,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(54),
          ),
          child: const Text('Continuar'),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TonalSection(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                zonesAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const Text(
                    'No pudimos cargar las zonas.',
                    style: AppTextStyles.bodySm,
                  ),
                  data: (zones) {
                    if (zones.isEmpty) {
                      return const Text(
                        'No hay zonas disponibles para reclamo en este momento.',
                        style: AppTextStyles.bodySm,
                      );
                    }
                    final selected = state.selectedZoneId;
                    return DropdownButtonFormField<String>(
                      initialValue: zones.any((zone) => zone.id == selected)
                          ? selected
                          : null,
                      items: zones
                          .map(
                            (zone) => DropdownMenuItem<String>(
                              value: zone.id,
                              child: Text(zone.label),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value == null) return;
                        controller.setZoneId(value);
                      },
                      decoration: const InputDecoration(
                        labelText: 'Zona',
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                AppTextInput(
                  hint: 'Nombre del comercio',
                  onChanged: controller.setSearchQuery,
                  textInputAction: TextInputAction.search,
                  suffixIcon: IconButton(
                    onPressed:
                        state.canSearch ? controller.searchMerchants : null,
                    icon: const Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: state.canSearch && !state.isSearching
                        ? controller.searchMerchants
                        : null,
                    icon: state.isSearching
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                    label: const Text('Buscar'),
                  ),
                ),
              ],
            ),
          ),
          if (state.errorMessage != null) ...[
            const SizedBox(height: 8),
            _ClaimErrorBanner(message: state.errorMessage!),
          ],
          const SizedBox(height: 12),
          if (state.searchResults.isEmpty &&
              state.searchQuery.trim().length >= 2)
            const Text(
              'No encontramos coincidencias. Probá con otro término o zona.',
              style: AppTextStyles.bodySm,
            ),
          ...state.searchResults.map(
            (merchant) => _MerchantCandidateTile(
              merchant: merchant,
              selected:
                  state.selectedMerchant?.merchantId == merchant.merchantId,
              onTap: () => controller.selectMerchant(merchant),
            ),
          ),
        ],
      ),
    );
  }
}

class ClaimApplicantDataScreen extends ConsumerStatefulWidget {
  const ClaimApplicantDataScreen({super.key});

  @override
  ConsumerState<ClaimApplicantDataScreen> createState() =>
      _ClaimApplicantDataScreenState();
}

class _ClaimApplicantDataScreenState
    extends ConsumerState<ClaimApplicantDataScreen> {
  late final TextEditingController _phoneController;
  late final TextEditingController _nameController;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    final state = ref.read(merchantClaimFlowControllerProvider);
    _phoneController = TextEditingController(text: state.phone ?? '');
    _nameController =
        TextEditingController(text: state.claimantDisplayName ?? '');
    _noteController = TextEditingController(text: state.claimantNote ?? '');
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(merchantClaimFlowControllerProvider);
    final controller = ref.read(merchantClaimFlowControllerProvider.notifier);
    final email = ref.watch(currentUserProvider)?.email ?? 'Sin email';

    return _ClaimScaffold(
      title: 'Tus datos',
      step: 3,
      totalSteps: 5,
      subtitle:
          'Confirmá tu identidad operativa. El email queda fijo por seguridad.',
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () async {
                await controller.trackStepCompleted('applicant_data');
                if (!context.mounted) return;
                context.push(AppRoutes.claimEvidence);
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary500,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(54),
              ),
              child: const Text('Continuar'),
            ),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: state.isBusy
                ? null
                : () async {
                    await controller.saveDraft();
                    await controller.trackAbandoned(stepId: 'applicant_data');
                    if (!context.mounted) return;
                    final hasError = ref
                            .read(merchantClaimFlowControllerProvider)
                            .errorMessage !=
                        null;
                    if (hasError) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Borrador guardado.'),
                      ),
                    );
                    context.go(AppRoutes.profile);
                  },
            child: const Text('Guardar y salir'),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TonalSection(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoCard(
                  icon: Icons.alternate_email,
                  title: 'Email fijo del reclamo',
                  subtitle: email,
                ),
                const SizedBox(height: 10),
                AppTextInput(
                  hint: 'Nombre y apellido (opcional)',
                  controller: _nameController,
                  onChanged: controller.setClaimantDisplayName,
                ),
                const SizedBox(height: 10),
                AppTextInput(
                  hint: 'Teléfono (opcional, sin verificación en MVP)',
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  onChanged: controller.setPhone,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<MerchantClaimDeclaredRole>(
                  initialValue: state.declaredRole,
                  items: MerchantClaimDeclaredRole.values
                      .map(
                        (role) => DropdownMenuItem(
                          value: role,
                          child: Text(role.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (role) {
                    if (role != null) {
                      controller.setDeclaredRole(role);
                    }
                  },
                  decoration: const InputDecoration(
                    labelText: 'Rol declarado',
                  ),
                ),
                const SizedBox(height: 10),
                AppTextInput(
                  hint: 'Observación opcional',
                  controller: _noteController,
                  onChanged: controller.setClaimantNote,
                ),
              ],
            ),
          ),
          if (state.errorMessage != null) ...[
            const SizedBox(height: 10),
            _ClaimErrorBanner(message: state.errorMessage!),
          ],
        ],
      ),
    );
  }
}

class ClaimEvidenceScreen extends ConsumerStatefulWidget {
  const ClaimEvidenceScreen({super.key});

  @override
  ConsumerState<ClaimEvidenceScreen> createState() =>
      _ClaimEvidenceScreenState();
}

class _ClaimEvidenceScreenState extends ConsumerState<ClaimEvidenceScreen> {
  final ImagePicker _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(merchantClaimFlowControllerProvider);
    final categoryCopy = _evidenceCopyForCategory(
      state.selectedMerchant?.categoryId,
    );

    return _ClaimScaffold(
      title: 'Subí evidencia',
      step: 4,
      totalSteps: 5,
      subtitle: 'Subí una foto de fachada y una prueba documental mínima.',
      footer: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: state.hasRequiredEvidence
              ? () async {
                  await ref
                      .read(merchantClaimFlowControllerProvider.notifier)
                      .trackStepCompleted('evidence');
                  if (!context.mounted) return;
                  context.push(AppRoutes.claimConsent);
                }
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary500,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(54),
          ),
          child: const Text('Continuar'),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _InfoCard(
            icon: Icons.lock_outline_rounded,
            title: 'Tus archivos se usan solo para revisar tu solicitud',
            subtitle:
                'Los adjuntos se procesan de forma privada y con acceso restringido.',
          ),
          const SizedBox(height: 10),
          _EvidenceUploadTile(
            title: 'Foto de fachada (obligatoria)',
            subtitle: categoryCopy.storefrontHint,
            hasFile: state.evidenceFiles.any(
              (file) => file.kind == MerchantClaimEvidenceKind.storefrontPhoto,
            ),
            onUpload: state.isBusy
                ? null
                : () => _pickAndUpload(
                      kind: MerchantClaimEvidenceKind.storefrontPhoto,
                    ),
          ),
          const SizedBox(height: 10),
          _EvidenceUploadTile(
            title: 'Prueba documental (obligatoria)',
            subtitle: categoryCopy.documentHint,
            hasFile: state.evidenceFiles.any(
              (file) =>
                  file.kind == MerchantClaimEvidenceKind.ownershipDocument,
            ),
            onUpload: state.isBusy
                ? null
                : () => _pickAndUpload(
                      kind: MerchantClaimEvidenceKind.ownershipDocument,
                    ),
          ),
          if (state.errorMessage != null) ...[
            const SizedBox(height: 10),
            _ClaimErrorBanner(message: state.errorMessage!),
          ],
          const SizedBox(height: 10),
          const _TonalSection(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.flag_outlined,
                    color: AppColors.primary600, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Próximo paso: revisá consentimiento y enviá la solicitud.',
                    style: AppTextStyles.bodySm,
                  ),
                ),
              ],
            ),
          ),
          if (state.isBusy) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }

  Future<void> _pickAndUpload({
    required MerchantClaimEvidenceKind kind,
  }) async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1800,
        imageQuality: 88,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final contentType = (file.mimeType ?? 'image/jpeg').trim().toLowerCase();
      final upload = MerchantClaimEvidenceUpload(
        id: '${kind.apiValue}_${DateTime.now().millisecondsSinceEpoch}',
        kind: kind,
        bytes: bytes,
        contentType: contentType.isEmpty ? 'image/jpeg' : contentType,
        originalFileName: file.name,
      );
      await ref
          .read(merchantClaimFlowControllerProvider.notifier)
          .uploadEvidence(upload);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pudimos cargar el archivo.')),
      );
    }
  }
}

class ClaimConsentScreen extends ConsumerWidget {
  const ClaimConsentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(merchantClaimFlowControllerProvider);
    final controller = ref.read(merchantClaimFlowControllerProvider.notifier);

    return _ClaimScaffold(
      title: 'Confirmación y envío',
      step: 5,
      totalSteps: 5,
      subtitle: 'Revisá consentimientos y enviá el reclamo para validación.',
      footer: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: state.isBusy
                  ? null
                  : () async {
                      await controller.saveDraft();
                      await controller.trackAbandoned(stepId: 'consent');
                      if (!context.mounted) return;
                      final hasError = ref
                              .read(merchantClaimFlowControllerProvider)
                              .errorMessage !=
                          null;
                      if (hasError) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Borrador guardado.'),
                        ),
                      );
                    },
              child: const Text('Guardar borrador'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: state.isBusy
                  ? null
                  : () async {
                      await controller.trackStepCompleted('consent');
                      await controller.submitClaim();
                      final currentState =
                          ref.read(merchantClaimFlowControllerProvider);
                      if (currentState.errorMessage != null) {
                        return;
                      }
                      if (!context.mounted) return;
                      context.go(AppRoutes.claimSuccess);
                    },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.tertiary700,
                foregroundColor: Colors.white,
              ),
              child: const Text('Enviar reclamo'),
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ClaimSubmissionSummaryCard(state: state),
          const SizedBox(height: 10),
          const _InfoCard(
            icon: Icons.gavel_outlined,
            title: 'Vamos a revisar tu solicitud',
            subtitle:
                'Si falta algo, te avisaremos para completar información.',
          ),
          const SizedBox(height: 10),
          CheckboxListTile(
            value: state.consentDataProcessing,
            onChanged: (value) =>
                controller.setConsentDataProcessing(value == true),
            title: const Text(
              'Acepto el tratamiento de datos y documentación del reclamo.',
              style: AppTextStyles.bodySm,
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          CheckboxListTile(
            value: state.consentLegitimacy,
            onChanged: (value) =>
                controller.setConsentLegitimacy(value == true),
            title: const Text(
              'Declaro que la información aportada es legítima.',
              style: AppTextStyles.bodySm,
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: 8),
          if (state.errorMessage != null) ...[
            _ClaimErrorBanner(message: state.errorMessage!),
            const SizedBox(height: 10),
          ],
          if (state.isBusy) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class ClaimSuccessScreen extends ConsumerWidget {
  const ClaimSuccessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary =
        ref.watch(merchantClaimFlowControllerProvider).statusSummary;
    final status = summary?.claimStatus ?? MerchantClaimStatus.submitted;
    return _ClaimScaffold(
      title: 'Reclamo enviado',
      subtitle: 'Tu solicitud quedó registrada y ya está en revisión.',
      showProgress: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.successBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vamos a revisar tu solicitud',
                  style: AppTextStyles.headingSm,
                ),
                SizedBox(height: 6),
                Text(
                  'Todavía no tenés acceso completo al panel de tu comercio.',
                  style: AppTextStyles.bodySm,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _statusBadgeBg(status),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'Estado actual: ${_statusLabel(status)}',
              style: AppTextStyles.labelSm.copyWith(
                color: _statusBadgeFg(status),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () => context.go(AppRoutes.claimStatus),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary500,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
            ),
            child: const Text('Ver estado del reclamo'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => context.go(AppRoutes.profile),
            child: const Text('Volver al perfil'),
          ),
        ],
      ),
    );
  }
}

class ClaimStatusScreen extends ConsumerStatefulWidget {
  const ClaimStatusScreen({super.key});

  @override
  ConsumerState<ClaimStatusScreen> createState() => _ClaimStatusScreenState();
}

class _ClaimStatusScreenState extends ConsumerState<ClaimStatusScreen> {
  bool _handledApprovedTransition = false;
  DateTime? _lastAccessRefreshAt;
  late final _ClaimLifecycleObserver _lifecycleObserver;

  @override
  void initState() {
    super.initState();
    _lifecycleObserver = _ClaimLifecycleObserver(_handleResume);
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
    scheduleMicrotask(() => _syncClaimStatusAndSession(forceRefresh: true));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    super.dispose();
  }

  Future<void> _handleResume() async {
    await _syncClaimStatusAndSession(forceRefresh: false);
  }

  Future<void> _syncClaimStatusAndSession({
    required bool forceRefresh,
  }) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _lastAccessRefreshAt != null &&
        now.difference(_lastAccessRefreshAt!) < const Duration(seconds: 6)) {
      return;
    }
    _lastAccessRefreshAt = now;

    try {
      await ref.read(authNotifierProvider).refreshSession();
    } catch (_) {
      // Si falla refresh de token, igualmente intentamos refrescar estado de claim.
    }
    await ref.read(merchantClaimFlowControllerProvider.notifier).loadStatus();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(merchantClaimFlowControllerProvider);
    final summary = state.statusSummary;
    final authState = ref.watch(authNotifierProvider).authState;

    if (!_handledApprovedTransition &&
        summary?.claimStatus == MerchantClaimStatus.approved &&
        authState is AuthAuthenticated &&
        authState.role == 'owner' &&
        !authState.ownerPending) {
      _handledApprovedTransition = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.go(
          AppRoutes.accessUpdatedPath(
            target: 'owner',
            reason: 'approved_transition',
            from: AppRoutes.claimStatus,
          ),
        );
      });
    }

    return _ClaimScaffold(
      title: 'Estado de tu reclamo',
      subtitle: 'Seguí el estado y próximos pasos de tu solicitud.',
      showProgress: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state.isBusy) const LinearProgressIndicator(),
          if (state.errorMessage != null) ...[
            const SizedBox(height: 10),
            _ClaimErrorBanner(message: state.errorMessage!),
          ],
          const SizedBox(height: 12),
          if (summary == null && !state.isBusy)
            const _InfoCard(
              icon: Icons.info_outline,
              title: 'Todavía no tenés reclamos enviados',
              subtitle: 'Cuando envíes uno, vas a poder seguirlo desde acá.',
            ),
          if (summary != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.merchantSurfaceLowest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: _statusBadgeBg(summary.claimStatus),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          _statusLabel(summary.claimStatus).toUpperCase(),
                          style: AppTextStyles.labelSm.copyWith(
                            fontWeight: FontWeight.w700,
                            color: _statusBadgeFg(summary.claimStatus),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    summary.merchantName ?? 'Comercio ${summary.merchantId}',
                    style: AppTextStyles.headingSm,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _statusDescription(summary.claimStatus),
                    style: AppTextStyles.bodySm,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _ClaimStatusTimeline(status: summary.claimStatus),
            const SizedBox(height: 10),
            _InfoCard(
              icon: Icons.help_outline,
              title: 'Próximo paso',
              subtitle: _nextStepDescription(summary.claimStatus),
            ),
            if (summary.duplicateOfClaimId?.isNotEmpty == true ||
                summary.conflictType?.isNotEmpty == true) ...[
              const SizedBox(height: 10),
              _InfoCard(
                icon: Icons.info_outline,
                title: 'Referencia del caso',
                subtitle: _claimReference(summary),
              ),
            ],
          ],
          const SizedBox(height: 10),
          FilledButton(
            onPressed: state.isBusy
                ? null
                : () => _syncClaimStatusAndSession(forceRefresh: true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary500,
              foregroundColor: Colors.white,
            ),
            child: const Text('Actualizar estado'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => context.go(AppRoutes.profile),
            child: const Text('Volver al perfil'),
          ),
        ],
      ),
    );
  }
}

class _ClaimLifecycleObserver extends WidgetsBindingObserver {
  _ClaimLifecycleObserver(this.onResumed);

  final Future<void> Function() onResumed;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(onResumed());
  }
}

class _ClaimScaffold extends StatelessWidget {
  const _ClaimScaffold({
    required this.title,
    required this.child,
    this.step,
    this.totalSteps,
    this.footer,
    this.subtitle,
    this.showProgress = true,
  });

  final String title;
  final Widget child;
  final int? step;
  final int? totalSteps;
  final Widget? footer;
  final String? subtitle;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    final safeStep = step ?? 0;
    final safeTotal = totalSteps ?? 0;
    final progress = safeStep > 0 && safeTotal > 0
        ? (safeStep / safeTotal).clamp(0, 1).toDouble()
        : null;
    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        backgroundColor: AppColors.neutral50,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.verified_user_outlined,
                color: AppColors.primary600,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            const Text('Verifier', style: AppTextStyles.headingSm),
          ],
        ),
      ),
      bottomNavigationBar: footer == null
          ? null
          : _ClaimBottomBar(
              child: footer!,
            ),
      body: Column(
        children: [
          if (showProgress && progress != null)
            LinearProgressIndicator(
              value: progress,
              color: AppColors.primary600,
              backgroundColor: AppColors.neutral200,
              minHeight: 4,
            ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                20 + (footer != null ? 96 : 0),
              ),
              children: [
                _ClaimStepHeader(
                  title: title,
                  subtitle: subtitle,
                  step: step,
                  totalSteps: totalSteps,
                ),
                const SizedBox(height: 14),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.merchantSurfaceLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.primary100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primary700, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.labelSm.copyWith(
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.neutral800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: AppTextStyles.bodySm),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MerchantCandidateTile extends StatelessWidget {
  const _MerchantCandidateTile({
    required this.merchant,
    required this.selected,
    required this.onTap,
  });

  final ClaimableMerchantCandidate merchant;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary50 : AppColors.merchantSurfaceLowest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        onTap: onTap,
        title: Text(merchant.name, style: AppTextStyles.labelMd),
        subtitle: Text(
          merchant.address?.isNotEmpty == true
              ? merchant.address!
              : 'Sin dirección disponible',
          style: AppTextStyles.bodySm,
        ),
        trailing: merchant.isConflictCandidate
            ? const Icon(Icons.warning_amber_rounded,
                color: AppColors.warningFg)
            : const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _EvidenceUploadTile extends StatelessWidget {
  const _EvidenceUploadTile({
    required this.title,
    required this.subtitle,
    required this.hasFile,
    required this.onUpload,
  });

  final String title;
  final String subtitle;
  final bool hasFile;
  final VoidCallback? onUpload;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.merchantSurfaceLowest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.labelMd),
          const SizedBox(height: 4),
          Text(subtitle, style: AppTextStyles.bodySm),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  hasFile ? 'Archivo cargado' : 'Archivo pendiente',
                  style: AppTextStyles.bodySm.copyWith(
                    color: hasFile ? AppColors.successFg : AppColors.warningFg,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onUpload,
                icon: const Icon(Icons.upload_file),
                label: Text(hasFile ? 'Reemplazar' : 'Subir'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClaimErrorBanner extends StatelessWidget {
  const _ClaimErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.errorFg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySm.copyWith(color: AppColors.errorFg),
            ),
          ),
        ],
      ),
    );
  }
}

class _TonalSection extends StatelessWidget {
  const _TonalSection({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.merchantSurfaceLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }
}

class _ClaimSubmissionSummaryCard extends StatelessWidget {
  const _ClaimSubmissionSummaryCard({required this.state});

  final MerchantClaimFlowState state;

  @override
  Widget build(BuildContext context) {
    final merchant = state.selectedMerchant;
    final evidences = state.evidenceFiles.length;
    return _TonalSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Resumen del reclamo', style: AppTextStyles.labelMd),
          const SizedBox(height: 8),
          Text(
            merchant?.name ?? 'Comercio no seleccionado',
            style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Rol declarado: ${state.declaredRole.label}',
            style: AppTextStyles.bodySm,
          ),
          const SizedBox(height: 2),
          Text(
            'Archivos cargados: $evidences',
            style: AppTextStyles.bodySm,
          ),
        ],
      ),
    );
  }
}

class _ClaimStatusTimeline extends StatelessWidget {
  const _ClaimStatusTimeline({required this.status});

  final MerchantClaimStatus status;

  @override
  Widget build(BuildContext context) {
    final currentIndex = _timelineIndex(status);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.merchantSurfaceLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          _TimelineItem(
            title: 'Solicitud recibida',
            subtitle: 'Recibimos tu reclamo correctamente.',
            active: currentIndex == 0,
            done: currentIndex > 0,
          ),
          const SizedBox(height: 10),
          _TimelineItem(
            title: 'Validación inicial',
            subtitle: 'Estamos verificando datos y evidencias.',
            active: currentIndex == 1,
            done: currentIndex > 1,
          ),
          const SizedBox(height: 10),
          _TimelineItem(
            title: 'Decisión',
            subtitle: 'Definimos aprobación, rechazo o pedido adicional.',
            active: currentIndex == 2,
            done: currentIndex > 2,
          ),
        ],
      ),
    );
  }

  int _timelineIndex(MerchantClaimStatus status) {
    switch (status) {
      case MerchantClaimStatus.draft:
        return 0;
      case MerchantClaimStatus.submitted:
      case MerchantClaimStatus.underReview:
      case MerchantClaimStatus.needsMoreInfo:
      case MerchantClaimStatus.duplicateClaim:
      case MerchantClaimStatus.conflictDetected:
        return 1;
      case MerchantClaimStatus.approved:
      case MerchantClaimStatus.rejected:
        return 2;
    }
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.title,
    required this.subtitle,
    required this.active,
    required this.done,
  });

  final String title;
  final String subtitle;
  final bool active;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final dotBg = done
        ? AppColors.primary600
        : active
            ? AppColors.primary100
            : AppColors.neutral200;
    final dotFg = done ? Colors.white : AppColors.primary700;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: dotBg,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Icon(
            done ? Icons.check : Icons.circle,
            color: dotFg,
            size: done ? 14 : 8,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.labelMd.copyWith(
                  color: active || done
                      ? AppColors.neutral900
                      : AppColors.neutral700,
                ),
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: AppTextStyles.bodySm),
            ],
          ),
        ),
      ],
    );
  }
}

class _ClaimStepHeader extends StatelessWidget {
  const _ClaimStepHeader({
    required this.title,
    required this.step,
    required this.totalSteps,
    this.subtitle,
  });

  final String title;
  final int? step;
  final int? totalSteps;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final showStep = step != null && totalSteps != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showStep)
          Text(
            'PASO ${step!} DE ${totalSteps!}',
            style: AppTextStyles.labelSm.copyWith(
              color: AppColors.primary700,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        if (showStep) const SizedBox(height: 6),
        Text(
          title,
          style: AppTextStyles.headingLg.copyWith(
            height: 1.18,
          ),
        ),
        if (subtitle?.isNotEmpty == true) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: AppTextStyles.bodyMd.copyWith(color: AppColors.neutral700),
          ),
        ],
      ],
    );
  }
}

class _ClaimBottomBar extends StatelessWidget {
  const _ClaimBottomBar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.merchantSurfaceLowest,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: SafeArea(top: false, child: child),
    );
  }
}

String _statusLabel(MerchantClaimStatus status) {
  switch (status) {
    case MerchantClaimStatus.draft:
      return 'Borrador';
    case MerchantClaimStatus.submitted:
      return 'Enviado';
    case MerchantClaimStatus.underReview:
      return 'En revisión';
    case MerchantClaimStatus.needsMoreInfo:
      return 'Falta información';
    case MerchantClaimStatus.approved:
      return 'Aprobado';
    case MerchantClaimStatus.rejected:
      return 'Rechazado';
    case MerchantClaimStatus.duplicateClaim:
      return 'Duplicado';
    case MerchantClaimStatus.conflictDetected:
      return 'Conflicto detectado';
  }
}

Color _statusBadgeBg(MerchantClaimStatus status) {
  switch (status) {
    case MerchantClaimStatus.approved:
      return AppColors.successBg;
    case MerchantClaimStatus.rejected:
    case MerchantClaimStatus.conflictDetected:
      return AppColors.errorBg;
    case MerchantClaimStatus.needsMoreInfo:
    case MerchantClaimStatus.duplicateClaim:
      return AppColors.warningBg;
    case MerchantClaimStatus.draft:
    case MerchantClaimStatus.submitted:
    case MerchantClaimStatus.underReview:
      return AppColors.infoBg;
  }
}

Color _statusBadgeFg(MerchantClaimStatus status) {
  switch (status) {
    case MerchantClaimStatus.approved:
      return AppColors.successFg;
    case MerchantClaimStatus.rejected:
    case MerchantClaimStatus.conflictDetected:
      return AppColors.errorFg;
    case MerchantClaimStatus.needsMoreInfo:
    case MerchantClaimStatus.duplicateClaim:
      return AppColors.tertiary700;
    case MerchantClaimStatus.draft:
    case MerchantClaimStatus.submitted:
    case MerchantClaimStatus.underReview:
      return AppColors.primary700;
  }
}

String _statusDescription(MerchantClaimStatus status) {
  switch (status) {
    case MerchantClaimStatus.draft:
      return 'Tu reclamo está guardado como borrador.';
    case MerchantClaimStatus.submitted:
      return 'Recibimos tu reclamo y lo estamos procesando.';
    case MerchantClaimStatus.underReview:
      return 'Tu caso está en revisión manual.';
    case MerchantClaimStatus.needsMoreInfo:
      return 'Necesitamos más evidencia para decidir.';
    case MerchantClaimStatus.approved:
      return 'Tu reclamo fue aprobado.';
    case MerchantClaimStatus.rejected:
      return 'Tu reclamo fue rechazado.';
    case MerchantClaimStatus.duplicateClaim:
      return 'Detectamos un reclamo duplicado para este comercio.';
    case MerchantClaimStatus.conflictDetected:
      return 'Detectamos un conflicto que requiere revisión manual.';
  }
}

String _nextStepDescription(MerchantClaimStatus status) {
  switch (status) {
    case MerchantClaimStatus.draft:
      return 'Completá evidencia y enviá el reclamo.';
    case MerchantClaimStatus.submitted:
    case MerchantClaimStatus.underReview:
      return 'Esperá la revisión. Te avisaremos si hace falta más información.';
    case MerchantClaimStatus.needsMoreInfo:
      return 'Volvé al flujo y subí la información solicitada.';
    case MerchantClaimStatus.approved:
      return 'Tu acceso OWNER se habilita por backend autorizado.';
    case MerchantClaimStatus.rejected:
      return 'Podés iniciar un nuevo reclamo si corresponde.';
    case MerchantClaimStatus.duplicateClaim:
    case MerchantClaimStatus.conflictDetected:
      return 'El caso seguirá revisión manual para resolución.';
  }
}

String _claimReference(MerchantClaimStatusSummary summary) {
  if (summary.duplicateOfClaimId?.isNotEmpty == true) {
    return 'Encontramos un reclamo relacionado (${summary.duplicateOfClaimId}).';
  }
  if (summary.conflictType?.isNotEmpty == true) {
    return 'Detectamos un conflicto (${summary.conflictType}) y lo vamos a revisar manualmente.';
  }
  return 'Tu caso quedó registrado para revisión.';
}

({String storefrontHint, String documentHint}) _evidenceCopyForCategory(
  String? categoryId,
) {
  switch ((categoryId ?? '').trim()) {
    case 'pharmacy':
      return (
        storefrontHint:
            'Mostrá la farmacia y su cartel visible desde la calle.',
        documentHint:
            'Podés subir habilitación, constancia fiscal o factura del local.',
      );
    case 'kiosk':
      return (
        storefrontHint: 'Mostrá el frente del kiosco con su identificación.',
        documentHint:
            'Podés subir habilitación municipal, contrato o factura vinculada.',
      );
    case 'gomeria':
      return (
        storefrontHint: 'Mostrá el frente de la gomería y su acceso principal.',
        documentHint:
            'Subí una constancia comercial o factura asociada al local.',
      );
    default:
      return (
        storefrontHint: 'Mostrá frente/cartel del comercio.',
        documentHint: 'Por ejemplo habilitación, factura o constancia.',
      );
  }
}

extension on Future<void> {
  void ignore() {}
}
