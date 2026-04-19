import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tum2/modules/owner/models/merchant_product.dart';
import 'package:tum2/modules/owner/repositories/product_repository.dart';
import 'package:tum2/modules/owner/screens/product_form_controller.dart';

void main() {
  group('ProductFormNotifier', () {
    test('carga producto inicial en modo edición', () async {
      final repository = _FakeProductRepository(
        initialProducts: {
          'p-1': _buildProduct(id: 'p-1'),
        },
      );
      final notifier = ProductFormNotifier(
        repository: repository,
        scope: const ProductFormScope(
          merchantId: 'm-1',
          ownerUserId: 'owner-1',
          productId: 'p-1',
        ),
      );

      await _waitForLoaded(notifier);

      expect(notifier.state.isEditing, isTrue);
      expect(notifier.state.name, 'Ibuprofeno');
      expect(notifier.state.priceLabel, '\$2.500');
      expect(notifier.state.visibilityStatus, ProductVisibilityStatus.visible);
    });

    test('valida campos requeridos antes de guardar', () async {
      final repository = _FakeProductRepository();
      final notifier = ProductFormNotifier(
        repository: repository,
        scope: const ProductFormScope(
          merchantId: 'm-1',
          ownerUserId: 'owner-1',
        ),
      );

      notifier.setName(' ');
      notifier.setPriceLabel('');

      final result = await notifier.submit(actorUserId: 'owner-1');

      expect(result.success, isFalse);
      expect(notifier.state.nameError, isNotNull);
      expect(notifier.state.priceLabelError, isNotNull);
      expect(repository.createCalls, 0);
    });

    test('crea producto en modo alta', () async {
      final repository = _FakeProductRepository();
      final notifier = ProductFormNotifier(
        repository: repository,
        scope: const ProductFormScope(
          merchantId: 'm-1',
          ownerUserId: 'owner-1',
        ),
      );

      notifier.setName('Yerba Mate');
      notifier.setPriceLabel('Consultar');
      notifier.setVisibilityStatus(ProductVisibilityStatus.hidden);

      final result = await notifier.submit(actorUserId: 'owner-1');

      expect(result.success, isTrue);
      expect(result.isCreate, isTrue);
      expect(repository.createCalls, 1);
      expect(notifier.state.submitStatus, ProductFormSubmitStatus.success);
    });

    test('edita producto existente con imagen nueva', () async {
      final repository = _FakeProductRepository(
        initialProducts: {
          'p-1': _buildProduct(id: 'p-1'),
        },
      );
      final notifier = ProductFormNotifier(
        repository: repository,
        scope: const ProductFormScope(
          merchantId: 'm-1',
          ownerUserId: 'owner-1',
          productId: 'p-1',
        ),
      );
      await _waitForLoaded(notifier);

      notifier.setName('Ibuprofeno Plus');
      notifier.setPriceLabel('\$3.000');
      notifier.setLocalImage(
        ProductImageUploadData(
          bytes: Uint8List.fromList(const [1, 2, 3]),
          contentType: 'image/jpeg',
          fileName: 'cover.jpg',
        ),
      );

      final result = await notifier.submit(actorUserId: 'owner-1');

      expect(result.success, isTrue);
      expect(result.isCreate, isFalse);
      expect(repository.updateCalls, 1);
      expect(repository.lastUpdatedProductId, 'p-1');
      expect(repository.lastUpdatedImage?.sizeBytes, 3);
    });

    test('marca error de imagen cuando supera el límite', () {
      final repository = _FakeProductRepository();
      final notifier = ProductFormNotifier(
        repository: repository,
        scope: const ProductFormScope(
          merchantId: 'm-1',
          ownerUserId: 'owner-1',
        ),
      );

      notifier.setLocalImage(
        ProductImageUploadData(
          bytes: Uint8List(productImageMaxBytes + 1),
          contentType: 'image/jpeg',
          fileName: 'large.jpg',
        ),
      );

      expect(notifier.state.imageError, contains('imagen más liviana'));
      expect(notifier.state.localImage, isNull);
    });
  });
}

