import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/product_repository.dart';
import '../../domain/product_model.dart';

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository();
});

/// Streams all visible products for a given store.
final storeProductsProvider =
    StreamProvider.family<List<ProductModel>, String>((ref, storeId) {
  return ref.watch(productRepositoryProvider).watchProducts(storeId);
});
