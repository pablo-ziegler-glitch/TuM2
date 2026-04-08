import 'package:cloud_firestore/cloud_firestore.dart';

/// Resumen privado del comercio asociado al OWNER autenticado.
///
/// Fuente: colección `merchants` (nunca `merchant_public`).
class OwnerMerchantSummary {
  const OwnerMerchantSummary({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.zoneId,
    required this.address,
    required this.status,
    required this.visibilityStatus,
    required this.verificationStatus,
    required this.sourceType,
    required this.hasProducts,
    required this.hasSchedules,
    required this.hasOperationalSignals,
    required this.updatedAt,
    required this.createdAt,
    required this.isDataComplete,
  });

  final String id;
  final String name;
  final String categoryId;
  final String zoneId;
  final String address;
  final String status;
  final String visibilityStatus;
  final String verificationStatus;
  final String sourceType;
  final bool hasProducts;
  final bool hasSchedules;
  final bool hasOperationalSignals;
  final DateTime? updatedAt;
  final DateTime? createdAt;
  final bool isDataComplete;

  bool get isArchived => status == 'archived';
  bool get isDraft => status == 'draft';
  bool get isVisible => visibilityStatus == 'visible';
  bool get isReviewPending => visibilityStatus == 'review_pending';
  bool get isPharmacy {
    final value = categoryId.toLowerCase();
    return value.contains('farm');
  }

  String get locationLabel {
    if (address.isNotEmpty) return address;
    if (zoneId.isNotEmpty) return zoneId;
    return 'Ubicación sin definir';
  }

  factory OwnerMerchantSummary.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    final name = (data['name'] as String?)?.trim() ?? '';
    final categoryId = (data['categoryId'] as String?)?.trim() ??
        (data['category'] as String?)?.trim() ??
        '';
    final zoneId = (data['zoneId'] as String?)?.trim() ??
        (data['zone'] as String?)?.trim() ??
        '';
    final address = (data['address'] as String?)?.trim() ?? '';
    final status = (data['status'] as String?)?.trim().toLowerCase() ?? 'draft';
    final visibilityStatus =
        (data['visibilityStatus'] as String?)?.trim().toLowerCase() ?? 'hidden';
    final verificationStatus =
        (data['verificationStatus'] as String?)?.trim().toLowerCase() ??
            'unverified';
    final sourceType = (data['sourceType'] as String?)?.trim().toLowerCase() ??
        'owner_created';

    return OwnerMerchantSummary(
      id: id,
      name: name.isEmpty ? 'Comercio sin nombre' : name,
      categoryId: categoryId,
      zoneId: zoneId,
      address: address,
      status: status,
      visibilityStatus: visibilityStatus,
      verificationStatus: verificationStatus,
      sourceType: sourceType,
      hasProducts: data['hasProducts'] == true,
      hasSchedules: data['hasSchedules'] == true,
      hasOperationalSignals: data['hasOperationalSignals'] == true,
      updatedAt: _parseTimestamp(data['updatedAt']),
      createdAt: _parseTimestamp(data['createdAt']),
      isDataComplete: name.isNotEmpty,
    );
  }

  static DateTime? _parseTimestamp(Object? raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return null;
  }
}

/// Resultado de resolución de `merchants` para un owner autenticado.
class OwnerMerchantResolution {
  const OwnerMerchantResolution({
    required this.primaryMerchant,
    required this.allMerchants,
  });

  final OwnerMerchantSummary? primaryMerchant;
  final List<OwnerMerchantSummary> allMerchants;

  bool get hasMerchant => primaryMerchant != null;
  bool get hasMultipleMerchants => allMerchants.length > 1;
}
