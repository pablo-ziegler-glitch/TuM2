import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tum2/modules/owner/models/merchant_product.dart';
import 'package:tum2/modules/owner/providers/product_providers.dart';
import 'package:tum2/modules/owner/repositories/product_repository.dart';

void main() {
  group('ProductMutationController', () {
    test('setStockStatus llama repositorio y limpia estado en éxito', () async {
      final repository = _MutationFakeRepository();
      final container = ProviderContainer(
        overrides: [
          productRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final product = _buildProduct();
      final success =
          await container.read(productMutationProvider.notifier).setStockStatus(
                product: product,
                stockStatus: ProductStockStatus.outOfStock,
                actorUserId: 'owner-1',
              );

      expect(success, isTrue);
      expect(repository.stockCalls, 1);
      expect(repository.lastStockStatus, ProductStockStatus.outOfStock);
      expect(
        container.read(productMutationProvider).stockInFlightIds,
        isEmpty,
      );
    });

    test('deactivate actualiza estado y expone error si falla', () async {
      final repository = _MutationFakeRepository(throwOnDeactivate: true);
      final container = ProviderContainer(
        overrides: [
          productRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final success =
          await container.read(productMutationProvider.notifier).deactivate(
                product: _buildProduct(),
                actorUserId: 'owner-1',
              );

      expect(success, isFalse);
      expect(repository.deactivateCalls, 1);
      expect(container.read(productMutationProvider).errorMessage, isNotNull);
    });

    test('setStockStatus evita cambios en productos ocultos', () async {
      final repository = _MutationFakeRepository();
      final container = ProviderContainer(
        overrides: [
          productRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final success =
          await container.read(productMutationProvider.notifier).setStockStatus(
                product: _buildProduct(
                  status: ProductStatus.inactive,
                ),
                stockStatus: ProductStockStatus.outOfStock,
                actorUserId: 'owner-1',
              );

      expect(success, isFalse);
      expect(repository.stockCalls, 0);
      expect(container.read(productMutationProvider).errorMessage, isNotNull);
    });
  });
}

class _MutationFakeRepository implements ProductRepository {
  _MutationFakeRepository({this.throwOnDeactivate = false});

  final bool throwOnDeactivate;
  int stockCalls = 0;
  int deactivateCalls = 0;
  ProductStockStatus? lastStockStatus;

  @override
  Future<ProductCreateResult> createProduct({
    required String merchantId,
    required String ownerUserId,
    required String actorUserId,
    required ProductDraftInput input,
    ProductImageUploadData? image,
  }) async {
    return const ProductCreateResult(productId: 'new-product');
  }

  @override
  Future<void> deactivateProduct({
    required MerchantProduct product,
    required String actorUserId,
  }) async {
    deactivateCalls += 1;
    if (throwOnDeactivate) {
      throw const ProductRepositoryException(
        code: 'forced-error',
        message: 'forced',
      );
    }
  }

  @override
  Future<List<MerchantProduct>> fetchPublicProducts({
    required String merchantId,
    int limit = 24,
  }) async {
    return const [];
  }

  @override
  Future<List<MerchantProduct>> fetchOwnerProducts({
    required String merchantId,
    int limit = 120,
  }) async {
    return const [];
  }

  @override
  Future<MerchantProduct?> getProductById(String productId) async {
    return null;
  }

  @override
  Future<void> setVisibilityStatus({
    required MerchantProduct product,
    required ProductVisibilityStatus visibilityStatus,
    required String actorUserId,
  }) async {
    // unused in tests
  }

  @override
  Future<void> setStockStatus({
    required MerchantProduct product,
    required ProductStockStatus stockStatus,
    required String actorUserId,
  }) async {
    stockCalls += 1;
    lastStockStatus = stockStatus;
  }

  @override
  Future<void> updateProduct({
    required MerchantProduct product,
    required String actorUserId,
    required ProductDraftInput input,
    ProductImageUploadData? newImage,
  }) async {}

  @override
  Future<ProductImageUploadResult> uploadProductImage({
    required String merchantId,
    required String productId,
    required ProductImageUploadData image,
    String? existingImagePath,
  }) async {
    return ProductImageUploadResult(
      downloadUrl: '',
      storagePath: '',
      sizeBytes: image.sizeBytes,
    );
  }

  @override
  Stream<MerchantProduct?> watchProductById(String productId) {
    return const Stream.empty();
  }

  @override
  Stream<List<MerchantProduct>> watchOwnerProducts({
    required String merchantId,
    int limit = 120,
  }) {
    return const Stream.empty();
  }

  @override
  Future<void> reactivateProduct({
    required MerchantProduct product,
    required String actorUserId,
  }) async {}
}

MerchantProduct _buildProduct({
  ProductVisibilityStatus visibilityStatus = ProductVisibilityStatus.visible,
  ProductStatus status = ProductStatus.active,
}) {
  return MerchantProduct(
    id: 'p-1',
    merchantId: 'm-1',
    ownerUserId: 'owner-1',
    name: 'Yerba',
    normalizedName: 'yerba',
    description: '',
    priceLabel: '\$2.500',
    priceMode: ProductPriceMode.fixed,
    stockStatus: ProductStockStatus.available,
    visibilityStatus: visibilityStatus,
    status: status,
    sourceType: 'owner_created',
    createdBy: 'owner-1',
    updatedBy: 'owner-1',
  );
}
