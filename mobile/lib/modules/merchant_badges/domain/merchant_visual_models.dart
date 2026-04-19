enum MerchantSurface {
  searchCard,
  detail,
  compactCard,
  mapMarker,
  ownerPanel,
  claimStatus,
  pharmacyPublic,
}

enum MerchantVisibilityState {
  visible,
  reviewPending,
  hidden,
  suppressed,
}

enum MerchantLifecycleState {
  active,
  inactive,
  draft,
  archived,
}

enum MerchantConfidenceState {
  verified,
  validated,
  claimed,
  communitySubmitted,
  referential,
  unverified,
}

enum MerchantOpeningState {
  openNow,
  closed,
  noInfo,
}

enum MerchantPharmacyGuardState {
  none,
  onDuty,
  guardVerification,
  guardOperationalChange,
}

enum MerchantOperationalSignalState {
  none,
  vacation,
  temporaryClosure,
  opensLater,
}

enum MerchantClaimWorkflowState {
  draft,
  submitted,
  underReview,
  needsMoreInfo,
  approved,
  rejected,
  duplicateClaim,
  conflictDetected,
}

enum MerchantBadgeKey {
  closedForVacation,
  temporaryClosure,
  onDuty,
  guardVerification,
  operationalChange,
  opensLater,
  openNow,
  openCompact,
  closed,
  alwaysOpen24h,
  referentialSchedule,
  noInfo,
  confidenceVerified,
  confidenceValidated,
  confidenceClaimed,
  confidenceCommunity,
  confidenceReferential,
  confidenceUnverified,
  ownerVisible,
  ownerReviewPending,
  ownerSuppressed,
  ownerHidden,
  ownerActive,
  ownerDraft,
  ownerInactive,
  ownerArchived,
  claimDraft,
  claimSubmitted,
  claimUnderReview,
  claimNeedsMoreInfo,
  claimApproved,
  claimRejected,
  claimDuplicate,
  claimConflict,
}

class MerchantVisualState {
  const MerchantVisualState({
    required this.visibility,
    required this.lifecycle,
    required this.confidence,
    required this.opening,
    required this.guardState,
    required this.operationalSignal,
    required this.show24hBadge,
    required this.twentyFourHourCooldownActive,
    required this.categoryLabel,
    required this.claimState,
    required this.hasSufficientScheduleInfo,
    required this.manualOverrideMode,
    required this.informational,
  });

  final MerchantVisibilityState visibility;
  final MerchantLifecycleState lifecycle;
  final MerchantConfidenceState confidence;
  final MerchantOpeningState opening;
  final MerchantPharmacyGuardState guardState;
  final MerchantOperationalSignalState operationalSignal;
  final bool show24hBadge;
  final bool twentyFourHourCooldownActive;
  final String? categoryLabel;
  final MerchantClaimWorkflowState? claimState;
  final bool hasSufficientScheduleInfo;
  final String manualOverrideMode;
  final bool informational;
}

class BadgeResolution {
  const BadgeResolution({
    required this.primary,
    required this.secondary,
    required this.rubricLabel,
    required this.confidence,
  });

  final MerchantBadgeKey? primary;
  final List<MerchantBadgeKey> secondary;
  final String? rubricLabel;
  final MerchantBadgeKey? confidence;
}
