import 'package:cloud_firestore/cloud_firestore.dart';

class MerchantDetailRepository {
  MerchantDetailRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<Map<String, dynamic>?> fetchMerchantDetail(String merchantId) async {
    final snapshot = await _firestore.doc('merchant_public/$merchantId').get();

    if (!snapshot.exists) {
      return null;
    }

    final data = snapshot.data();
    if (data == null) {
      return null;
    }

    final visibilityStatus = data['visibilityStatus'] as String? ?? '';
    const allowedStatuses = {'visible', 'review_pending'};
    if (!allowedStatuses.contains(visibilityStatus)) {
      return null;
    }

    return data;
  }
}
