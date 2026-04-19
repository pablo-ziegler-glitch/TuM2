import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/merchant_product.dart';
import 'product_repository.dart';

class FirebaseProductRepository implements ProductRepository {
  FirebaseProductRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  static const String _productsCollection = 'merchant_products';
  static const int _maxImageBytes = 5 * 1024 * 1024;
  static const int _maxPublicProductsLimit = 60;
  static const int _maxOwnerProductsLimit = 180;
  static const Duration _callableTimeout = Duration(seconds: 10);

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseFunctions _functions;

  @override
  Stream<List<MerchantProduct>> watchOwnerProducts({
    required String merchantId,
    int limit = 120,
  }) {
    final normalizedMerchantId = normalizeProductField(merchantId);
    if (normalizedMerchantId.isEmpty) return const Stream.empty();
    final safeLimit = limit.clamp(1, _maxOwnerProductsLimit).toInt();

    return _firestore
        .collection(_productsCollection)
        .where('merchantId', isEqualTo: normalizedMerchantId)
        .orderBy('updatedAt', descending: true)
        .limit(safeLimit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map(MerchantProduct.fromFirestore)
          .toList(growable: false);
    });
  }

  @override
  Future<List<MerchantProduct>> fetchOwnerProducts({
    required String merchantId,
    int limit = 120,
  }) async {
    final normalizedMerchantId = normalizeProductField(merchantId);
    if (normalizedMerchantId.isEmpty) return const [];
    final safeLimit = limit.clamp(1, _maxOwnerProductsLimit).toInt();

    try {
      final snapshot = await _firestore
          .collection(_productsCollection)
          .where('merchantId', isEqualTo: normalizedMerchantId)
          .orderBy('updatedAt', descending: true)
          .limit(safeLimit)
          .get();

      return snapshot.docs
          .map(MerchantProduct.fromFirestore)
          .toList(growable: false);
    } on FirebaseException catch (error) {
      throw _mapFirestoreException(error);
    } catch (error) {
      throw ProductRepositoryException(
        code: 'product-owner-read-failed',
        message: 'No pudimos cargar el catálogo del comercio.',
        cause: error,
      );
    }
  }

  @override
  Stream<MerchantProduct?> watchProductById(String productId) {
    final normalizedProductId = normalizeProductField(productId);
    if (normalizedProductId.isEmpty) return Stream.value(null);
    return _firestore
        .collection(_productsCollection)
        .doc(normalizedProductId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;
      return MerchantProduct.fromFirestore(snapshot);
    });
  }

  @override
  Future<MerchantProduct?> getProductById(String productId) async {
    final normalizedProductId = normalizeProductField(productId);
    if (normalizedProductId.isEmpty) return null;
    try {
      final snapshot = await _firestore
          .collection(_productsCollection)
          .doc(normalizedProductId)
          .get();
      if (!snapshot.exists) return null;
      return MerchantProduct.fromFirestore(snapshot);
    } on FirebaseException catch (error) {
      throw _mapFirestoreException(error);
    } catch (error) {
      throw ProductRepositoryException(
        code: 'product-read-failed',
        message: 'No pudimos cargar el producto.',
        cause: error,
      );
    }
  }

  @override
  Future<String> createProduct({
    required String merchantId,
    required String ownerUserId,
    required String actorUserId,
    required ProductDraftInput input,
    ProductImageUploadData? image,
  }) async {
    final normalizedMerchantId = normalizeProductField(merchantId);
    final normalizedOwnerUserId = normalizeProductField(ownerUserId);
    final normalizedActorUserId = normalizeProductField(actorUserId);

    if (normalizedMerchantId.isEmpty ||
        normalizedOwnerUserId.isEmpty ||
        normalizedActorUserId.isEmpty) {
      throw const ProductUnauthorizedException();
    }

    _validateInput(input);

    final productId = _firestore.collection(_productsCollection).doc().id;
    ProductImageUploadResult? imageResult;

    try {
      if (image != null) {
        imageResult = await uploadProductImage(
          merchantId: normalizedMerchantId,
          productId: productId,
          image: image,
        );
      }

      final createdProductId = await _callCreateProductCallable(
        merchantId: normalizedMerchantId,
        productId: productId,
        name: normalizeProductField(input.name),
        priceLabel: normalizeProductField(input.priceLabel),
        stockStatus: input.stockStatus,
        visibilityStatus: input.visibilityStatus,
        status: input.status,
        imageResult: imageResult,
      );
      return createdProductId;
    } on FirebaseFunctionsException catch (error) {
      if (imageResult != null) {
        await _safeDeleteStorageObject(imageResult.storagePath);
      }
      throw _mapFunctionsException(error);
    } on FirebaseException catch (error) {
      if (imageResult != null) {
        await _safeDeleteStorageObject(imageResult.storagePath);
      }
      throw _mapFirebaseException(error);
    } on ProductRepositoryException {
      rethrow;
    } on TimeoutException catch (error) {
      throw ProductRepositoryException(
        code: 'product-create-timeout',
        message:
            'La creación está tardando más de lo esperado. Verificá el catálogo antes de reintentar.',
        cause: error,
      );
    } catch (error) {
      if (imageResult != null) {
        await _safeDeleteStorageObject(imageResult.storagePath);
      }
      throw ProductRepositoryException(
        code: 'product-create-failed',
        message:
            'No pudimos guardar el producto. Revisá tu conexión y reintentá.',
        cause: error,
      );
    }
  }

  @override
  Future<void> updateProduct({
    required MerchantProduct product,
    required String actorUserId,
    required ProductDraftInput input,
    ProductImageUploadData? newImage,
  }) async {
    _validateInput(input);
    _assertActorMatchesProductOwner(product: product, actorUserId: actorUserId);

    ProductImageUploadResult? uploadedImage;
    try {
      if (newImage != null) {
        uploadedImage = await uploadProductImage(
          merchantId: product.merchantId,
          productId: product.id,
          image: newImage,
          existingImagePath: product.imagePath,
        );
      }

      final normalizedName = normalizeProductName(input.name);
      final payload = <String, dynamic>{
        'name': normalizeProductField(input.name),
        'normalizedName': normalizedName,
        'searchKeywords': buildProductSearchKeywords(input.name),
        'priceLabel': normalizeProductField(input.priceLabel),
        'stockStatus': input.stockStatus.value,
        'visibilityStatus': input.visibilityStatus.value,
        'status': input.status.value,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': normalizeProductField(actorUserId),
        if (uploadedImage != null) 'imageUrl': uploadedImage.downloadUrl,
        if (uploadedImage != null) 'imagePath': uploadedImage.storagePath,
        if (uploadedImage != null)
          'imageUploadStatus': ProductImageUploadStatus.ready.value,
      };

      await _firestore
          .collection(_productsCollection)
          .doc(product.id)
          .update(payload);
    } on FirebaseException catch (error) {
      await _cleanupFailedUpdateUpload(
        uploadedImage: uploadedImage,
        previousImagePath: product.imagePath,
      );
      throw _mapFirebaseException(error);
    } on ProductRepositoryException {
      rethrow;
    } catch (error) {
      await _cleanupFailedUpdateUpload(
        uploadedImage: uploadedImage,
        previousImagePath: product.imagePath,
      );
      throw ProductRepositoryException(
        code: 'product-update-failed',
        message:
            'No pudimos guardar el producto. Revisá tu conexión y reintentá.',
        cause: error,
      );
    }
  }

  @override
  Future<void> deactivateProduct({
    required MerchantProduct product,
    required String actorUserId,
  }) async {
    _assertActorMatchesProductOwner(product: product, actorUserId: actorUserId);

    try {
      await _callDeactivateProductCallable(
        merchantId: product.merchantId,
        productId: product.id,
      );
    } on FirebaseFunctionsException catch (error) {
      throw _mapFunctionsException(error);
    } on FirebaseException catch (error) {
      throw _mapFirebaseException(error);
    } catch (error) {
      throw ProductRepositoryException(
        code: 'product-deactivate-failed',
        message: 'No pudimos dar de baja el producto. Probá nuevamente.',
        cause: error,
      );
    }
  }

  @override
  Future<void> setVisibilityStatus({
    required MerchantProduct product,
    required ProductVisibilityStatus visibilityStatus,
    required String actorUserId,
  }) async {
    _assertActorMatchesProductOwner(product: product, actorUserId: actorUserId);

    try {
      await _firestore.collection(_productsCollection).doc(product.id).update({
        'visibilityStatus': visibilityStatus.value,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': normalizeProductField(actorUserId),
      });
    } on FirebaseException catch (error) {
      throw _mapFirebaseException(error);
    } catch (error) {
      throw ProductRepositoryException(
        code: 'product-visibility-failed',
        message: 'No pudimos actualizar la visibilidad del producto.',
        cause: error,
      );
    }
  }

  @override
  Future<ProductImageUploadResult> uploadProductImage({
    required String merchantId,
    required String productId,
    required ProductImageUploadData image,
    String? existingImagePath,
  }) async {
    _validateImage(image);
    final path =
        'merchant-products/${normalizeProductField(merchantId)}/${normalizeProductField(productId)}/cover.jpg';
    final ref = _storage.ref(path);

    try {
      final metadata = SettableMetadata(
        contentType: image.contentType,
        cacheControl: 'public,max-age=3600',
      );
      await ref.putData(image.bytes, metadata);
      final downloadUrl = await ref.getDownloadURL();

      final normalizedExistingPath = normalizeNullableProductField(
        existingImagePath,
      );
      if (normalizedExistingPath != null && normalizedExistingPath != path) {
        await _safeDeleteStorageObject(normalizedExistingPath);
      }

      return ProductImageUploadResult(
        downloadUrl: downloadUrl,
        storagePath: path,
        sizeBytes: image.sizeBytes,
      );
    } on FirebaseException catch (error) {
      throw _mapStorageException(error);
    } catch (error) {
      throw ProductImageUploadException(cause: error);
    }
  }

  @override
  Future<List<MerchantProduct>> fetchPublicProducts({
    required String merchantId,
    int limit = 24,
  }) async {
    final normalizedMerchantId = normalizeProductField(merchantId);
    if (normalizedMerchantId.isEmpty) return const [];
    final safeLimit = limit.clamp(1, _maxPublicProductsLimit).toInt();

    try {
      final snapshot = await _firestore
          .collection(_productsCollection)
          .where('merchantId', isEqualTo: normalizedMerchantId)
          .where('status', isEqualTo: ProductStatus.active.value)
          .where(
            'visibilityStatus',
            isEqualTo: ProductVisibilityStatus.visible.value,
          )
          .orderBy('updatedAt', descending: true)
          .limit(safeLimit)
          .get();

      return snapshot.docs
          .map(MerchantProduct.fromFirestore)
          .toList(growable: false);
    } on FirebaseException catch (error) {
      throw _mapFirestoreException(error);
    } catch (error) {
      throw ProductRepositoryException(
        code: 'product-public-read-failed',
        message: 'No pudimos cargar los productos públicos.',
        cause: error,
      );
    }
  }

  void _validateInput(ProductDraftInput input) {
    final nameError = validateProductName(input.name);
    if (nameError != null) {
      throw ProductRepositoryException(
        code: 'product-name-invalid',
        message: nameError,
      );
    }
    final priceError = validateProductPriceLabel(input.priceLabel);
    if (priceError != null) {
      throw ProductRepositoryException(
        code: 'product-price-invalid',
        message: priceError,
      );
    }
  }

  void _validateImage(ProductImageUploadData image) {
    if (image.sizeBytes > _maxImageBytes) {
      throw const ProductImageTooLargeException();
    }
    final normalizedType =
        normalizeProductField(image.contentType).toLowerCase();
    if (!normalizedType.startsWith('image/')) {
      throw const ProductImageTypeException();
    }
  }

  void _assertActorMatchesProductOwner({
    required MerchantProduct product,
    required String actorUserId,
  }) {
    final normalizedActorUserId = normalizeProductField(actorUserId);
    if (normalizedActorUserId.isEmpty ||
        normalizedActorUserId != product.ownerUserId) {
      throw const ProductUnauthorizedException();
    }
  }

  Future<void> _safeDeleteStorageObject(String path) async {
    try {
      await _storage.ref(path).delete();
    } catch (_) {
      // No bloqueamos el flujo principal por una limpieza best-effort.
    }
  }

  Future<void> _cleanupFailedUpdateUpload({
    required ProductImageUploadResult? uploadedImage,
    required String? previousImagePath,
  }) async {
    if (uploadedImage == null) return;
    final previous = normalizeNullableProductField(previousImagePath);
    if (previous == uploadedImage.storagePath) {
      // Si se sobrescribió el mismo objeto, no intentamos borrar para no
      // dejar al producto sin imagen.
      return;
    }
    await _safeDeleteStorageObject(uploadedImage.storagePath);
  }

  ProductRepositoryException _mapFirebaseException(FirebaseException error) {
    if (error.plugin == 'firebase_storage') {
      return _mapStorageException(error);
    }
    return _mapFirestoreException(error);
  }

  ProductRepositoryException _mapFirestoreException(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return ProductUnauthorizedException(cause: error);
      case 'unauthenticated':
        return ProductSessionExpiredException(cause: error);
      case 'not-found':
        return ProductNotFoundException(cause: error);
      default:
        return ProductRepositoryException(
          code: 'product-firestore-error',
          message:
              'No pudimos guardar el producto. Revisá tu conexión y reintentá.',
          cause: error,
        );
    }
  }

  ProductRepositoryException _mapStorageException(FirebaseException error) {
    switch (error.code) {
      case 'unauthenticated':
      case 'unauthorized':
        return ProductUnauthorizedException(cause: error);
      case 'object-not-found':
        return ProductNotFoundException(cause: error);
      case 'invalid-argument':
      case 'invalid-checksum':
      case 'invalid-event-name':
      case 'invalid-url':
        return ProductImageTypeException(cause: error);
      case 'retry-limit-exceeded':
      case 'canceled':
      case 'unknown':
      default:
        return ProductImageUploadException(cause: error);
    }
  }

  Future<String> _callCreateProductCallable({
    required String merchantId,
    required String productId,
    required String name,
    required String priceLabel,
    required ProductStockStatus stockStatus,
    required ProductVisibilityStatus visibilityStatus,
    required ProductStatus status,
    required ProductImageUploadResult? imageResult,
  }) async {
    final callable = _functions.httpsCallable('createMerchantProduct');
    final response = await callable.call(<String, dynamic>{
      'merchantId': merchantId,
      'productId': productId,
      'name': name,
      'priceLabel': priceLabel,
      'stockStatus': stockStatus.value,
      'visibilityStatus': visibilityStatus.value,
      'status': status.value,
      if (imageResult != null) 'imageUrl': imageResult.downloadUrl,
      if (imageResult != null) 'imagePath': imageResult.storagePath,
      if (imageResult != null)
        'imageUploadStatus': ProductImageUploadStatus.ready.value,
    }).timeout(_callableTimeout);

    final data = (response.data as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final createdProductId =
        normalizeProductField((data['productId'] as String?) ?? productId);
    if (createdProductId.isEmpty) {
      throw const ProductRepositoryException(
        code: 'product-create-failed',
        message: 'No pudimos crear el producto.',
      );
    }
    return createdProductId;
  }

  Future<void> _callDeactivateProductCallable({
    required String merchantId,
    required String productId,
  }) async {
    final callable = _functions.httpsCallable('deactivateMerchantProduct');
    await callable.call(<String, dynamic>{
      'merchantId': normalizeProductField(merchantId),
      'productId': normalizeProductField(productId),
    }).timeout(_callableTimeout);
  }

  ProductRepositoryException _mapFunctionsException(
    FirebaseFunctionsException error,
  ) {
    final details = (error.details is Map)
        ? (error.details as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final detailCode = (details['code'] as String?)?.trim();
    if (detailCode == 'catalog_limit_reached' ||
        error.code == 'failed-precondition') {
      return ProductLimitReachedException(
        message: error.message ??
            'Alcanzaste el límite de productos de tu catálogo. Contactá a administración para ampliar el cupo.',
        cause: error,
      );
    }

    switch (error.code) {
      case 'permission-denied':
        return ProductUnauthorizedException(cause: error);
      case 'unauthenticated':
        return ProductSessionExpiredException(cause: error);
      case 'not-found':
        return ProductNotFoundException(cause: error);
      default:
        return ProductRepositoryException(
          code: 'product-functions-error',
          message: error.message ??
              'No pudimos guardar el producto. Revisá tu conexión y reintentá.',
          cause: error,
        );
    }
  }
}
