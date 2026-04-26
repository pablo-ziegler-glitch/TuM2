import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analytics/owner_products_analytics.dart';
import '../models/merchant_product.dart';
import '../repositories/firebase_product_repository.dart';
import '../repositories/product_repository.dart';
import '../screens/product_form_controller.dart';
import 'owner_providers.dart';

const _kOwnerProductsProviderTtl = Duration(minutes: 4);
const _kOwnerProductByIdProviderTtl = Duration(minutes: 3);

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return FirebaseProductRepository();
});

final merchantProductsProvider =
    FutureProvider.autoDispose.family<List<MerchantProduct>, String>((
  ref,
  merchantId,
) async {
  final link = ref.keepAlive();
  Timer? disposeTimer;
  void scheduleDispose() {
    disposeTimer?.cancel();
    disposeTimer = Timer(_kOwnerProductsProviderTtl, link.close);
  }

  ref.onCancel(scheduleDispose);
  ref.onResume(() => disposeTimer?.cancel());
  ref.onDispose(() => disposeTimer?.cancel());

  final repository = ref.watch(productRepositoryProvider);
  return repository.fetchOwnerProducts(merchantId: merchantId);
});

final merchantProductByIdProvider = FutureProvider.autoDispose
    .family<MerchantProduct?, String>((ref, productId) async {
  final link = ref.keepAlive();
  Timer? disposeTimer;
  void scheduleDispose() {
    disposeTimer?.cancel();
    disposeTimer = Timer(_kOwnerProductByIdProviderTtl, link.close);
  }

  ref.onCancel(scheduleDispose);
  ref.onResume(() => disposeTimer?.cancel());
  ref.onDispose(() => disposeTimer?.cancel());

  final repository = ref.watch(productRepositoryProvider);
  return repository.getProductById(productId);
});

final publicMerchantProductsProvider =
    FutureProvider.autoDispose.family<List<MerchantProduct>, String>((
  ref,
  merchantId,
) async {
  final repository = ref.watch(productRepositoryProvider);
  return repository.fetchPublicProducts(merchantId: merchantId);
});

final productFormNotifierProvider = StateNotifierProvider.autoDispose
    .family<ProductFormNotifier, ProductFormState, ProductFormScope>((
  ref,
  scope,
) {
  final repository = ref.watch(productRepositoryProvider);
  return ProductFormNotifier(repository: repository, scope: scope);
});

final productImageUploadStateProvider =
    Provider.autoDispose.family<ProductImageUploadState, ProductFormScope>((
  ref,
  scope,
) {
  return ref.watch(productFormNotifierProvider(scope)).uploadState;
});

class ProductMutationState {
  const ProductMutationState({
    this.stockInFlightIds = const <String>{},
    this.reactivateInFlightIds = const <String>{},
    this.deactivateInFlightIds = const <String>{},
    this.errorMessage,
  });

  final Set<String> stockInFlightIds;
  final Set<String> reactivateInFlightIds;
  final Set<String> deactivateInFlightIds;
  final String? errorMessage;

  bool isStockLoading(String productId) => stockInFlightIds.contains(productId);

  bool isReactivateLoading(String productId) =>
      reactivateInFlightIds.contains(productId);

  bool isDeactivateLoading(String productId) =>
      deactivateInFlightIds.contains(productId);

