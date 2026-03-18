import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../domain/store_model.dart';

class StoreRepository {
  final FirebaseFirestore _db;
  static const _uuid = Uuid();

  StoreRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _db.collection('stores');

  /// Streams all active stores owned by [ownerId].
  Stream<List<StoreModel>> watchOwnerStores(String ownerId) {
    return _collection
        .where('ownerId', isEqualTo: ownerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => StoreModel.fromFirestore(doc)).toList());
  }

  /// Streams a single store by ID.
  Stream<StoreModel?> watchStore(String storeId) {
    return _collection.doc(storeId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return StoreModel.fromFirestore(snap);
    });
  }

  /// Fetches a single store by ID.
  Future<StoreModel?> getStore(String storeId) async {
    final snap = await _collection.doc(storeId).get();
    if (!snap.exists) return null;
    return StoreModel.fromFirestore(snap);
  }

  /// Fetches a store by its URL slug.
  Future<StoreModel?> getStoreBySlug(String slug) async {
    final snap = await _collection
        .where('slug', isEqualTo: slug)
        .where('visibilityStatus', isEqualTo: 'active')
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return StoreModel.fromFirestore(snap.docs.first);
  }

  /// Creates a new store document.
  Future<String> createStore(StoreModel store) async {
    final id = _uuid.v4();
    final data = store.toFirestore();
    data['id'] = id;
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _collection.doc(id).set(data);
    return id;
  }

  /// Updates specific fields on a store document.
  Future<void> updateStore(String storeId, Map<String, dynamic> fields) async {
    fields['updatedAt'] = FieldValue.serverTimestamp();
    await _collection.doc(storeId).update(fields);
  }

  /// Soft-deletes a store by setting visibilityStatus to 'suspended'.
  Future<void> archiveStore(String storeId) async {
    await _collection.doc(storeId).update({
      'visibilityStatus': 'suspended',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Re-activates a store.
  Future<void> activateStore(String storeId) async {
    await _collection.doc(storeId).update({
      'visibilityStatus': 'active',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
