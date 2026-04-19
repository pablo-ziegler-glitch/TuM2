import 'dart:typed_data';

enum MerchantClaimStatus {
  draft,
  submitted,
  underReview,
  needsMoreInfo,
  approved,
  rejected,
  duplicateClaim,
  conflictDetected,
}

enum MerchantClaimDeclaredRole {
  owner,
  coOwner,
  authorizedRepresentative,
}

enum MerchantClaimEvidenceKind {
  storefrontPhoto,
  ownershipDocument,
  regulatoryDocument,
  reinforcedRelationshipEvidence,
  operationalPointPhoto,
  alternativeRelationshipEvidence,
}

class MerchantClaimEvidenceUpload {
  const MerchantClaimEvidenceUpload({
    required this.id,
    required this.kind,
    required this.bytes,
    required this.contentType,
    required this.originalFileName,
  });

  final String id;
  final MerchantClaimEvidenceKind kind;
  final Uint8List bytes;
  final String contentType;
  final String originalFileName;
}

class MerchantClaimEvidenceFile {
  const MerchantClaimEvidenceFile({
    required this.id,
    required this.kind,
    required this.storagePath,
    required this.contentType,
    required this.sizeBytes,
    this.originalFileName,
  });

  final String id;
  final MerchantClaimEvidenceKind kind;
  final String storagePath;
  final String contentType;
  final int sizeBytes;
  final String? originalFileName;

  Map<String, dynamic> toPayload() {
    return {
      'id': id,
      'kind': kind.apiValue,
      'storagePath': storagePath,
      'contentType': contentType,
      'sizeBytes': sizeBytes,
      'originalFileName': originalFileName,
    };
  }
}

class ClaimableMerchantCandidate {
  const ClaimableMerchantCandidate({
    required this.merchantId,
    required this.name,
    required this.categoryId,
    required this.zoneId,
    required this.ownershipStatus,
    required this.hasOwner,
    this.address,
  });

  final String merchantId;
  final String name;
  final String categoryId;
  final String zoneId;
  final String ownershipStatus;
  final bool hasOwner;
  final String? address;

  bool get isConflictCandidate =>
      hasOwner || ownershipStatus.toLowerCase() == 'claimed';
}

class MerchantClaimStatusSummary {
  const MerchantClaimStatusSummary({
    required this.claimId,
    required this.claimStatus,
    required this.merchantId,
    required this.updatedAtMillis,
    required this.submittedAtMillis,
    required this.needsMoreInfo,
    required this.conflictDetected,
    required this.duplicateDetected,
    this.duplicateOfClaimId,
    this.conflictType,
    this.merchantName,
  });

  final String claimId;
  final MerchantClaimStatus claimStatus;
  final String merchantId;
  final String? merchantName;
  final int? updatedAtMillis;
  final int? submittedAtMillis;
  final bool needsMoreInfo;
  final bool conflictDetected;
  final bool duplicateDetected;
  final String? duplicateOfClaimId;
  final String? conflictType;
}

class MerchantClaimDraftInput {
  const MerchantClaimDraftInput({
    required this.merchantId,
    required this.declaredRole,
    required this.hasAcceptedDataProcessingConsent,
    required this.hasAcceptedLegitimacyDeclaration,
    required this.evidenceFiles,
    this.claimId,
    this.expectedUpdatedAtMillis,
    this.phone,
    this.claimantDisplayName,
    this.claimantNote,
  });

  final String? claimId;
  final int? expectedUpdatedAtMillis;
  final String merchantId;
  final MerchantClaimDeclaredRole declaredRole;
  final String? phone;
  final String? claimantDisplayName;
  final String? claimantNote;
  final bool hasAcceptedDataProcessingConsent;
  final bool hasAcceptedLegitimacyDeclaration;
  final List<MerchantClaimEvidenceFile> evidenceFiles;
}

extension MerchantClaimStatusX on MerchantClaimStatus {
  static MerchantClaimStatus fromApi(String raw) {
    switch (raw) {
      case 'draft':
        return MerchantClaimStatus.draft;
      case 'submitted':
        return MerchantClaimStatus.submitted;
      case 'under_review':
        return MerchantClaimStatus.underReview;
      case 'needs_more_info':
        return MerchantClaimStatus.needsMoreInfo;
      case 'approved':
        return MerchantClaimStatus.approved;
      case 'rejected':
        return MerchantClaimStatus.rejected;
      case 'duplicate_claim':
        return MerchantClaimStatus.duplicateClaim;
      case 'conflict_detected':
        return MerchantClaimStatus.conflictDetected;
      default:
        return MerchantClaimStatus.draft;
    }
  }

  String get apiValue {
    switch (this) {
      case MerchantClaimStatus.draft:
        return 'draft';
      case MerchantClaimStatus.submitted:
        return 'submitted';
      case MerchantClaimStatus.underReview:
        return 'under_review';
      case MerchantClaimStatus.needsMoreInfo:
        return 'needs_more_info';
      case MerchantClaimStatus.approved:
        return 'approved';
      case MerchantClaimStatus.rejected:
        return 'rejected';
      case MerchantClaimStatus.duplicateClaim:
        return 'duplicate_claim';
      case MerchantClaimStatus.conflictDetected:
        return 'conflict_detected';
    }
  }
}

extension MerchantClaimDeclaredRoleX on MerchantClaimDeclaredRole {
  String get apiValue {
    switch (this) {
      case MerchantClaimDeclaredRole.owner:
        return 'owner';
      case MerchantClaimDeclaredRole.coOwner:
        return 'co_owner';
      case MerchantClaimDeclaredRole.authorizedRepresentative:
        return 'authorized_representative';
    }
  }

  String get label {
    switch (this) {
      case MerchantClaimDeclaredRole.owner:
        return 'Dueño/a';
      case MerchantClaimDeclaredRole.coOwner:
        return 'Co-dueño/a';
      case MerchantClaimDeclaredRole.authorizedRepresentative:
        return 'Representante autorizado';
    }
  }
}

extension MerchantClaimEvidenceKindX on MerchantClaimEvidenceKind {
  String get apiValue {
    switch (this) {
      case MerchantClaimEvidenceKind.storefrontPhoto:
        return 'storefront_photo';
      case MerchantClaimEvidenceKind.ownershipDocument:
        return 'ownership_document';
      case MerchantClaimEvidenceKind.regulatoryDocument:
        return 'regulatory_document';
      case MerchantClaimEvidenceKind.reinforcedRelationshipEvidence:
        return 'reinforced_relationship_evidence';
      case MerchantClaimEvidenceKind.operationalPointPhoto:
        return 'operational_point_photo';
      case MerchantClaimEvidenceKind.alternativeRelationshipEvidence:
        return 'alternative_relationship_evidence';
    }
  }

  String get label {
    switch (this) {
      case MerchantClaimEvidenceKind.storefrontPhoto:
        return 'Foto de fachada';
      case MerchantClaimEvidenceKind.ownershipDocument:
        return 'Prueba de vínculo';
      case MerchantClaimEvidenceKind.regulatoryDocument:
        return 'Documento regulatorio';
      case MerchantClaimEvidenceKind.reinforcedRelationshipEvidence:
        return 'Evidencia reforzada';
      case MerchantClaimEvidenceKind.operationalPointPhoto:
        return 'Foto del puesto';
      case MerchantClaimEvidenceKind.alternativeRelationshipEvidence:
        return 'Vínculo alternativo';
    }
  }
}
