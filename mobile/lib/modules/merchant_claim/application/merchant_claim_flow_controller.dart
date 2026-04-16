import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_providers.dart';
import '../../pharmacy/repositories/zones_repository.dart';
import '../data/merchant_claim_repository.dart';
import '../models/merchant_claim_models.dart';

final merchantClaimRepositoryProvider = Provider<MerchantClaimRepository>(
  (ref) => MerchantClaimRepository(),
);

final claimZonesRepositoryProvider = Provider<ZonesRepository>(
  (ref) => ZonesRepository(),
);

final merchantClaimFlowControllerProvider =
    NotifierProvider<MerchantClaimFlowController, MerchantClaimFlowState>(
  MerchantClaimFlowController.new,
);

class MerchantClaimFlowState {
  const MerchantClaimFlowState({
    this.featureEnabled = true,
    this.isBusy = false,
    this.isSearching = false,
    this.searchQuery = '',
    this.selectedZoneId,
    this.searchResults = const [],
    this.selectedMerchant,
    this.claimId,
    this.phone,
    this.claimantDisplayName,
    this.claimantNote,
    this.declaredRole = MerchantClaimDeclaredRole.owner,
    this.consentDataProcessing = false,
    this.consentLegitimacy = false,
    this.evidenceFiles = const [],
    this.statusSummary,
    this.errorMessage,
  });

  final bool featureEnabled;
  final bool isBusy;
  final bool isSearching;
  final String searchQuery;
  final String? selectedZoneId;
  final List<ClaimableMerchantCandidate> searchResults;
  final ClaimableMerchantCandidate? selectedMerchant;
  final String? claimId;
  final String? phone;
  final String? claimantDisplayName;
  final String? claimantNote;
  final MerchantClaimDeclaredRole declaredRole;
  final bool consentDataProcessing;
  final bool consentLegitimacy;
  final List<MerchantClaimEvidenceFile> evidenceFiles;
  final MerchantClaimStatusSummary? statusSummary;
  final String? errorMessage;

  bool get canSearch =>
      (selectedZoneId ?? '').trim().isNotEmpty &&
      searchQuery.trim().length >= 2;

  bool get hasRequiredEvidence {
    final storefront = evidenceFiles.any(
      (evidence) => evidence.kind == MerchantClaimEvidenceKind.storefrontPhoto,
    );
    final ownership = evidenceFiles.any(
      (evidence) =>
          evidence.kind == MerchantClaimEvidenceKind.ownershipDocument,
    );
    return storefront && ownership;
  }

  bool get canSaveDraft =>
      selectedMerchant != null &&
          declaredRole != MerchantClaimDeclaredRole.authorizedRepresentative ||
      selectedMerchant != null;

