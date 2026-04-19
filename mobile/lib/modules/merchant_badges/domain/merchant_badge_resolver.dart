import 'merchant_visual_models.dart';

class MerchantBadgeResolver {
  const MerchantBadgeResolver._();

  static BadgeResolution resolve({
    required MerchantVisualState state,
    required MerchantSurface surface,
  }) {
    if (_isPublicSurface(surface) && !_isPubliclyVisible(state.visibility)) {
      return BadgeResolution(
        primary: null,
        secondary: const <MerchantBadgeKey>[],
        rubricLabel: _rubricLabelForSurface(state.categoryLabel, surface),
        confidence: null,
      );
    }

    if (surface == MerchantSurface.ownerPanel) {
      return BadgeResolution(
        primary: _ownerVisibilityBadge(state.visibility),
        secondary: <MerchantBadgeKey>[
          _ownerLifecycleBadge(state.lifecycle),
        ],
        rubricLabel: _rubricLabelForSurface(state.categoryLabel, surface),
        confidence: _confidenceBadge(state.confidence),
      );
    }

    if (surface == MerchantSurface.claimStatus) {
      final claimBadge = _claimBadge(state.claimState);
      return BadgeResolution(
        primary: claimBadge,
        secondary: const <MerchantBadgeKey>[],
        rubricLabel: null,
        confidence: null,
      );
    }

    final primary = _resolvePrimaryOperationalBadge(state);
    final confidence = _confidenceBadge(state.confidence);
    final secondary = _resolveSecondaryBadges(
      state: state,
      surface: surface,
      primary: primary,
      confidence: confidence,
    );

    return BadgeResolution(
      primary: primary,
      secondary: secondary,
      rubricLabel: _rubricLabelForSurface(state.categoryLabel, surface),
      confidence: confidence,
    );
  }

  static bool _isPublicSurface(MerchantSurface surface) {
    return surface == MerchantSurface.searchCard ||
        surface == MerchantSurface.compactCard ||
        surface == MerchantSurface.detail ||
        surface == MerchantSurface.mapMarker ||
        surface == MerchantSurface.pharmacyPublic;
  }

  static bool _isPubliclyVisible(MerchantVisibilityState visibility) {
    return visibility == MerchantVisibilityState.visible;
  }

  static String? _rubricLabelForSurface(
      String? label, MerchantSurface surface) {
    if (surface == MerchantSurface.mapMarker ||
        surface == MerchantSurface.claimStatus) {
      return null;
    }
    final trimmed = (label ?? '').trim();
    if (trimmed.isEmpty) return null;
    return trimmed;
  }

  static MerchantBadgeKey _ownerVisibilityBadge(
      MerchantVisibilityState visibility) {
    switch (visibility) {
      case MerchantVisibilityState.visible:
        return MerchantBadgeKey.ownerVisible;
      case MerchantVisibilityState.reviewPending:
        return MerchantBadgeKey.ownerReviewPending;
      case MerchantVisibilityState.hidden:
        return MerchantBadgeKey.ownerHidden;
      case MerchantVisibilityState.suppressed:
        return MerchantBadgeKey.ownerSuppressed;
    }
  }

  static MerchantBadgeKey _ownerLifecycleBadge(
      MerchantLifecycleState lifecycle) {
    switch (lifecycle) {
      case MerchantLifecycleState.active:
        return MerchantBadgeKey.ownerActive;
      case MerchantLifecycleState.draft:
        return MerchantBadgeKey.ownerDraft;
      case MerchantLifecycleState.inactive:
        return MerchantBadgeKey.ownerInactive;
      case MerchantLifecycleState.archived:
        return MerchantBadgeKey.ownerArchived;
    }
  }