Future<void> _waitForLoaded(ProductFormNotifier notifier) async {
  for (var i = 0; i < 20; i++) {
    if (!notifier.state.isInitialLoading) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

MerchantProduct _buildProduct({required String id}) {
  return MerchantProduct(
    id: id,
    merchantId: 'm-1',
    ownerUserId: 'owner-1',
    name: 'Ibuprofeno',
    normalizedName: 'ibuprofeno',
    priceLabel: '\$2.500',
    stockStatus: ProductStockStatus.available,
    visibilityStatus: ProductVisibilityStatus.visible,
    status: ProductStatus.active,
    sourceType: 'owner_created',
    createdBy: 'owner-1',
    updatedBy: 'owner-1',
    imageUrl: null,
    imagePath: null,
  );
}

class _FakeProductRepository implements ProductRepository {
  _FakeProductRepository({
    Map<String, MerchantProduct>? initialProducts,
  }) : _products = initialProducts ?? {};

  final Map<String, MerchantProduct> _products;
  int createCalls = 0;
  int updateCalls = 0;
  String? lastUpdatedProductId;
  ProductImageUploadData? lastUpdatedImage;

  @override
  Future<String> createProduct({
    required String merchantId,
    required String ownerUserId,
    required String actorUserId,
    required ProductDraftInput input,
    ProductImageUploadData? image,
  }) async {
    createCalls += 1;
    final id = 'created-$createCalls';
    _products[id] = MerchantProduct(
      id: id,
      merchantId: merchantId,
      ownerUserId: ownerUserId,
      name: input.name,
      normalizedName: normalizeProductName(input.name),
      priceLabel: input.priceLabel,
      stockStatus: input.stockStatus,
      visibilityStatus: input.visibilityStatus,
      status: input.status,
      sourceType: 'owner_created',
      createdBy: actorUserId,
      updatedBy: actorUserId,
      imageUrl: null,
      imagePath: null,
    );
    return id;
  }

  @override
  Future<void> deactivateProduct({
    required MerchantProduct product,
    required String actorUserId,
  }) async {}

  @override
  Future<List<MerchantProduct>> fetchPublicProducts({
    required String merchantId,
    int limit = 24,
  }) async {
    return _products.values
        .where((item) => item.merchantId == merchantId)
        .take(limit)
        .toList();
  }

  @override
  Future<List<MerchantProduct>> fetchOwnerProducts({
    required String merchantId,
    int limit = 120,
  }) async {
    return _products.values
        .where((item) => item.merchantId == merchantId)
        .take(limit)
        .toList();
  }

  @override
  Future<MerchantProduct?> getProductById(String productId) async {
    return _products[productId];
  }

  @override
  Future<void> setVisibilityStatus({
    required MerchantProduct product,
    required ProductVisibilityStatus visibilityStatus,
    required String actorUserId,
  }) async {}

  @override
  Future<void> updateProduct({
    required MerchantProduct product,
    required String actorUserId,
    required ProductDraftInput input,
    ProductImageUploadData? newImage,
  }) async {
    updateCalls += 1;
    lastUpdatedProductId = product.id;
    lastUpdatedImage = newImage;
    _products[product.id] = product.copyWith(
      name: input.name,
      normalizedName: normalizeProductName(input.name),
      priceLabel: input.priceLabel,
      stockStatus: input.stockStatus,
      visibilityStatus: input.visibilityStatus,
      status: input.status,
      updatedBy: actorUserId,
    );
  }

  @override
  Future<ProductImageUploadResult> uploadProductImage({
    required String merchantId,
    required String productId,
    required ProductImageUploadData image,
    String? existingImagePath,
  }) async {
    return ProductImageUploadResult(
      downloadUrl: 'https://example.com/$productId.jpg',
      storagePath: 'merchant-products/$merchantId/$productId/cover.jpg',
      sizeBytes: image.sizeBytes,
    );
  }

  @override
  Stream<MerchantProduct?> watchProductById(String productId) {
    return Stream.value(_products[productId]);
  }

  @override
  Stream<List<MerchantProduct>> watchOwnerProducts({
    required String merchantId,
    int limit = 120,
  }) {
    return Stream.value(
      _products.values.where((item) => item.merchantId == merchantId).toList(),
    );
  }
}
