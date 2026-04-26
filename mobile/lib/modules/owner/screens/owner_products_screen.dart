import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_notifier.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/providers/feature_flags_provider.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_toast.dart';
import '../analytics/owner_products_analytics.dart';
import '../models/catalog_capacity.dart';
import '../models/merchant_product.dart';
import '../providers/catalog_capacity_providers.dart';
import '../providers/owner_providers.dart';
import '../providers/product_providers.dart';
import '../widgets/product_actions_sheet.dart';
import '../widgets/product_card.dart';
import '../widgets/product_empty_state.dart';

enum _ProductsSortOption {
  recents('Recientes'),
  nameAsc('Nombre A-Z'),
  priceAsc('Precio: menor');

  const _ProductsSortOption(this.label);
  final String label;
}

enum _ProductsFilter {
  active('Activos'),
  outOfStock('Agotados'),
  hidden('Ocultos');

  const _ProductsFilter(this.label);
  final String label;
}

class OwnerProductsScreen extends ConsumerStatefulWidget {
  const OwnerProductsScreen({super.key});

  @override
  ConsumerState<OwnerProductsScreen> createState() =>
      _OwnerProductsScreenState();
}

class _OwnerProductsScreenState extends ConsumerState<OwnerProductsScreen> {
  String? _lastMutationError;
  String? _lastLimitWarningKey;
  String? _lastLimitBlockedKey;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  _ProductsSortOption _sortOption = _ProductsSortOption.recents;
  _ProductsFilter _filter = _ProductsFilter.active;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider).authState;
    final ownerProductsEnabledAsync = ref.watch(ownerProductsEnabledProvider);
    final catalogCapacityPolicyEnabledAsync =
        ref.watch(catalogCapacityPolicyEnabledProvider);
    final catalogCapacityHardBlockEnabledAsync =
        ref.watch(catalogCapacityHardBlockEnabledProvider);
    final catalogCreateViaCfEnabledAsync =
        ref.watch(catalogProductCreateViaCfEnabledProvider);
    final catalogLimitsConfigAsync = ref.watch(catalogLimitsConfigProvider);
    final ownerMerchantAsync = ref.watch(ownerMerchantProvider);
    final mutationState = ref.watch(productMutationProvider);
    _listenMutationErrors(mutationState);

    final ownerUserId = authState is AuthAuthenticated
        ? normalizeProductField(authState.user.uid)
        : '';
    if (ownerUserId.isEmpty) {
      return _Shell(
        child: _LoadErrorState(
          title: 'Sesión no válida',
          message: 'Tu sesión cambió. Volvé a iniciar sesión.',
          ctaLabel: 'Ir a login',
          onRetry: () => context.go(AppRoutes.login),
        ),
      );
    }

    return ownerProductsEnabledAsync.when(
      loading: _buildLoadingShell,
      error: (_, __) => _Shell(
        child: _LoadErrorState(
          title: 'No disponible',
          message: 'No se pudo consultar la disponibilidad del módulo.',
          ctaLabel: 'Reintentar',
          onRetry: () => ref.invalidate(ownerProductsEnabledProvider),
        ),
      ),
      data: (enabled) {
        if (!enabled) {
          return const _Shell(
            child: _LoadErrorState(
              title: 'Temporalmente deshabilitado',
              message:
                  'La gestión de productos está deshabilitada temporalmente.',
              ctaLabel: 'Volver',
            ),
          );
        }

        return ownerMerchantAsync.when(
          loading: _buildLoadingShell,
          error: (_, __) => _Shell(
            child: _LoadErrorState(
              title: 'No pudimos validar tu comercio',
              message: 'Revisá tu conexión e intentá de nuevo.',
              ctaLabel: 'Reintentar',
              onRetry: () => ref.invalidate(ownerMerchantProvider),
            ),
          ),
          data: (resolution) {
            final merchant = resolution.primaryMerchant;
            if (merchant == null) {
              return const _Shell(
                child: _LoadErrorState(
                  title: 'Sin comercio asociado',
                  message: 'No encontramos un comercio asociado a tu usuario.',
                  ctaLabel: 'Volver',
                ),
              );
            }

            final catalogPolicyEnabled =
                catalogCapacityPolicyEnabledAsync.valueOrNull ?? true;
            final catalogHardBlockEnabled =
                catalogCapacityHardBlockEnabledAsync.valueOrNull ?? true;
            final catalogCreateViaCfEnabled =
                catalogCreateViaCfEnabledAsync.valueOrNull ?? true;
            final catalogCapacity = catalogPolicyEnabled &&
                    catalogLimitsConfigAsync.hasValue
                ? resolveOwnerCatalogCapacity(
                    categoryId: merchant.categoryId,
                    activeProductCount: merchant.activeProductCount,
                    merchantLimitOverride: merchant.catalogProductLimitOverride,
                    config: catalogLimitsConfigAsync.requireValue,
                  )
                : null;
            final isCreateBlocked = catalogPolicyEnabled &&
                catalogHardBlockEnabled &&
                (catalogCapacity?.isBlocked ?? false);
            _trackCatalogCapacityEvents(
              merchantId: merchant.id,
              capacity: catalogCapacity,
            );

            final productsAsync =
                ref.watch(merchantProductsProvider(merchant.id));

            return _Shell(
              onFabPressed: () => _handleCreateTap(
                merchantId: merchant.id,
                capacity: catalogCapacity,
                policyEnabled: catalogPolicyEnabled,
                hardBlockEnabled: catalogHardBlockEnabled,
                createViaCfEnabled: catalogCreateViaCfEnabled,
                products: const <MerchantProduct>[],
              ),
              child: Column(
                children: [
                  Expanded(
                    child: productsAsync.when(
                      loading: () => _buildLoadingContent(
                        merchantId: merchant.id,
                        capacity: catalogCapacity,
                        policyEnabled: catalogPolicyEnabled,
                        hardBlockEnabled: catalogHardBlockEnabled,
                        createViaCfEnabled: catalogCreateViaCfEnabled,
                      ),
                      error: (_, __) => _LoadErrorState(
                        title: 'No pudimos cargar tu catálogo',
                        message: 'Revisá tu conexión e intentá de nuevo.',
                        ctaLabel: 'Reintentar',
                        onRetry: () => ref
                            .invalidate(merchantProductsProvider(merchant.id)),
                      ),
                      data: (products) {
                        final filtered = _applyFilters(products,
                            query: _searchQuery,
                            sort: _sortOption,
                            filter: _filter);
                        if (products.isEmpty) {
                          return _buildEmptyState(
                            context,
                            merchantId: merchant.id,
                            capacity: catalogCapacity,
                            policyEnabled: catalogPolicyEnabled,
                            hardBlockEnabled: catalogHardBlockEnabled,
                            createViaCfEnabled: catalogCreateViaCfEnabled,
                          );
                        }
                        return RefreshIndicator(
                          onRefresh: () async {
                            ref.invalidate(
                                merchantProductsProvider(merchant.id));
                            await Future<void>.delayed(
                              const Duration(milliseconds: 200),
                            );
                          },
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                            children: [
                              _HeaderBlock(
                                onAddPressed: () => _handleCreateTap(
                                  merchantId: merchant.id,
                                  capacity: catalogCapacity,
                                  policyEnabled: catalogPolicyEnabled,
                                  hardBlockEnabled: catalogHardBlockEnabled,
                                  createViaCfEnabled: catalogCreateViaCfEnabled,
                                  products: products,
                                ),
                                capacity: catalogCapacity,
                                policyEnabled: catalogPolicyEnabled,
                                hardBlockEnabled: catalogHardBlockEnabled,
                                onContactAdmin: () => _showContactAdminDialog(
                                  merchantId: merchant.id,
                                ),
                              ),
                              const SizedBox(height: 14),
                              _SearchAndSortBlock(
                                searchController: _searchController,
                                onSearchChanged: (value) {
                                  setState(() {
                                    _searchQuery = value;
                                  });
                                },
                                productsCount: filtered.length,
                                sort: _sortOption,
                                onSortChanged: (value) {
                                  if (value == null) return;
                                  setState(() {
                                    _sortOption = value;
                                  });
                                },
                              ),
                              const SizedBox(height: 12),
                              _FilterChips(
                                selected: _filter,
                                onSelected: (value) {
                                  setState(() {
                                    _filter = value;
                                  });
                                },
                              ),
                              const SizedBox(height: 12),
                              if (filtered.isEmpty)
                                const _NoResultsState()
                              else
                                Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(14),
                                    border:
                                        Border.all(color: AppColors.neutral200),
                                  ),
                                  child: Column(
                                    children: [
                                      for (var index = 0;
                                          index < filtered.length;
                                          index++) ...[
                                        ProductCard(
                                          product: filtered[index],
                                          isBusy: mutationState.isStockLoading(
                                                filtered[index].id,
                                              ) ||
                                              mutationState.isReactivateLoading(
                                                filtered[index].id,
                                              ) ||
                                              mutationState.isDeactivateLoading(
                                                filtered[index].id,
                                              ),
                                          onStockStatusChanged: (status) {
                                            _setStockStatus(
                                              context,
                                              product: filtered[index],
                                              stockStatus: status,
                                              ownerUserId: ownerUserId,
                                            );
                                          },
                                          onTapActions: () {
                                            showProductActionsSheet(
                                              context,
                                              product: filtered[index],
                                              onEdit: () => _goToEdit(
                                                context,
                                                filtered[index].id,
                                              ),
                                              onMarkOutOfStock: () =>
                                                  _setStockStatus(
                                                context,
                                                product: filtered[index],
                                                stockStatus: ProductStockStatus
                                                    .outOfStock,
                                                ownerUserId: ownerUserId,
                                              ),
                                              onMarkAvailable: () =>
                                                  _setStockStatus(
                                                context,
                                                product: filtered[index],
                                                stockStatus: ProductStockStatus
                                                    .available,
                                                ownerUserId: ownerUserId,
                                              ),
                                              onHide: () => _confirmDeactivate(
                                                context,
                                                product: filtered[index],
                                                ownerUserId: ownerUserId,
                                              ),
                                              onReactivate: () =>
                                                  _confirmReactivate(
                                                context,
                                                product: filtered[index],
                                                ownerUserId: ownerUserId,
                                              ),
                                              onDelete: () => _confirmDelete(
                                                context,
                                                product: filtered[index],
                                                ownerUserId: ownerUserId,
                                              ),
                                            );
                                          },
                                        ),
                                        if (index != filtered.length - 1)
                                          const Divider(
                                            height: 1,
                                            thickness: 1,
                                            color: AppColors.neutral100,
                                          ),
                                      ],
                                    ],
                                  ),
                                ),
                              if (isCreateBlocked) ...[
                                const SizedBox(height: 12),
                                _LimitBlockedPanel(
                                  capacity: catalogCapacity,
                                  onChooseProductToHide: () =>
                                      _openHideSelectorForBlockedCatalog(
                                    merchantId: merchant.id,
                                    ownerUserId: ownerUserId,
                                    products: products,
                                  ),
                                  onBackToCatalog: () {
                                    setState(() {
                                      _filter = _ProductsFilter.active;
                                      _searchQuery = '';
                                      _searchController.clear();
                                    });
                                  },
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLoadingShell() {
    return const _Shell(
      child: Center(
        child: CircularProgressIndicator(color: AppColors.primary500),
      ),
    );
  }

  Widget _buildLoadingContent({
    required String merchantId,
    required OwnerCatalogCapacity? capacity,
    required bool policyEnabled,
    required bool hardBlockEnabled,
    required bool createViaCfEnabled,
  }) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        _HeaderBlock(
          onAddPressed: () => _handleCreateTap(
            merchantId: merchantId,
            capacity: capacity,
            policyEnabled: policyEnabled,
            hardBlockEnabled: hardBlockEnabled,
            createViaCfEnabled: createViaCfEnabled,
            products: const <MerchantProduct>[],
          ),
          capacity: capacity,
          policyEnabled: policyEnabled,
          hardBlockEnabled: hardBlockEnabled,
          onContactAdmin: () => _showContactAdminDialog(
            merchantId: merchantId,
          ),
        ),
        const SizedBox(height: 14),
        _SearchAndSortBlock(
          searchController: _searchController,
          onSearchChanged: (_) {},
          productsCount: 0,
          sort: _sortOption,
          onSortChanged: (_) {},
        ),
        const SizedBox(height: 12),
        const _FilterSkeleton(),
        const SizedBox(height: 12),
        const _CatalogLoadingSkeleton(),
      ],
    );
  }

  Widget _buildEmptyState(
    BuildContext context, {
    required String merchantId,
    required OwnerCatalogCapacity? capacity,
    required bool policyEnabled,
    required bool hardBlockEnabled,
    required bool createViaCfEnabled,
  }) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        _HeaderBlock(
          onAddPressed: () => _handleCreateTap(
            merchantId: merchantId,
            capacity: capacity,
            policyEnabled: policyEnabled,
            hardBlockEnabled: hardBlockEnabled,
            createViaCfEnabled: createViaCfEnabled,
            products: const <MerchantProduct>[],
          ),
          capacity: capacity,
          policyEnabled: policyEnabled,
          hardBlockEnabled: hardBlockEnabled,
          onContactAdmin: () => _showContactAdminDialog(
            merchantId: merchantId,
          ),
        ),
        const SizedBox(height: 18),
        ProductEmptyState(
          onAddPressed: () => _handleCreateTap(
            merchantId: merchantId,
            capacity: capacity,
            policyEnabled: policyEnabled,
            hardBlockEnabled: hardBlockEnabled,
            createViaCfEnabled: createViaCfEnabled,
            products: const <MerchantProduct>[],
          ),
        ),
      ],
    );
  }

  List<MerchantProduct> _applyFilters(
    List<MerchantProduct> items, {
    required String query,
    required _ProductsSortOption sort,
    required _ProductsFilter filter,
  }) {
    final filteredByTab = items.where((item) {
      switch (filter) {
        case _ProductsFilter.active:
          return item.status == ProductStatus.active &&
              item.stockStatus == ProductStockStatus.available;
        case _ProductsFilter.outOfStock:
          return item.status == ProductStatus.active &&
              item.stockStatus == ProductStockStatus.outOfStock;
        case _ProductsFilter.hidden:
          return item.status == ProductStatus.inactive ||
              item.visibilityStatus == ProductVisibilityStatus.hidden;
      }
    }).toList(growable: false);
    final normalizedQuery = normalizeProductName(query);
    final filtered = filteredByTab.where((item) {
      if (normalizedQuery.isEmpty) return true;
      return item.normalizedName.contains(normalizedQuery) ||
          normalizeProductName(item.name).contains(normalizedQuery);
    }).toList();

    switch (sort) {
      case _ProductsSortOption.recents:
        filtered.sort((a, b) {
          final bDate = b.updatedAt ?? b.createdAt ?? DateTime(1970);
          final aDate = a.updatedAt ?? a.createdAt ?? DateTime(1970);
          return bDate.compareTo(aDate);
        });
        break;
      case _ProductsSortOption.nameAsc:
        filtered.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case _ProductsSortOption.priceAsc:
        filtered.sort((a, b) {
          final aPrice = _parsePriceLike(a.priceLabel);
          final bPrice = _parsePriceLike(b.priceLabel);
          return aPrice.compareTo(bPrice);
        });
        break;
    }
    return filtered;
  }

  double _parsePriceLike(String label) {
    final clean = label.replaceAll(RegExp(r'[^0-9,.]'), '').replaceAll('.', '');
    final normalized = clean.replaceAll(',', '.');
    return double.tryParse(normalized) ?? 999999999;
  }

  void _listenMutationErrors(ProductMutationState state) {
    if (state.errorMessage == null) {
      _lastMutationError = null;
      return;
    }
    final error = state.errorMessage;
    if (error == null || error == _lastMutationError) return;
    _lastMutationError = error;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AppToast.show(
        context,
        message: error,
        type: ToastType.error,
      );
      ref.read(productMutationProvider.notifier).clearError();
    });
  }

  Future<void> _handleCreateTap({
    required String merchantId,
    required OwnerCatalogCapacity? capacity,
    required bool policyEnabled,
    required bool hardBlockEnabled,
    required bool createViaCfEnabled,
    required List<MerchantProduct> products,
  }) async {
    if (!createViaCfEnabled) {
      if (!mounted) return;
      AppToast.show(
        context,
        message:
            'La creación de productos está temporalmente deshabilitada por configuración.',
        type: ToastType.error,
      );
      return;
    }

    final isBlocked =
        policyEnabled && hardBlockEnabled && (capacity?.isBlocked ?? false);
    if (isBlocked) {
      final fallbackProducts =
          ref.read(merchantProductsProvider(merchantId)).valueOrNull ??
              const <MerchantProduct>[];
      final productsForSelector =
          products.isNotEmpty ? products : fallbackProducts;
      await OwnerProductsAnalytics.logProductCreateBlockedByLimit(
        merchantId: merchantId,
        used: capacity?.used ?? 0,
        limit: capacity?.limit ?? 0,
        source: capacity?.source.value ?? 'global_default',
      );
      if (!mounted) return;
      await _openHideSelectorForBlockedCatalog(
        merchantId: merchantId,
        ownerUserId: _ownerUserIdFromAuthState(),
        products: productsForSelector,
      );
      return;
    }
    if (!mounted) return;
    context.push(AppRoutes.ownerProductsNew);
  }

  String _ownerUserIdFromAuthState() {
    final authState = ref.read(authNotifierProvider).authState;
    if (authState is! AuthAuthenticated) return '';
    return normalizeProductField(authState.user.uid);
  }

  void _goToEdit(BuildContext context, String productId) {
    context.push(AppRoutes.ownerProductsEditPath(productId));
  }

  Future<void> _showContactAdminDialog({
    required String merchantId,
  }) async {
    await OwnerProductsAnalytics.logCatalogContactAdmin(
      merchantId: merchantId,
      source: 'owner_products',
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Contactar administración'),
          content: const Text(
            'Tu comercio alcanzó el cupo actual del catálogo. '
            'Contactá al equipo de administración por los canales habituales para ampliar el límite.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendido'),
            ),
          ],
        );
      },
    );
  }

  void _trackCatalogCapacityEvents({
    required String merchantId,
    required OwnerCatalogCapacity? capacity,
  }) {
    if (capacity == null) return;

    if (capacity.isWarning) {
      final warningKey =
          '$merchantId:${capacity.used}:${capacity.limit}:warning';
      if (warningKey != _lastLimitWarningKey) {
        _lastLimitWarningKey = warningKey;
        unawaited(
          OwnerProductsAnalytics.logCatalogLimitWarningSeen(
            merchantId: merchantId,
            used: capacity.used,
            limit: capacity.limit,
            source: capacity.source.value,
          ),
        );
      }
    } else {
      _lastLimitWarningKey = null;
    }

    if (capacity.isBlocked) {
      final blockedKey =
          '$merchantId:${capacity.used}:${capacity.limit}:blocked';
      if (blockedKey != _lastLimitBlockedKey) {
        _lastLimitBlockedKey = blockedKey;
        unawaited(
          OwnerProductsAnalytics.logCatalogLimitBlockSeen(
            merchantId: merchantId,
            used: capacity.used,
            limit: capacity.limit,
            source: capacity.source.value,
          ),
        );
      }
    } else {
      _lastLimitBlockedKey = null;
    }
  }

  Future<void> _setStockStatus(
    BuildContext context, {
    required MerchantProduct product,
    required ProductStockStatus stockStatus,
    required String ownerUserId,
  }) async {
    final success =
        await ref.read(productMutationProvider.notifier).setStockStatus(
              product: product,
              stockStatus: stockStatus,
              actorUserId: ownerUserId,
            );
    if (!success || !context.mounted) return;
    AppToast.show(
      context,
      message: stockStatus == ProductStockStatus.outOfStock
          ? 'Marcado como agotado.'
          : 'Marcado como disponible.',
      type: ToastType.success,
    );
  }

  Future<void> _confirmDeactivate(
    BuildContext context, {
    required MerchantProduct product,
    required String ownerUserId,
  }) async {
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.neutral100,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Icon(
                    Icons.visibility_off_outlined,
                    color: AppColors.neutral700,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  '¿Ocultar este producto?',
                  style: AppTextStyles.headingSm,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'No se va a mostrar a los Vecinos, pero lo podés volver a activar cuando quieras.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySm,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary500,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Ocultar producto'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.neutral200,
                      foregroundColor: AppColors.neutral900,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (accepted != true || !context.mounted) return;

    final success = await ref.read(productMutationProvider.notifier).deactivate(
          product: product,
          actorUserId: ownerUserId,
        );
    if (!success || !context.mounted) return;

    AppToast.show(
      context,
      message: 'Producto oculto.',
      type: ToastType.success,
    );
  }

  Future<void> _confirmReactivate(
    BuildContext context, {
    required MerchantProduct product,
    required String ownerUserId,
  }) async {
    final success = await ref.read(productMutationProvider.notifier).reactivate(
          product: product,
          actorUserId: ownerUserId,
        );
    if (!success || !context.mounted) return;
    AppToast.show(
      context,
      message: 'Volvió a mostrarse en Tu zona.',
      type: ToastType.success,
    );
  }

  Future<void> _confirmDelete(
    BuildContext context, {
    required MerchantProduct product,
    required String ownerUserId,
  }) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.errorBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Icon(
                  Icons.delete_outline,
                  color: AppColors.errorFg,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                '¿Eliminar producto?',
                style: AppTextStyles.headingSm,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Esta acción no se puede deshacer. Si solo querés que no se vea, te conviene ocultarlo.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySm,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary500,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Ocultar en vez de eliminar'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.errorBg,
                    foregroundColor: AppColors.errorFg,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Eliminar igual'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (accepted != true || !context.mounted) return;
    final success = await ref.read(productMutationProvider.notifier).deactivate(
          product: product,
          actorUserId: ownerUserId,
        );
    if (!success || !context.mounted) return;
    AppToast.show(
      context,
      message: 'Producto eliminado del catálogo activo.',
      type: ToastType.success,
    );
  }

  Future<void> _openHideSelectorForBlockedCatalog({
    required String merchantId,
    required String ownerUserId,
    required List<MerchantProduct> products,
  }) async {
    final parentContext = context;
    final normalizedOwnerId = normalizeProductField(ownerUserId);
    if (normalizedOwnerId.isEmpty) {
      AppToast.show(
        context,
        message: 'No pudimos validar tu sesión. Volvé a iniciar.',
        type: ToastType.error,
      );
      return;
    }
    final activeProducts = products
        .where((item) =>
            item.status == ProductStatus.active &&
            item.visibilityStatus == ProductVisibilityStatus.visible)
        .toList(growable: false);
    if (activeProducts.isEmpty) {
      AppToast.show(
        context,
        message: 'No hay productos activos para ocultar.',
        type: ToastType.error,
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Elegí un producto para ocultar',
                  style: AppTextStyles.headingSm,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Para cargar otro, ocultá alguno que ya no quieras mostrar en Tu zona.',
                  style: AppTextStyles.bodySm,
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: activeProducts.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: AppColors.neutral100),
                    itemBuilder: (context, index) {
                      final item = activeProducts[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.labelMd,
                        ),
                        subtitle: Text(
                          item.displayPriceLabel,
                          style: AppTextStyles.bodyXs.copyWith(
                            color: AppColors.neutral600,
                          ),
                        ),
                        trailing: TextButton(
                          onPressed: () async {
                            Navigator.of(context).pop();
                            final success = await ref
                                .read(productMutationProvider.notifier)
                                .deactivate(
                                  product: item,
                                  actorUserId: normalizedOwnerId,
                                );
                            if (!mounted || !parentContext.mounted || !success)
                              return;
                            AppToast.show(
                              parentContext,
                              message:
                                  'Producto oculto. Ya podés agregar uno nuevo.',
                              type: ToastType.success,
                            );
                            await OwnerProductsAnalytics
                                .logCatalogLimitBlockSeen(
                              merchantId: merchantId,
                              used: activeProducts.length - 1,
                              limit: activeProducts.length,
                              source: 'owner_products',
                            );
                          },
                          child: const Text('Ocultar'),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Shell extends StatelessWidget {
  const _Shell({
    required this.child,
    this.onFabPressed,
  });

  final Widget child;
  final VoidCallback? onFabPressed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
              return;
            }
            context.go(AppRoutes.ownerDashboard);
          },
          icon: const Icon(Icons.arrow_back, color: AppColors.primary500),
        ),
        title: const Text('Tus productos', style: AppTextStyles.headingSm),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary100,
              child: Icon(Icons.person, color: AppColors.primary700, size: 18),
            ),
          ),
        ],
      ),
      floatingActionButton: onFabPressed == null
          ? null
          : FloatingActionButton(
              backgroundColor: AppColors.primary500,
              foregroundColor: Colors.white,
              onPressed: onFabPressed,
              child: const Icon(Icons.add),
            ),
      body: child,
    );
  }
}

