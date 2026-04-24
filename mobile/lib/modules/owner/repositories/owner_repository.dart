import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/owner_merchant_summary.dart';
import '../models/operational_signals.dart';
import 'owner_operational_signals_repository.dart';

/// Repositorio privado del módulo OWNER.
///
/// Resuelve el comercio asociado al usuario autenticado buscando en `merchants`
/// por `ownerUserId`. Nunca usa `merchant_public`.
class OwnerRepository {
  OwnerRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _operationalSignalsRepository = OwnerOperationalSignalsRepository(
          dataSource: FirestoreOwnerOperationalSignalsDataSource(
            firestore: firestore ?? FirebaseFirestore.instance,
          ),
        );

  final FirebaseFirestore _firestore;
  final OwnerOperationalSignalsRepository _operationalSignalsRepository;

  Future<OwnerMerchantResolution> resolveOwnerMerchant(
    String ownerUserId, {
    String? preferredMerchantId,
  }) async {
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

    final normalizedPreferredId = preferredMerchantId?.trim();
    OwnerMerchantSummary? preferred;
    if (normalizedPreferredId != null && normalizedPreferredId.isNotEmpty) {
      for (final merchant in merchants) {
        if (merchant.id == normalizedPreferredId) {
          preferred = merchant;
          break;
        }
      }
    }
    final primary = preferred ?? merchants.first;

    return OwnerMerchantResolution(
      primaryMerchant: primary,
      allMerchants: merchants,
    );
  }

  Future<OwnerOperationalSignal?> fetchOperationalSignal({
    required String merchantId,
  }) {
    return _operationalSignalsRepository.fetchSignal(merchantId: merchantId);
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

  Future<void> updateMerchantProfile({
    required String merchantId,
    required String razonSocial,
    required String nombreFantasia,
  }) async {
    final trimmedRazonSocial = razonSocial.trim();
    final trimmedNombreFantasia = nombreFantasia.trim();
    final visibleName = trimmedNombreFantasia.isNotEmpty
        ? trimmedNombreFantasia
        : trimmedRazonSocial;

    await _firestore.collection('merchants').doc(merchantId).update({
      'name': visibleName,
      'razonSocial': trimmedRazonSocial,
      'nombreFantasia': trimmedNombreFantasia,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
