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
  static const int _ownerMerchantQueryLimit = 10;

  Future<OwnerMerchantResolution> resolveOwnerMerchant(
    String ownerUserId, {
    String? preferredMerchantId,
  }) async {
    final normalizedPreferredId = preferredMerchantId?.trim();
    if (normalizedPreferredId != null && normalizedPreferredId.isNotEmpty) {
      final preferredDoc = await _firestore
          .collection('merchants')
          .doc(normalizedPreferredId)
          .get();
      if (preferredDoc.exists) {
        final preferredData = preferredDoc.data() ?? const <String, dynamic>{};
        final preferredOwnerUserId =
            (preferredData['ownerUserId'] as String?)?.trim();
        if (preferredOwnerUserId == ownerUserId) {
          final merchant = OwnerMerchantSummary.fromFirestore(
            preferredDoc.id,
            preferredData,
          );
          return OwnerMerchantResolution(
            primaryMerchant: merchant,
            allMerchants: [merchant],
          );
        }
      }
    }

    final snapshot = await _firestore
        .collection('merchants')
        .where('ownerUserId', isEqualTo: ownerUserId)
        .limit(_ownerMerchantQueryLimit)
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
    final byDate = bUpdated.compareTo(aUpdated);
    if (byDate != 0) return byDate;
    // Tie-break estable para evitar saltos de comercio primario entre sesiones.
    return a.id.compareTo(b.id);
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
