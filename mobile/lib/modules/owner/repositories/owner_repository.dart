import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/owner_merchant_summary.dart';

/// Repositorio privado del módulo OWNER.
///
/// Resuelve el comercio asociado al usuario autenticado buscando en `merchants`
/// por `ownerUserId`. Nunca usa `merchant_public`.
class OwnerRepository {
  OwnerRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<OwnerMerchantResolution> resolveOwnerMerchant(
      String ownerUserId) async {
    final snapshot = await _firestore
        .collection('merchants')
        .where('ownerUserId', isEqualTo: ownerUserId)
        .limit(10)
        .get();

    final merchants = snapshot.docs
        .map(
          (doc) => OwnerMerchantSummary.fromFirestore(
            doc.id,
            doc.data(),
          ),
        )
        .toList()
      ..sort(_sortByPriority);

    if (merchants.isEmpty) {
      return const OwnerMerchantResolution(
        primaryMerchant: null,
        allMerchants: [],
      );
    }

    return OwnerMerchantResolution(
      primaryMerchant: merchants.first,
      allMerchants: merchants,
    );
  }

  int _sortByPriority(OwnerMerchantSummary a, OwnerMerchantSummary b) {
    // Priorizar no archivados; luego por updatedAt/createdAt más reciente.
    if (a.isArchived != b.isArchived) {
      return a.isArchived ? 1 : -1;
    }

    final aUpdated = a.updatedAt ?? a.createdAt;
    final bUpdated = b.updatedAt ?? b.createdAt;
    if (aUpdated == null && bUpdated == null) return 0;
    if (aUpdated == null) return 1;
    if (bUpdated == null) return -1;
    return bUpdated.compareTo(aUpdated);
  }
}