class _HeaderBlock extends StatelessWidget {
  const _HeaderBlock({
    required this.onAddPressed,
    required this.capacity,
    required this.policyEnabled,
    required this.hardBlockEnabled,
    required this.onContactAdmin,
  });

  final VoidCallback onAddPressed;
  final OwnerCatalogCapacity? capacity;
  final bool policyEnabled;
  final bool hardBlockEnabled;
  final VoidCallback onContactAdmin;

  @override
  Widget build(BuildContext context) {
    final isBlocked =
        policyEnabled && hardBlockEnabled && (capacity?.isBlocked ?? false);
    final isWarning = policyEnabled && (capacity?.isWarning ?? false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tus productos',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 44,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: AppColors.neutral900,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Mantené actualizado lo que mostrás en Tu zona.',
          style: AppTextStyles.bodyMd.copyWith(
            color: AppColors.neutral700,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (policyEnabled && capacity != null) ...[
          const SizedBox(height: 14),
          _CatalogCapacityCard(
            capacity: capacity!,
            isHardBlocked: isBlocked,
            onContactAdmin: onContactAdmin,
          ),
        ],
        if (isWarning && !isBlocked) ...[
          const SizedBox(height: 10),
          const _InlineNotice(
            color: AppColors.warningFg,
            background: AppColors.warningBg,
            icon: Icons.warning_amber_rounded,
            text: 'Te queda poco lugar para productos activos.',
          ),
        ],
        if (isBlocked) ...[
          const SizedBox(height: 10),
          const _InlineNotice(
            color: AppColors.errorFg,
            background: AppColors.errorBg,
            icon: Icons.block_rounded,
            text:
                'Llegaste al máximo de productos activos. Para cargar otro, ocultá alguno que ya no quieras mostrar en Tu zona.',
          ),
        ],
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0044AA), Color(0xFF0E5BD8)],
              ),
            ),
            child: ElevatedButton.icon(
              onPressed: onAddPressed,
              icon: const Icon(Icons.add, size: 18),
              label: const Text(
                'Agregar producto',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CatalogCapacityCard extends StatelessWidget {
  const _CatalogCapacityCard({
    required this.capacity,
    required this.isHardBlocked,
    required this.onContactAdmin,
  });

  final OwnerCatalogCapacity capacity;
  final bool isHardBlocked;
  final VoidCallback onContactAdmin;

  @override
  Widget build(BuildContext context) {
    final progress = capacity.usageRatio.clamp(0, 1).toDouble();
    final progressColor = isHardBlocked
        ? AppColors.errorFg
        : (capacity.isWarning ? AppColors.warningFg : AppColors.primary500);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHardBlocked
              ? AppColors.errorFg.withValues(alpha: 0.25)
              : AppColors.neutral200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Capacidad de catálogo',
            style: AppTextStyles.labelMd.copyWith(
              color: AppColors.neutral800,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${capacity.used}/${capacity.limit} usados · ${capacity.remaining} restantes',
            style: AppTextStyles.bodySm.copyWith(
              color: AppColors.neutral700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: progress,
              color: progressColor,
              backgroundColor: AppColors.neutral200,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                'Uso: ${capacity.usagePercent}%',
                style: AppTextStyles.bodyXs.copyWith(
                  color: AppColors.neutral600,
                ),
              ),
              const Spacer(),
              Text(
                'Fuente: ${capacity.source.label}',
                style: AppTextStyles.bodyXs.copyWith(
                  color: AppColors.neutral600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (isHardBlocked || capacity.isWarning) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onContactAdmin,
              icon: const Icon(Icons.support_agent, size: 16),
              label: const Text('Contactar administración'),
              style: TextButton.styleFrom(
                foregroundColor:
                    isHardBlocked ? AppColors.errorFg : AppColors.warningFg,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({
    required this.color,
    required this.background,
    required this.icon,
    required this.text,
  });

  final Color color;
  final Color background;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodyXs.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LimitBlockedPanel extends StatelessWidget {
  const _LimitBlockedPanel({
    required this.capacity,
    required this.onChooseProductToHide,
    required this.onBackToCatalog,
  });

  final OwnerCatalogCapacity? capacity;
  final VoidCallback onChooseProductToHide;
  final VoidCallback onBackToCatalog;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.errorBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Llegaste al máximo de productos activos',
            style: AppTextStyles.labelMd.copyWith(
              color: AppColors.errorFg,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Para cargar otro, ocultá alguno que ya no quieras mostrar en Tu zona.',
            style: AppTextStyles.bodySm.copyWith(
              color: AppColors.errorFg,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (capacity != null) ...[
            const SizedBox(height: 8),
            Text(
              '${capacity!.used} de ${capacity!.limit} productos activos',
              style: AppTextStyles.bodyXs.copyWith(
                color: AppColors.errorFg,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onChooseProductToHide,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorFg,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: const Text('Elegir producto para ocultar'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: onBackToCatalog,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.errorFg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: const Text('Volver a mi catálogo'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchAndSortBlock extends StatelessWidget {
  const _SearchAndSortBlock({
    required this.searchController,
    required this.onSearchChanged,
    required this.productsCount,
    required this.sort,
    required this.onSortChanged,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final int productsCount;
  final _ProductsSortOption sort;
  final ValueChanged<_ProductsSortOption?> onSortChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.neutral100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Buscar productos...',
              prefixIcon: const Icon(Icons.search, color: AppColors.neutral500),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                '$productsCount PRODUCTOS',
                style: AppTextStyles.labelSm.copyWith(
                  color: AppColors.neutral600,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.3,
                ),
              ),
              const Spacer(),
              Text(
                'ORDENAR:',
                style: AppTextStyles.labelSm.copyWith(
                  color: AppColors.neutral600,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              DropdownButtonHideUnderline(
                child: DropdownButton<_ProductsSortOption>(
                  value: sort,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                  items: _ProductsSortOption.values.map((item) {
                    return DropdownMenuItem<_ProductsSortOption>(
                      value: item,
                      child: Text(
                        item.label,
                        style: AppTextStyles.labelSm.copyWith(
                          color: AppColors.primary500,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: onSortChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.selected,
    required this.onSelected,
  });

  final _ProductsFilter selected;
  final ValueChanged<_ProductsFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _ProductsFilter.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = _ProductsFilter.values[index];
          final isSelected = item == selected;
          return ChoiceChip(
            label: Text(item.label),
            selected: isSelected,
            onSelected: (_) => onSelected(item),
          );
        },
      ),
    );
  }
}

class _FilterSkeleton extends StatelessWidget {
  const _FilterSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, __) => Container(
          width: 96,
          decoration: BoxDecoration(
            color: AppColors.neutral200,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}

class _CatalogLoadingSkeleton extends StatelessWidget {
  const _CatalogLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(3, (index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.neutral200),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.neutral100,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 14,
                      width: 160,
                      decoration: BoxDecoration(
                        color: AppColors.neutral200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 12,
                      width: 90,
                      decoration: BoxDecoration(
                        color: AppColors.neutral100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 34,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.neutral100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _NoResultsState extends StatelessWidget {
  const _NoResultsState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        children: [
          const Icon(Icons.search_off, color: AppColors.neutral500),
          const SizedBox(height: 8),
          Text(
            'No encontramos productos con esa búsqueda.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySm.copyWith(color: AppColors.neutral700),
          ),
        ],
      ),
    );
  }
}

class _LoadErrorState extends StatelessWidget {
  const _LoadErrorState({
    required this.title,
    required this.message,
    required this.ctaLabel,
    this.onRetry,
  });

  final String title;
  final String message;
  final String ctaLabel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Transform.rotate(
                  angle: 0.08,
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      color: AppColors.neutral100,
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                Transform.rotate(
                  angle: -0.08,
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      color: AppColors.neutral100.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Container(
                        width: 82,
                        height: 82,
                        decoration: BoxDecoration(
                          color: AppColors.errorBg,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Icon(
                          Icons.cloud_off_outlined,
                          color: AppColors.errorFg,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: -10,
                  right: -10,
                  child: Transform.rotate(
                    angle: 0.3,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.tertiary100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.wifi_off_rounded,
                        color: AppColors.tertiary700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: AppTextStyles.headingLg.copyWith(
                fontSize: 44,
                height: 1.05,
                letterSpacing: -0.6,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.neutral700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0044AA), Color(0xFF0E5BD8)],
                  ),
                ),
                child: ElevatedButton(
                  onPressed: onRetry ??
                      () {
                        if (context.canPop()) {
                          context.pop();
                        }
                      },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    ctaLabel,
                    style: AppTextStyles.labelMd.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