  static MerchantBadgeKey? _claimBadge(MerchantClaimWorkflowState? state) {
    switch (state) {
      case MerchantClaimWorkflowState.draft:
        return MerchantBadgeKey.claimDraft;
      case MerchantClaimWorkflowState.submitted:
        return MerchantBadgeKey.claimSubmitted;
      case MerchantClaimWorkflowState.underReview:
        return MerchantBadgeKey.claimUnderReview;
      case MerchantClaimWorkflowState.needsMoreInfo:
        return MerchantBadgeKey.claimNeedsMoreInfo;
      case MerchantClaimWorkflowState.approved:
        return MerchantBadgeKey.claimApproved;
      case MerchantClaimWorkflowState.rejected:
        return MerchantBadgeKey.claimRejected;
      case MerchantClaimWorkflowState.duplicateClaim:
        return MerchantBadgeKey.claimDuplicate;
      case MerchantClaimWorkflowState.conflictDetected:
        return MerchantBadgeKey.claimConflict;
      case null:
        return null;
    }
  }

  static MerchantBadgeKey? _resolvePrimaryOperationalBadge(
      MerchantVisualState state) {
    // Precedencia oficial:
    // vacation > temporary_closure > guardia > guardia_en_verificacion >
    // cambio_operativo > abierto_ahora > abre_mas_tarde > cerrado > info.
    if (state.operationalSignal == MerchantOperationalSignalState.vacation) {
      return MerchantBadgeKey.closedForVacation;
    }
    if (state.operationalSignal ==
        MerchantOperationalSignalState.temporaryClosure) {
      return MerchantBadgeKey.temporaryClosure;
    }
    if (state.guardState == MerchantPharmacyGuardState.guardVerification) {
      return MerchantBadgeKey.guardVerification;
    }
    if (state.guardState == MerchantPharmacyGuardState.onDuty) {
      return MerchantBadgeKey.onDuty;
    }
    if (state.guardState == MerchantPharmacyGuardState.guardOperationalChange) {
      return MerchantBadgeKey.operationalChange;
    }
    if (state.opening == MerchantOpeningState.openNow) {
      return MerchantBadgeKey.openNow;
    }
    if (state.operationalSignal == MerchantOperationalSignalState.opensLater) {
      return MerchantBadgeKey.opensLater;
    }
    if (state.opening == MerchantOpeningState.closed) {
      return MerchantBadgeKey.closed;
    }

    if (state.hasSufficientScheduleInfo) {
      return MerchantBadgeKey.referentialSchedule;
    }
    return MerchantBadgeKey.noInfo;
  }

  static MerchantBadgeKey? _confidenceBadge(
      MerchantConfidenceState confidence) {
    switch (confidence) {
      case MerchantConfidenceState.verified:
        return MerchantBadgeKey.confidenceVerified;
      case MerchantConfidenceState.validated:
        return MerchantBadgeKey.confidenceValidated;
      case MerchantConfidenceState.claimed:
        return MerchantBadgeKey.confidenceClaimed;
      case MerchantConfidenceState.communitySubmitted:
        return MerchantBadgeKey.confidenceCommunity;
      case MerchantConfidenceState.referential:
        return MerchantBadgeKey.confidenceReferential;
      case MerchantConfidenceState.unverified:
        return MerchantBadgeKey.confidenceUnverified;
    }
  }

  static List<MerchantBadgeKey> _resolveSecondaryBadges({
    required MerchantVisualState state,
    required MerchantSurface surface,
    required MerchantBadgeKey? primary,
    required MerchantBadgeKey? confidence,
  }) {
    final secondary = <MerchantBadgeKey>[];

    final allowsSecondaries = surface == MerchantSurface.detail ||
        surface == MerchantSurface.compactCard;
    if (!allowsSecondaries) {
      return const <MerchantBadgeKey>[];
    }

    final canShow24h = state.show24hBadge &&
        !state.twentyFourHourCooldownActive &&
        state.opening == MerchantOpeningState.openNow &&
        primary != MerchantBadgeKey.closedForVacation &&
        primary != MerchantBadgeKey.temporaryClosure &&
        primary != MerchantBadgeKey.opensLater;
    if (canShow24h) {
      secondary.add(MerchantBadgeKey.alwaysOpen24h);
    }

    if (surface == MerchantSurface.detail && confidence != null) {
      secondary.add(confidence);
    }

    final limit = surface == MerchantSurface.detail ? 2 : 1;
    return secondary.take(limit).toList(growable: false);
  }
}
