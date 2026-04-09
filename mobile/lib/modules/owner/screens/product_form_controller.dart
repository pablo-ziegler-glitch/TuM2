import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analytics/owner_products_analytics.dart';
import '../models/merchant_product.dart';
import '../repositories/product_repository.dart';

const int productImageMaxBytes = 5 * 1024 * 1024;

enum ProductFormMode { create, edit }

enum ProductFormSubmitStatus { idle, success, error }

class ProductFormScope {
  const ProductFormScope({
    required this.merchantId,
    required this.ownerUserId,
    this.productId,
  });

  final String merchantId;
  final String ownerUserId;
  final String? productId;

  bool get isEditing =>
      productId != null && normalizeProductField(productId!) != '';

  @override
  bool operator ==(Object other) {
    return other is ProductFormScope &&
        other.merchantId == merchantId &&
        other.ownerUserId == ownerUserId &&
        other.productId == productId;
  }

  @override
  int get hashCode => Object.hash(merchantId, ownerUserId, productId);
}

class ProductImageUploadState {
  const ProductImageUploadState({
    required this.isUploading,
    required this.progress,
    this.errorMessage,
  });

  const ProductImageUploadState.idle()
      : isUploading = false,
        progress = 0,
        errorMessage = null;

  final bool isUploading;
  final double progress;
  final String? errorMessage;
}

class ProductFormState {
  const ProductFormState({
    required this.scope,
    required this.mode,
    this.isInitialLoading = false,
    this.isSubmitting = false,
    this.submitStatus = ProductFormSubmitStatus.idle,
    this.name = '',
    this.priceLabel = '',
    this.stockStatus = ProductStockStatus.available,
    this.visibilityStatus = ProductVisibilityStatus.visible,
    this.status = ProductStatus.active,
    this.currentImageUrl,
    this.currentImagePath,
    this.localImage,
    this.nameError,
    this.priceLabelError,
    this.imageError,
    this.message,
    this.loadedProduct,
    this.uploadState = const ProductImageUploadState.idle(),
  });

  final ProductFormScope scope;
  final ProductFormMode mode;
  final bool isInitialLoading;
  final bool isSubmitting;
  final ProductFormSubmitStatus submitStatus;
  final String name;
  final String priceLabel;
  final ProductStockStatus stockStatus;
  final ProductVisibilityStatus visibilityStatus;
  final ProductStatus status;
  final String? currentImageUrl;
  final String? currentImagePath;
  final ProductImageUploadData? localImage;
  final String? nameError;
  final String? priceLabelError;
  final String? imageError;
  final String? message;
  final MerchantProduct? loadedProduct;
  final ProductImageUploadState uploadState;

  bool get isEditing => mode == ProductFormMode.edit;
  bool get hasLocalImage => localImage != null;
  bool get hasCurrentImage =>
      normalizeNullableProductField(currentImageUrl) != null;
  bool get hasImage => hasLocalImage || hasCurrentImage;

  ProductFormState copyWith({
    bool? isInitialLoading,
    bool? isSubmitting,
    ProductFormSubmitStatus? submitStatus,
    String? name,
    String? priceLabel,
    ProductStockStatus? stockStatus,
    ProductVisibilityStatus? visibilityStatus,
    ProductStatus? status,
    String? currentImageUrl,
    bool clearCurrentImageUrl = false,
    String? currentImagePath,
    bool clearCurrentImagePath = false,
    ProductImageUploadData? localImage,
    bool clearLocalImage = false,
    String? nameError,
    bool clearNameError = false,
    String? priceLabelError,
    bool clearPriceLabelError = false,
    String? imageError,
    bool clearImageError = false,
    String? message,
    bool clearMessage = false,
    MerchantProduct? loadedProduct,
    ProductImageUploadState? uploadState,
  }) {
    return ProductFormState(
      scope: scope,
      mode: mode,
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submitStatus: submitStatus ?? this.submitStatus,
      name: name ?? this.name,
      priceLabel: priceLabel ?? this.priceLabel,
      stockStatus: stockStatus ?? this.stockStatus,
      visibilityStatus: visibilityStatus ?? this.visibilityStatus,
      status: status ?? this.status,
      currentImageUrl: clearCurrentImageUrl
          ? null
          : (currentImageUrl ?? this.currentImageUrl),
      currentImagePath: clearCurrentImagePath
          ? null
          : (currentImagePath ?? this.currentImagePath),
      localImage: clearLocalImage ? null : (localImage ?? this.localImage),
      nameError: clearNameError ? null : (nameError ?? this.nameError),
      priceLabelError: clearPriceLabelError
          ? null
          : (priceLabelError ?? this.priceLabelError),
      imageError: clearImageError ? null : (imageError ?? this.imageError),
      message: clearMessage ? null : (message ?? this.message),
      loadedProduct: loadedProduct ?? this.loadedProduct,
      uploadState: uploadState ?? this.uploadState,
    );
  }
}

