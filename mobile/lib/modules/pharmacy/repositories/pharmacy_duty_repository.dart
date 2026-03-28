import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/pharmacy_duty_item.dart';
import '../services/distance_calculator.dart';

/// Repositorio de turnos de farmacia.
///
/// Solo lectura: esta vista no escribe en Firestore.
///
/// Flujo de datos:
///   1. Query pharmacy_duties: zoneId + date (hoy en AR) + status='published'
///   2. Dedup por merchantId (evita mostrar el mismo merchant dos veces si hay datos duplicados)
///   3. Batch-get merchant_public para los merchantIds resultantes
///   4. Combinar ambos documentos en [PharmacyDutyItem]
///   5. Filtrar silenciosamente entradas sin merchant_public (dato huérfano)
class PharmacyDutyRepository {
  final FirebaseFirestore _firestore;

  static const Duration _queryTimeout = Duration(seconds: 5);

  PharmacyDutyRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Retorna los turnos publicados para [zoneId] en la fecha de hoy (timezone Argentina).
  ///
  /// Lanza [TimeoutException] si Firestore no responde en 5 segundos.
  /// Lanza [FirebaseException] si hay un error de Firestore subyacente.
  Future<List<PharmacyDutyItem>> getDutiesForZone(String zoneId) async {
    final today = todayArgentina();

    // 1. Query principal
    final dutiesSnap = await _firestore
        .collection('pharmacy_duties')
        .where('zoneId', isEqualTo: zoneId)
        .where('date', isEqualTo: today)
        .where('status', isEqualTo: 'published')
        .get()
        .timeout(_queryTimeout);

    if (dutiesSnap.docs.isEmpty) return [];

    // 2. Dedup por merchantId (tomar el primer turno de cada merchant)
    final seen = <String>{};
    final dedupedDuties = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (final doc in dutiesSnap.docs) {
      final merchantId = doc.data()['merchantId'] as String?;
      if (merchantId == null || merchantId.isEmpty) continue;
      if (seen.add(merchantId)) {
        dedupedDuties.add(doc);
      }
    }

    if (dedupedDuties.isEmpty) return [];

    // 3. Batch-get merchant_public en paralelo (N ≤ 5 para zona piloto)
    final merchantIds = dedupedDuties.map((d) => d.data()['merchantId'] as String).toList();
    final merchantFutures = merchantIds.map((id) =>
        _firestore.doc('merchant_public/$id').get().timeout(_queryTimeout));
    final merchantSnaps = await Future.wait(merchantFutures);

    // 4. Mapear a PharmacyDutyItem, filtrar huérfanos silenciosamente
    final items = <PharmacyDutyItem>[];
    for (var i = 0; i < dedupedDuties.length; i++) {
      final dutyDoc = dedupedDuties[i];
      final merchantDoc = merchantSnaps[i];

      if (!merchantDoc.exists) {
        // Dato huérfano: pharmacy_duty sin merchant_public correspondiente.
        // Se descarta silenciosamente para no romper la lista.
        continue;
      }

      items.add(PharmacyDutyItem.fromFirestore(
        dutyId: dutyDoc.id,
        dutyData: dutyDoc.data(),
        merchantData: merchantDoc.data()!,
      ));
    }

    return items;
  }
}
