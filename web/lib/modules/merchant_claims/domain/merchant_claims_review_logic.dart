import '../data/merchant_claims_admin_repository.dart';

enum MerchantClaimsSortOption {
  newestFirst,
  oldestPendingFirst,
  conflictFirst,
  pendingActionFirst,
  riskFirst,
}

class MerchantClaimsLocalFilters {
  const MerchantClaimsLocalFilters({
    this.query = '',
    this.categoryId,
    this.conflictOnly = false,
    this.missingInfoOnly = false,
    this.existingOwnerOnly = false,
    this.duplicateOnly = false,
    this.observedOnly = false,
    this.pendingOnly = false,
    this.dateFromMillis,
    this.dateToMillis,
    this.sort = MerchantClaimsSortOption.pendingActionFirst,
  });

  final String query;
  final String? categoryId;
  final bool conflictOnly;
  final bool missingInfoOnly;
  final bool existingOwnerOnly;
  final bool duplicateOnly;
  final bool observedOnly;
  final bool pendingOnly;
  final int? dateFromMillis;
  final int? dateToMillis;
  final MerchantClaimsSortOption sort;

  MerchantClaimsLocalFilters copyWith({
    String? query,
    String? categoryId,
    bool? conflictOnly,
    bool? missingInfoOnly,
    bool? existingOwnerOnly,
    bool? duplicateOnly,
    bool? observedOnly,
    bool? pendingOnly,
    int? dateFromMillis,
    int? dateToMillis,
    MerchantClaimsSortOption? sort,
    bool clearCategory = false,
    bool clearDateFrom = false,
    bool clearDateTo = false,
  }) {
    return MerchantClaimsLocalFilters(
      query: query ?? this.query,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      conflictOnly: conflictOnly ?? this.conflictOnly,
      missingInfoOnly: missingInfoOnly ?? this.missingInfoOnly,
      existingOwnerOnly: existingOwnerOnly ?? this.existingOwnerOnly,
      duplicateOnly: duplicateOnly ?? this.duplicateOnly,
      observedOnly: observedOnly ?? this.observedOnly,
      pendingOnly: pendingOnly ?? this.pendingOnly,
      dateFromMillis:
          clearDateFrom ? null : (dateFromMillis ?? this.dateFromMillis),
      dateToMillis: clearDateTo ? null : (dateToMillis ?? this.dateToMillis),
      sort: sort ?? this.sort,
    );
  }
}

List<MerchantClaimReviewItem> applyMerchantClaimLocalFilters({
  required List<MerchantClaimReviewItem> items,
  required MerchantClaimsLocalFilters filters,
}) {
  final query = filters.query.trim().toLowerCase();
  final filtered = items.where((item) {
    if (query.isNotEmpty) {
      final merchantName = (item.merchantName ?? '').toLowerCase();
      final matches = item.claimId.toLowerCase().contains(query) ||
          merchantName.contains(query) ||
          item.zoneId.toLowerCase().contains(query);
      if (!matches) return false;
    }

    if (filters.categoryId != null &&
        filters.categoryId!.trim().isNotEmpty &&
        item.categoryId != filters.categoryId) {
      return false;
    }

    if (filters.conflictOnly && !item.hasConflict) return false;
    if (filters.duplicateOnly && !item.hasDuplicate) return false;
    if (filters.observedOnly && item.autoValidationReasons.isEmpty)
      return false;
    if (filters.pendingOnly && !_isPendingStatus(item.claimStatus))
      return false;

    if (filters.missingInfoOnly &&
        item.claimStatus != MerchantClaimStatus.needsMoreInfo &&
        !item.autoValidationReasons.any(_isMissingInfoReason)) {
      return false;
    }

    if (filters.existingOwnerOnly &&
        !item.autoValidationReasons.contains('existing_owner_conflict')) {
      return false;
    }

    final createdAt = item.createdAtMillis ?? 0;
    if (filters.dateFromMillis != null && createdAt < filters.dateFromMillis!) {
      return false;
    }
    if (filters.dateToMillis != null && createdAt > filters.dateToMillis!) {
      return false;
    }

    return true;
  }).toList(growable: false);

  filtered.sort((left, right) => _compareClaims(left, right, filters.sort));
  return filtered;
}

bool isClaimDetailStale({
  required int? openedUpdatedAtMillis,
  required int? currentUpdatedAtMillis,
}) {
  if (openedUpdatedAtMillis == null || currentUpdatedAtMillis == null)
    return false;
  return openedUpdatedAtMillis != currentUpdatedAtMillis;
}

bool canResolveClaimStatus(
  MerchantClaimDetail detail,
  MerchantClaimStatus targetStatus,
) {
  if (!detail.canTakeAction) return false;
  return detail.allowedStatuses.contains(targetStatus);
}

bool shouldRequireReasonCode(MerchantClaimStatus status) {
  return status == MerchantClaimStatus.rejected ||
      status == MerchantClaimStatus.needsMoreInfo ||
      status == MerchantClaimStatus.conflictDetected ||
      status == MerchantClaimStatus.duplicateClaim;
}

bool _isPendingStatus(MerchantClaimStatus status) {
  return status == MerchantClaimStatus.submitted ||
      status == MerchantClaimStatus.underReview ||
      status == MerchantClaimStatus.needsMoreInfo ||
      status == MerchantClaimStatus.conflictDetected ||
      status == MerchantClaimStatus.duplicateClaim;
}

bool _isMissingInfoReason(String value) {
  return value.startsWith('missing_');
}

int _compareClaims(
  MerchantClaimReviewItem left,
  MerchantClaimReviewItem right,
  MerchantClaimsSortOption sort,
) {
  switch (sort) {
    case MerchantClaimsSortOption.newestFirst:
      return _compareDesc(left.createdAtMillis, right.createdAtMillis);
    case MerchantClaimsSortOption.oldestPendingFirst:
      return _compareAsc(left.createdAtMillis, right.createdAtMillis);
    case MerchantClaimsSortOption.conflictFirst:
      return _compareBool(right.hasConflict, left.hasConflict) != 0
          ? _compareBool(right.hasConflict, left.hasConflict)
          : _compareDesc(left.createdAtMillis, right.createdAtMillis);
    case MerchantClaimsSortOption.pendingActionFirst:
      final leftNeedsAction = _isPendingStatus(left.claimStatus);
      final rightNeedsAction = _isPendingStatus(right.claimStatus);
      return _compareBool(rightNeedsAction, leftNeedsAction) != 0
          ? _compareBool(rightNeedsAction, leftNeedsAction)
          : _compareDesc(left.createdAtMillis, right.createdAtMillis);
    case MerchantClaimsSortOption.riskFirst:
      final riskCompare = _compareRisk(left.riskPriority, right.riskPriority);
      return riskCompare != 0
          ? riskCompare
          : _compareDesc(left.createdAtMillis, right.createdAtMillis);
  }
}

int _compareRisk(String? left, String? right) {
  const weights = {'critical': 4, 'high': 3, 'medium': 2, 'low': 1};
  return (weights[right] ?? 0).compareTo(weights[left] ?? 0);
}

int _compareDesc(int? left, int? right) => (right ?? 0).compareTo(left ?? 0);

int _compareAsc(int? left, int? right) => (left ?? 0).compareTo(right ?? 0);

int _compareBool(bool left, bool right) => left == right ? 0 : (left ? 1 : -1);