class ProductFormSubmitResult {
  const ProductFormSubmitResult({
    required this.success,
    required this.isCreate,
    this.productId,
  });

  final bool success;
  final bool isCreate;
  final String? productId;
}

class ProductFormNotifier extends StateNotifier<ProductFormState> {
  ProductFormNotifier({
    required ProductRepository repository,
    required ProductFormScope scope,
  })  : _repository = repository,
        super(
          ProductFormState(
            scope: scope,
            mode:
                scope.isEditing ? ProductFormMode.edit : ProductFormMode.create,
            isInitialLoading: scope.isEditing,
          ),
        ) {
    if (scope.isEditing) {
      unawaited(_loadInitialProduct());
    }
  }

  final ProductRepository _repository;

  Future<void> _loadInitialProduct() async {
    final productId = state.scope.productId;
    if (productId == null) return;

    try {
      final product = await _repository.getProductById(productId);
      if (product == null) {
        state = state.copyWith(
          isInitialLoading: false,
          submitStatus: ProductFormSubmitStatus.error,
          message: 'No encontramos el producto que querés editar.',
        );
        return;
      }

      if (product.merchantId != state.scope.merchantId ||
          product.ownerUserId != state.scope.ownerUserId) {
        throw const ProductUnauthorizedException();
      }

      state = state.copyWith(
        isInitialLoading: false,
        loadedProduct: product,
        name: product.name,
        priceLabel: product.priceLabel,
        stockStatus: product.stockStatus,
        visibilityStatus: product.visibilityStatus,
        status: product.status,
        currentImageUrl: product.imageUrl,
        currentImagePath: product.imagePath,
      );
    } on ProductRepositoryException catch (error) {
      state = state.copyWith(
        isInitialLoading: false,
        submitStatus: ProductFormSubmitStatus.error,
        message: error.message,
      );
    } catch (_) {
      state = state.copyWith(
        isInitialLoading: false,
        submitStatus: ProductFormSubmitStatus.error,
        message: 'No pudimos cargar el producto.',
      );
    }
  }

  void setName(String value) {
    state = state.copyWith(
      name: value,
      clearNameError: true,
      clearMessage: true,
      submitStatus: ProductFormSubmitStatus.idle,
    );
  }

  void setPriceLabel(String value) {
    state = state.copyWith(
      priceLabel: value,
      clearPriceLabelError: true,
      clearMessage: true,
      submitStatus: ProductFormSubmitStatus.idle,
    );
  }

  void setStockStatus(ProductStockStatus value) {
    state = state.copyWith(
      stockStatus: value,
      clearMessage: true,
      submitStatus: ProductFormSubmitStatus.idle,
    );
  }

  void setVisibilityStatus(ProductVisibilityStatus value) {
    state = state.copyWith(
      visibilityStatus: value,
      clearMessage: true,
      submitStatus: ProductFormSubmitStatus.idle,
    );
  }

  void setLocalImage(ProductImageUploadData image) {
    if (image.sizeBytes > productImageMaxBytes) {
      state = state.copyWith(
        imageError:
            'No se pudo subir la foto. Probá con una imagen más liviana.',
      );
      return;
    }

    final contentType = normalizeProductField(image.contentType).toLowerCase();
    if (!contentType.startsWith('image/')) {
      state = state.copyWith(
        imageError: 'La imagen seleccionada no tiene un formato válido.',
      );
      return;
    }

    state = state.copyWith(
      localImage: image,
      clearImageError: true,
      clearMessage: true,
      submitStatus: ProductFormSubmitStatus.idle,
    );
  }

  void clearLocalImage() {
    state = state.copyWith(
      clearLocalImage: true,
      clearImageError: true,
    );
  }

