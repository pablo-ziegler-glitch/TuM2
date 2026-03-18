import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

import '../domain/product_model.dart';

class ProductRepository {
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;
  static const _uuid = Uuid();

  ProductRepository({FirebaseFirestore? db, FirebaseStorage? storage})
      : _db = db ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> _productsCollection(
          String storeId) =>
      _db.collection('stores').doc(storeId).collection('products');

  /// Streams all visible products for a store.
  Stream<List<ProductModel>> watchProducts(String storeId) {
    return _productsCollection(storeId)
        .where('isVisible', isEqualTo: true)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => ProductModel.fromFirestore(doc)).toList());
  }

  /// Creates a new product.
  Future<String> createProduct(ProductModel product) async {
    final id = _uuid.v4();
    final data = product.toFirestore();
    data['id'] = id;
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _productsCollection(product.storeId).doc(id).set(data);
    return id;
  }

  /// Updates a product.
  Future<void> updateProduct(
      String storeId, String productId, Map<String, dynamic> fields) async {
    fields['updatedAt'] = FieldValue.serverTimestamp();
    await _productsCollection(storeId).doc(productId).update(fields);
  }

  /// Soft-deletes a product by setting isVisible to false.
  Future<void> hideProduct(String storeId, String productId) async {
    await _productsCollection(storeId).doc(productId).update({
      'isVisible': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Uploads a product image to Firebase Storage and returns the download URL.
  Future<String> uploadProductImage({
    required String ownerId,
    required String storeId,
    required String productId,
    required File imageFile,
  }) async {
    final ref = _storage.ref(
        'productImages/$ownerId/$storeId/$productId/${_uuid.v4()}.jpg');
    await ref.putFile(imageFile);
    return ref.getDownloadURL();
  }
}
