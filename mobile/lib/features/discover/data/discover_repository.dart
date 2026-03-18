import 'package:cloud_firestore/cloud_firestore.dart';

import '../../store/domain/store_model.dart';
import '../domain/discover_filters.dart';

class DiscoverRepository {
  final FirebaseFirestore _db;

  DiscoverRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  /// Returns a stream of stores matching the given filters.
  Stream<List<StoreModel>> watchStores(DiscoverFilters filters) {
    Query<Map<String, dynamic>> query = _db
        .collection('stores')
        .where('visibilityStatus', isEqualTo: 'active');

    // Apply filters
    if (filters.openNow) {
      query = query.where('isOpenNow', isEqualTo: true);
    }
    if (filters.onDutyToday) {
      query = query.where('isOnDutyToday', isEqualTo: true);
    }
    if (filters.lateNight) {
      query = query.where('isLateNightNow', isEqualTo: true);
    }
    if (filters.category != null) {
      query = query.where('category', isEqualTo: filters.category);
    }
    if (filters.locality != null) {
      query = query.where('locality', isEqualTo: filters.locality);
    }

    query = query.orderBy('updatedAt', descending: true).limit(50);

    return query.snapshots().map((snap) {
      var stores =
          snap.docs.map((doc) => StoreModel.fromFirestore(doc)).toList();

      // Client-side text filtering
      if (filters.searchQuery.isNotEmpty) {
        final q = filters.searchQuery.toLowerCase();
        stores = stores
            .where((s) =>
                s.name.toLowerCase().contains(q) ||
                s.category.toLowerCase().contains(q) ||
                s.locality.toLowerCase().contains(q))
            .toList();
      }

      return stores;
    });
  }

  /// Searches stores by name prefix.
  Future<List<StoreModel>> searchByName(String query) async {
    if (query.isEmpty) return [];

    final snap = await _db
        .collection('stores')
        .where('visibilityStatus', isEqualTo: 'active')
        .limit(20)
        .get();

    final q = query.toLowerCase();
    return snap.docs
        .map((doc) => StoreModel.fromFirestore(doc))
        .where((s) =>
            s.name.toLowerCase().contains(q) ||
            s.category.toLowerCase().contains(q))
        .toList();
  }
}
