import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/catalog_capacity.dart';

class CatalogLimitsRepository {
  CatalogLimitsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<OwnerCatalogLimitsConfig> fetchCatalogLimitsConfig() async {
    final snapshot = await _firestore.doc('admin_configs/catalog_limits').get();
    if (!snapshot.exists) {
      return const OwnerCatalogLimitsConfig(
        defaultProductLimit: 100,
        categoryLimits: <String, int>{},
      );
    }

    return OwnerCatalogLimitsConfig.fromMap(snapshot.data() ?? const {});
  }
}