  ProductMutationState copyWith({
    Set<String>? stockInFlightIds,
    Set<String>? reactivateInFlightIds,
    Set<String>? deactivateInFlightIds,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ProductMutationState(
      stockInFlightIds: stockInFlightIds ?? this.stockInFlightIds,
      reactivateInFlightIds:
          reactivateInFlightIds ?? this.reactivateInFlightIds,
      deactivateInFlightIds:
          deactivateInFlightIds ?? this.deactivateInFlightIds,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class ProductMutationController extends StateNotifier<ProductMutationState> {
  ProductMutationController({
    required ProductRepository repository,
    required Ref ref,
  })  : _repository = repository,
        _ref = ref,
        super(const ProductMutationState());

  final ProductRepository _repository;
  final Ref _ref;
  Timer? _ownerMerchantInvalidateTimer;

  Future<bool> setStockStatus({
    required MerchantProduct product,
    required ProductStockStatus stockStatus,
    required String actorUserId,
  }) async {
    if (product.status == ProductStatus.inactive) {
      state = state.copyWith(
        errorMessage:
            'Este producto está oculto. Volvé a mostrarlo para cambiar disponibilidad.',
      );
      return false;
    }
    if (state.stockInFlightIds.contains(product.id)) return false;
    if (product.stockStatus == stockStatus) return true;

    final nextInFlight = {...state.stockInFlightIds, product.id};
    state = state.copyWith(
      stockInFlightIds: nextInFlight,
      clearError: true,
    );

    try {
      await _repository.setStockStatus(
        product: product,
        stockStatus: stockStatus,
        actorUserId: actorUserId,
      );
      await OwnerProductsAnalytics.logStockStatusChanged(
        merchantId: product.merchantId,
        productId: product.id,
        stockStatus: stockStatus,
      );
      _invalidateCaches(product);
      state = state.copyWith(
        stockInFlightIds: {...state.stockInFlightIds}..remove(product.id),
      );
      return true;
    } on ProductRepositoryException catch (error) {
      state = state.copyWith(
        stockInFlightIds: {...state.stockInFlightIds}..remove(product.id),
        errorMessage: error.message,
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        stockInFlightIds: {...state.stockInFlightIds}..remove(product.id),
        errorMessage: 'No pudimos actualizar la disponibilidad del producto.',
      );
      return false;
    }
  }

  Future<bool> deactivate({
    required MerchantProduct product,
    required String actorUserId,
  }) async {
    if (product.status == ProductStatus.inactive) {
      return false;
    }
    if (state.deactivateInFlightIds.contains(product.id)) return false;
    final nextInFlight = {...state.deactivateInFlightIds, product.id};
    state = state.copyWith(
      deactivateInFlightIds: nextInFlight,
      clearError: true,
    );

    try {
      await _repository.deactivateProduct(
        product: product,
        actorUserId: actorUserId,
      );
      await OwnerProductsAnalytics.logDeactivated(
        merchantId: product.merchantId,
        productId: product.id,
      );
      await OwnerProductsAnalytics.logVisibilityChanged(
        merchantId: product.merchantId,
        productId: product.id,
        visibilityStatus: ProductVisibilityStatus.hidden,
      );
      _invalidateCaches(product);
      state = state.copyWith(
        deactivateInFlightIds: {...state.deactivateInFlightIds}
          ..remove(product.id),
      );
      return true;
    } on ProductRepositoryException catch (error) {
      state = state.copyWith(
        deactivateInFlightIds: {...state.deactivateInFlightIds}
          ..remove(product.id),
        errorMessage: error.message,
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        deactivateInFlightIds: {...state.deactivateInFlightIds}
          ..remove(product.id),
        errorMessage: 'No pudimos dar de baja el producto.',
      );
      return false;
    }
  }

  Future<bool> reactivate({
    required MerchantProduct product,
    required String actorUserId,
  }) async {
    if (product.status == ProductStatus.active) {
      return true;
    }
    if (state.reactivateInFlightIds.contains(product.id)) return false;
    final nextInFlight = {...state.reactivateInFlightIds, product.id};
    state = state.copyWith(
      reactivateInFlightIds: nextInFlight,
      clearError: true,
    );

    try {
      await _repository.reactivateProduct(
        product: product,
        actorUserId: actorUserId,
      );
      await OwnerProductsAnalytics.logReactivated(
        merchantId: product.merchantId,
        productId: product.id,
      );
      await OwnerProductsAnalytics.logVisibilityChanged(
        merchantId: product.merchantId,
        productId: product.id,
        visibilityStatus: ProductVisibilityStatus.visible,
      );
      _invalidateCaches(product);
      state = state.copyWith(
        reactivateInFlightIds: {...state.reactivateInFlightIds}
          ..remove(product.id),
      );
      return true;
    } on ProductRepositoryException catch (error) {
      state = state.copyWith(
        reactivateInFlightIds: {...state.reactivateInFlightIds}
          ..remove(product.id),
        errorMessage: error.message,
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        reactivateInFlightIds: {...state.reactivateInFlightIds}
          ..remove(product.id),
        errorMessage: 'No pudimos volver a mostrar el producto.',
      );
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  void _invalidateCaches(MerchantProduct product) {
    _ref.invalidate(merchantProductsProvider(product.merchantId));
    _ref.invalidate(merchantProductByIdProvider(product.id));
    _ref.invalidate(publicMerchantProductsProvider(product.merchantId));
    // Debounce para evitar ráfagas de lecturas sobre `merchants` por múltiples
    // mutaciones consecutivas en el catálogo.
    _ownerMerchantInvalidateTimer?.cancel();
    _ownerMerchantInvalidateTimer = Timer(
      const Duration(milliseconds: 900),
      () => _ref.invalidate(ownerMerchantProvider),
    );
  }

  @override
  void dispose() {
    _ownerMerchantInvalidateTimer?.cancel();
    super.dispose();
  }
}

final productMutationProvider = StateNotifierProvider.autoDispose<
    ProductMutationController, ProductMutationState>((ref) {
  final repository = ref.watch(productRepositoryProvider);
  return ProductMutationController(repository: repository, ref: ref);
});
