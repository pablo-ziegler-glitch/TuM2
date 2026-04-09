import 'dart:typed_data';

import '../models/merchant_product.dart';

class ProductDraftInput {
  const ProductDraftInput({
    required this.name,
    required this.priceLabel,
    required this.stockStatus,
    required this.visibilityStatus,
    this.status = ProductStatus.active,
  });

  final String name;
  final String priceLabel;
  final ProductStockStatus stockStatus;
  final ProductVisibilityStatus visibilityStatus;
  final ProductStatus status;
}

class ProductImageUploadData {
  const ProductImageUploadData({
    required this.bytes,
    required this.contentType,
    required this.fileName,
  });

  final Uint8List bytes;
  final String contentType;
  final String fileName;

  int get sizeBytes => bytes.lengthInBytes;
}

class ProductImageUploadResult {
  const ProductImageUploadResult({
    required this.downloadUrl,
    required this.storagePath,
    required this.sizeBytes,
  });

  final String downloadUrl;
  final String storagePath;
  final int sizeBytes;
}

abstract interface class ProductRepository {
  Stream<List<MerchantProduct>> watchOwnerProducts({
    required String merchantId,
  });

  Future<List<MerchantProduct>> fetchOwnerProducts({
    required String merchantId,
    int limit,
  });

  Stream<MerchantProduct?> watchProductById(String productId);

  Future<MerchantProduct?> getProductById(String productId);

  Future<String> createProduct({
    required String merchantId,
    required String ownerUserId,
    required String actorUserId,
    required ProductDraftInput input,
    ProductImageUploadData? image,
  });

  Future<void> updateProduct({
    required MerchantProduct product,
    required String actorUserId,
    required ProductDraftInput input,
    ProductImageUploadData? newImage,
  });

  Future<void> deactivateProduct({
    required MerchantProduct product,
    required String actorUserId,
  });

  Future<void> setVisibilityStatus({
    required MerchantProduct product,
    required ProductVisibilityStatus visibilityStatus,
    required String actorUserId,
  });

  Future<ProductImageUploadResult> uploadProductImage({
    required String merchantId,
    required String productId,
    required ProductImageUploadData image,
    String? existingImagePath,
  });

  Future<List<MerchantProduct>> fetchPublicProducts({
    required String merchantId,
    int limit,
  });
}

class ProductRepositoryException implements Exception {
  const ProductRepositoryException({
    required this.code,
    required this.message,
    this.cause,
  });

  final String code;
  final String message;
  final Object? cause;

  @override
  String toString() {
    return 'ProductRepositoryException(code: $code, message: $message, cause: $cause)';
  }
}

class ProductUnauthorizedException extends ProductRepositoryException {
  const ProductUnauthorizedException({
    super.message = 'No tenés permisos para editar este producto.',
    super.cause,
  }) : super(code: 'product-unauthorized');
}

class ProductNotFoundException extends ProductRepositoryException {
  const ProductNotFoundException({
    super.message = 'El producto no existe o ya no está disponible.',
    super.cause,
  }) : super(code: 'product-not-found');
}

class ProductSessionExpiredException extends ProductRepositoryException {
  const ProductSessionExpiredException({
    super.message = 'Tu sesión cambió. Volvé a iniciar sesión.',
    super.cause,
  }) : super(code: 'product-session-expired');
}

class ProductImageTooLargeException extends ProductRepositoryException {
  const ProductImageTooLargeException({
    super.message =
        'No se pudo subir la foto. Probá con una imagen más liviana.',
    super.cause,
  }) : super(code: 'product-image-too-large');
}

class ProductImageTypeException extends ProductRepositoryException {
  const ProductImageTypeException({
    super.message = 'La imagen seleccionada no tiene un formato válido.',
    super.cause,
  }) : super(code: 'product-image-invalid-type');
}

class ProductImageUploadException extends ProductRepositoryException {
  const ProductImageUploadException({
    super.message =
        'No se pudo subir la foto. Probá con una imagen más liviana.',
    super.cause,
  }) : super(code: 'product-image-upload-failed');
}