  MerchantClaimFlowState copyWith({
    bool? featureEnabled,
    bool? isBusy,
    bool? isSearching,
    String? searchQuery,
    String? selectedZoneId,
    List<ClaimableMerchantCandidate>? searchResults,
    ClaimableMerchantCandidate? selectedMerchant,
    bool clearSelectedMerchant = false,
    String? claimId,
    bool clearClaimId = false,
    String? phone,
    bool clearPhone = false,
    String? claimantDisplayName,
    bool clearClaimantDisplayName = false,
    String? claimantNote,
    bool clearClaimantNote = false,
    MerchantClaimDeclaredRole? declaredRole,
    bool? consentDataProcessing,
    bool? consentLegitimacy,
    List<MerchantClaimEvidenceFile>? evidenceFiles,
    MerchantClaimStatusSummary? statusSummary,
    bool clearStatusSummary = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return MerchantClaimFlowState(
      featureEnabled: featureEnabled ?? this.featureEnabled,
      isBusy: isBusy ?? this.isBusy,
      isSearching: isSearching ?? this.isSearching,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedZoneId: selectedZoneId ?? this.selectedZoneId,
      searchResults: searchResults ?? this.searchResults,
      selectedMerchant: clearSelectedMerchant
          ? null
          : selectedMerchant ?? this.selectedMerchant,
      claimId: clearClaimId ? null : claimId ?? this.claimId,
      phone: clearPhone ? null : phone ?? this.phone,
      claimantDisplayName: clearClaimantDisplayName
          ? null
          : claimantDisplayName ?? this.claimantDisplayName,
      claimantNote:
          clearClaimantNote ? null : claimantNote ?? this.claimantNote,
      declaredRole: declaredRole ?? this.declaredRole,
      consentDataProcessing:
          consentDataProcessing ?? this.consentDataProcessing,
      consentLegitimacy: consentLegitimacy ?? this.consentLegitimacy,
      evidenceFiles: evidenceFiles ?? this.evidenceFiles,
      statusSummary:
          clearStatusSummary ? null : statusSummary ?? this.statusSummary,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class MerchantClaimFlowController extends Notifier<MerchantClaimFlowState> {
  @override
  MerchantClaimFlowState build() => const MerchantClaimFlowState();

  MerchantClaimRepository get _repository =>
      ref.read(merchantClaimRepositoryProvider);

  void setZoneId(String zoneId) {
    state = state.copyWith(
      selectedZoneId: zoneId.trim(),
      clearError: true,
    );
  }

  void setSearchQuery(String query) {
    state = state.copyWith(
      searchQuery: query,
      clearError: true,
    );
  }

  Future<void> searchMerchants() async {
    if (!state.canSearch) return;
    state = state.copyWith(isSearching: true, clearError: true);
    try {
      final results = await _repository.searchClaimableMerchants(
        zoneId: state.selectedZoneId!,
        query: state.searchQuery,
      );
      state = state.copyWith(
        isSearching: false,
        searchResults: results,
      );
    } on MerchantClaimRepositoryException catch (error) {
      state = state.copyWith(
        isSearching: false,
        errorMessage: error.message,
      );
    } catch (_) {
      state = state.copyWith(
        isSearching: false,
        errorMessage: 'No pudimos buscar comercios para reclamar.',
      );
    }
  }

  void selectMerchant(ClaimableMerchantCandidate merchant) {
    state = state.copyWith(
      selectedMerchant: merchant,
      clearError: true,
    );
  }

  void setDeclaredRole(MerchantClaimDeclaredRole role) {
    state = state.copyWith(declaredRole: role, clearError: true);
  }

  void setPhone(String phone) {
    state = state.copyWith(phone: phone, clearError: true);
  }

  void setClaimantDisplayName(String value) {
    state = state.copyWith(claimantDisplayName: value, clearError: true);
  }

  void setClaimantNote(String value) {
    state = state.copyWith(claimantNote: value, clearError: true);
  }

  void setConsentDataProcessing(bool accepted) {
    state = state.copyWith(consentDataProcessing: accepted, clearError: true);
  }

  void setConsentLegitimacy(bool accepted) {
    state = state.copyWith(consentLegitimacy: accepted, clearError: true);
  }

  Future<void> uploadEvidence(MerchantClaimEvidenceUpload upload) async {
    if (state.selectedMerchant == null) {
      state = state.copyWith(
        errorMessage: 'Primero seleccioná el comercio que querés reclamar.',
      );
      return;
    }
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final claimId = await _ensureDraft();
      final uploaded = await _repository.uploadEvidence(
        claimId: claimId,
        upload: upload,
      );
      final nextEvidence = [...state.evidenceFiles]
        ..removeWhere((item) => item.kind == upload.kind)
        ..add(uploaded);
      state = state.copyWith(
        isBusy: false,
        evidenceFiles: nextEvidence,
      );
    } on MerchantClaimRepositoryException catch (error) {
      state = state.copyWith(
        isBusy: false,
        errorMessage: error.message,
      );
    } catch (_) {
      state = state.copyWith(
        isBusy: false,
        errorMessage: 'No pudimos subir la evidencia. Probá nuevamente.',
      );
    }
  }

  Future<void> saveDraft() async {
    if (state.selectedMerchant == null) {
      state = state.copyWith(
        errorMessage: 'Seleccioná el comercio antes de guardar.',
      );
      return;
    }
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final result = await _repository.upsertDraft(_buildDraftInput());
      state = state.copyWith(
        isBusy: false,
        claimId: result.claimId,
      );
    } on MerchantClaimRepositoryException catch (error) {
      state = state.copyWith(
        isBusy: false,
        errorMessage: error.message,
      );
    } catch (_) {
      state = state.copyWith(
        isBusy: false,
        errorMessage: 'No pudimos guardar tu borrador.',
      );
    }
  }

  Future<void> submitClaim() async {
    if (state.selectedMerchant == null) {
      state = state.copyWith(errorMessage: 'Seleccioná un comercio.');
      return;
    }
    if (!state.hasRequiredEvidence) {
      state = state.copyWith(
        errorMessage:
            'Necesitás subir una foto de fachada y una prueba de vínculo.',
      );
      return;
    }
    if (!state.consentDataProcessing || !state.consentLegitimacy) {
      state = state.copyWith(
        errorMessage: 'Necesitás aceptar los consentimientos para enviar.',
      );
      return;
    }

    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final claimId = await _ensureDraft();
      final summary = await _repository.submitClaim(claimId: claimId);
      state = state.copyWith(
        isBusy: false,
        statusSummary: summary,
      );
    } on MerchantClaimRepositoryException catch (error) {
      state = state.copyWith(
        isBusy: false,
        errorMessage: error.message,
      );
    } catch (_) {
      state = state.copyWith(
        isBusy: false,
        errorMessage: 'No pudimos enviar tu reclamo.',
      );
    }
  }

  Future<void> loadStatus({String? claimId}) async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final summary = await _repository.getMyStatus(claimId: claimId);
      state = state.copyWith(
        isBusy: false,
        statusSummary: summary,
      );
    } on MerchantClaimRepositoryException catch (error) {
      state = state.copyWith(
        isBusy: false,
        errorMessage: error.message,
      );
    } catch (_) {
      state = state.copyWith(
        isBusy: false,
        errorMessage: 'No pudimos cargar el estado de tu reclamo.',
      );
    }
  }

  Future<String> _ensureDraft() async {
    final claimId = state.claimId;
    final result =
        await _repository.upsertDraft(_buildDraftInput(claimId: claimId));
    if (state.claimId != result.claimId) {
      state = state.copyWith(claimId: result.claimId);
    }
    return result.claimId;
  }

  MerchantClaimDraftInput _buildDraftInput({String? claimId}) {
    final merchant = state.selectedMerchant;
    if (merchant == null) {
      throw const MerchantClaimRepositoryException(
        code: 'claim-merchant-required',
        message: 'Seleccioná un comercio para continuar.',
      );
    }
    return MerchantClaimDraftInput(
      claimId: claimId,
      merchantId: merchant.merchantId,
      declaredRole: state.declaredRole,
      phone: state.phone,
      claimantDisplayName: state.claimantDisplayName,
      claimantNote: state.claimantNote,
      hasAcceptedDataProcessingConsent: state.consentDataProcessing,
      hasAcceptedLegitimacyDeclaration: state.consentLegitimacy,
      evidenceFiles: state.evidenceFiles,
    );
  }
}

final claimStatusForCurrentUserProvider =
    FutureProvider<MerchantClaimStatusSummary?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  final repository = ref.watch(merchantClaimRepositoryProvider);
  return repository.getMyStatus();
});

final claimActiveZonesProvider =
    FutureProvider<List<({String id, String label})>>(
  (ref) async {
    final repository = ref.watch(claimZonesRepositoryProvider);
    final zones = await repository.getActiveZones();
    return zones
        .map((zone) => (id: zone.zoneId, label: zone.name))
        .toList(growable: false);
  },
);