  Future<ProductFormSubmitResult> submit({
    required String actorUserId,
  }) async {
    if (state.isSubmitting || state.isInitialLoading) {
      return const ProductFormSubmitResult(
        success: false,
        isCreate: false,
      );
    }

    final name = normalizeProductField(state.name);
    final priceLabel = normalizeProductField(state.priceLabel);
    final nameError = validateProductName(name);
    final priceLabelError = validateProductPriceLabel(priceLabel);

    if (nameError != null || priceLabelError != null) {
      state = state.copyWith(
        nameError: nameError,
        priceLabelError: priceLabelError,
        submitStatus: ProductFormSubmitStatus.error,
      );
      return const ProductFormSubmitResult(
        success: false,
        isCreate: false,
      );
    }

    final input = ProductDraftInput(
      name: name,
      priceLabel: priceLabel,
      stockStatus: state.stockStatus,
      visibilityStatus: state.visibilityStatus,
      status: state.status,
    );

    state = state.copyWith(
      isSubmitting: true,
      submitStatus: ProductFormSubmitStatus.idle,
      clearMessage: true,
      clearImageError: true,
      uploadState: const ProductImageUploadState(
        isUploading: false,
        progress: 0,
      ),
    );

    final stopwatch = Stopwatch()..start();
    try {
      if (state.hasLocalImage) {
        state = state.copyWith(
          uploadState: const ProductImageUploadState(
            isUploading: true,
            progress: 0.2,
          ),
        );
      }

      if (state.isEditing) {
        final loadedProduct = state.loadedProduct;
        if (loadedProduct == null) {
          throw const ProductNotFoundException();
        }

        await _repository.updateProduct(
          product: loadedProduct,
          actorUserId: actorUserId,
          input: input,
          newImage: state.localImage,
        );

        if (state.hasLocalImage) {
          await OwnerProductsAnalytics.logImageUploaded(
            merchantId: loadedProduct.merchantId,
            productId: loadedProduct.id,
            imageSizeBytes: state.localImage!.sizeBytes,
            latencyMs: stopwatch.elapsedMilliseconds,
          );
        }

        await OwnerProductsAnalytics.logEdited(
          merchantId: loadedProduct.merchantId,
          productId: loadedProduct.id,
          hasImage: state.hasImage,
          stockStatus: input.stockStatus,
          visibilityStatus: input.visibilityStatus,
          latencyMs: stopwatch.elapsedMilliseconds,
        );

        state = state.copyWith(
          isSubmitting: false,
          submitStatus: ProductFormSubmitStatus.success,
          message: 'Producto actualizado correctamente.',
          clearLocalImage: true,
          uploadState: const ProductImageUploadState.idle(),
        );
        return ProductFormSubmitResult(
          success: true,
          isCreate: false,
          productId: loadedProduct.id,
        );
      }

      final productId = await _repository.createProduct(
        merchantId: state.scope.merchantId,
        ownerUserId: state.scope.ownerUserId,
        actorUserId: actorUserId,
        input: input,
        image: state.localImage,
      );

      if (state.hasLocalImage) {
        await OwnerProductsAnalytics.logImageUploaded(
          merchantId: state.scope.merchantId,
          productId: productId,
          imageSizeBytes: state.localImage!.sizeBytes,
          latencyMs: stopwatch.elapsedMilliseconds,
        );
      }

      await OwnerProductsAnalytics.logCreated(
        merchantId: state.scope.merchantId,
        productId: productId,
        hasImage: state.hasImage,
        stockStatus: input.stockStatus,
        visibilityStatus: input.visibilityStatus,
        latencyMs: stopwatch.elapsedMilliseconds,
      );

      state = state.copyWith(
        isSubmitting: false,
        submitStatus: ProductFormSubmitStatus.success,
        message: 'Producto creado correctamente.',
        clearLocalImage: true,
        uploadState: const ProductImageUploadState.idle(),
      );
      return ProductFormSubmitResult(
        success: true,
        isCreate: true,
        productId: productId,
      );
    } on ProductImageUploadException catch (error) {
      await OwnerProductsAnalytics.logImageUploadFailed(
        merchantId: state.scope.merchantId,
        productId: state.scope.productId ?? 'new',
        reason: error.code,
      );
      state = state.copyWith(
        isSubmitting: false,
        submitStatus: ProductFormSubmitStatus.error,
        imageError: error.message,
        uploadState: ProductImageUploadState(
          isUploading: false,
          progress: 0,
          errorMessage: error.message,
        ),
      );
      return const ProductFormSubmitResult(
        success: false,
        isCreate: false,
      );
    } on ProductRepositoryException catch (error) {
      if (state.hasLocalImage && _isImageRelatedError(error)) {
        await OwnerProductsAnalytics.logImageUploadFailed(
          merchantId: state.scope.merchantId,
          productId: state.scope.productId ?? 'new',
          reason: error.code,
        );
      }
      state = state.copyWith(
        isSubmitting: false,
        submitStatus: ProductFormSubmitStatus.error,
        message: error.message,
        uploadState: ProductImageUploadState(
          isUploading: false,
          progress: 0,
          errorMessage:
              error is ProductImageUploadException ? error.message : null,
        ),
      );
      return const ProductFormSubmitResult(
        success: false,
        isCreate: false,
      );
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        submitStatus: ProductFormSubmitStatus.error,
        message:
            'No pudimos guardar el producto. Revisá tu conexión y reintentá.',
        uploadState: const ProductImageUploadState.idle(),
      );
      return const ProductFormSubmitResult(
        success: false,
        isCreate: false,
      );
    }
  }

  bool _isImageRelatedError(ProductRepositoryException error) {
    return error is ProductImageUploadException ||
        error is ProductImageTooLargeException ||
        error is ProductImageTypeException ||
        error.code.startsWith('product-image');
  }
}
