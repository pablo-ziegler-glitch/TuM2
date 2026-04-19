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
    this.visibilityInFlightIds = const <String>{},
    this.deactivateInFlightIds = const <String>{},
    this.errorMessage,
  });

  final Set<String> visibilityInFlightIds;
  final Set<String> deactivateInFlightIds;
  final String? errorMessage;

  bool isVisibilityLoading(String productId) =>
      visibilityInFlightIds.contains(productId);

  bool isDeactivateLoading(String productId) =>
      deactivateInFlightIds.contains(productId);

  ProductMutationState copyWith({
    Set<String>? visibilityInFlightIds,
    Set<String>? deactivateInFlightIds,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ProductMutationState(
      visibilityInFlightIds:
          visibilityInFlightIds ?? this.visibilityInFlightIds,
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

  Future<bool> toggleVisibility({
    required MerchantProduct product,
    required String actorUserId,
  }) async {
    if (product.status == ProductStatus.inactive) {
      state = state.copyWith(
        errorMessage:
            'Este producto está inactivo. Reactivalo para cambiar su visibilidad.',
      );
      return false;
    }
    if (state.visibilityInFlightIds.contains(product.id)) return false;
    final nextVisibility =
        product.visibilityStatus == ProductVisibilityStatus.visible
            ? ProductVisibilityStatus.hidden
            : ProductVisibilityStatus.visible;

    final nextInFlight = {...state.visibilityInFlightIds, product.id};
    state = state.copyWith(
      visibilityInFlightIds: nextInFlight,
      clearError: true,
    );

    try {
      await _repository.setVisibilityStatus(
        product: product,
        visibilityStatus: nextVisibility,
        actorUserId: actorUserId,
      );
      await OwnerProductsAnalytics.logVisibilityChanged(
        merchantId: product.merchantId,
        productId: product.id,
        visibilityStatus: nextVisibility,
      );
      _invalidateCaches(product);
      state = state.copyWith(
        visibilityInFlightIds: {...state.visibilityInFlightIds}
          ..remove(product.id),
      );
      return true;
    } on ProductRepositoryException catch (error) {
      state = state.copyWith(
        visibilityInFlightIds: {...state.visibilityInFlightIds}
          ..remove(product.id),
        errorMessage: error.message,
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        visibilityInFlightIds: {...state.visibilityInFlightIds}
          ..remove(product.id),
        errorMessage: 'No pudimos actualizar la visibilidad del producto.',
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
