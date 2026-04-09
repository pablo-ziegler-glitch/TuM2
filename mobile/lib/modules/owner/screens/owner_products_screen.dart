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
import '../models/merchant_product.dart';
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

class OwnerProductsScreen extends ConsumerStatefulWidget {
  const OwnerProductsScreen({super.key});

  @override
  ConsumerState<OwnerProductsScreen> createState() =>
      _OwnerProductsScreenState();
}

class _OwnerProductsScreenState extends ConsumerState<OwnerProductsScreen> {
  String? _lastMutationError;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  _ProductsSortOption _sortOption = _ProductsSortOption.recents;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider).authState;
    final ownerProductsEnabledAsync = ref.watch(ownerProductsEnabledProvider);
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

            final productsAsync =
                ref.watch(merchantProductsProvider(merchant.id));

            return _Shell(
              onFabPressed: () => _goToCreate(context),
              child: Column(
                children: [
                  Expanded(
                    child: productsAsync.when(
                      loading: _buildLoadingContent,
                      error: (_, __) => _LoadErrorState(
                        title: 'No pudimos cargar tu catálogo',
                        message: 'Revisá tu conexión e intentá de nuevo.',
                        ctaLabel: 'Reintentar',
                        onRetry: () => ref
                            .invalidate(merchantProductsProvider(merchant.id)),
                      ),
                      data: (products) {
                        final filtered = _applyFilters(products,
                            query: _searchQuery, sort: _sortOption);
                        if (products.isEmpty) {
                          return _buildEmptyState(context);
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
                                onAddPressed: () => _goToCreate(context),
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
                                          isBusy: mutationState
                                                  .isVisibilityLoading(
                                                filtered[index].id,
                                              ) ||
                                              mutationState.isDeactivateLoading(
                                                filtered[index].id,
                                              ),
                                          onVisibilityChanged: (visible) {
                                            _confirmToggleVisibility(
                                              context,
                                              product: filtered[index],
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
                                              onToggleVisibility: () =>
                                                  _confirmToggleVisibility(
                                                context,
                                                product: filtered[index],
                                                ownerUserId: ownerUserId,
                                              ),
                                              onDeactivate: () =>
                                                  _confirmDeactivate(
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

  Widget _buildLoadingContent() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        _HeaderBlock(onAddPressed: () => _goToCreate(context)),
        const SizedBox(height: 14),
        _SearchAndSortBlock(
          searchController: _searchController,
          onSearchChanged: (_) {},
          productsCount: 0,
          sort: _sortOption,
          onSortChanged: (_) {},
        ),
        const SizedBox(height: 16),
        const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(color: AppColors.primary500),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        _HeaderBlock(onAddPressed: () => _goToCreate(context)),
        const SizedBox(height: 18),
        ProductEmptyState(
          onAddPressed: () => _goToCreate(context),
        ),
      ],
    );
  }

  List<MerchantProduct> _applyFilters(
    List<MerchantProduct> items, {
    required String query,
    required _ProductsSortOption sort,
  }) {
    final normalizedQuery = normalizeProductName(query);
    final filtered = items.where((item) {
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

  void _goToCreate(BuildContext context) {
    context.push(AppRoutes.ownerProductsNew);
  }

  void _goToEdit(BuildContext context, String productId) {
    context.push(AppRoutes.ownerProductsEditPath(productId));
  }

  Future<void> _confirmToggleVisibility(
    BuildContext context, {
    required MerchantProduct product,
    required String ownerUserId,
  }) async {
    final shouldHide =
        product.visibilityStatus == ProductVisibilityStatus.visible;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(shouldHide ? 'Ocultar producto' : 'Mostrar producto'),
          content: Text(
            shouldHide
                ? 'El producto quedará oculto y no aparecerá en tu ficha pública.'
                : 'El producto volverá a verse en tu ficha pública.',
            style: AppTextStyles.bodySm,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(shouldHide ? 'Ocultar' : 'Mostrar'),
            ),
          ],
        );
      },
    );

    if (accepted != true || !context.mounted) return;
    final success =
        await ref.read(productMutationProvider.notifier).toggleVisibility(
              product: product,
              actorUserId: ownerUserId,
            );
    if (!success || !context.mounted) return;

    AppToast.show(
      context,
      message: shouldHide
          ? 'El producto quedó oculto. Podés volver a mostrarlo cuando quieras.'
          : 'El producto vuelve a estar visible para los vecinos.',
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
                    color: AppColors.errorBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Icon(Icons.archive_outlined,
                      color: AppColors.errorFg),
                ),
                const SizedBox(height: 14),
                const Text(
                  '¿Eliminar este producto?',
                  style: AppTextStyles.headingSm,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Este producto dejará de aparecer en tu catálogo. No se elimina para siempre, podés recuperarlo luego.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySm,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.errorFg,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Dar de baja'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
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
      message: 'El producto se dio de baja y ya no aparece públicamente.',
      type: ToastType.success,
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
          icon: const Icon(Icons.menu, color: AppColors.primary500),
        ),
        title: const Text('Productos', style: AppTextStyles.headingSm),
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
  const _HeaderBlock({required this.onAddPressed});

  final VoidCallback onAddPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Productos',
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
          'Mostrá lo que ofrecés hoy a tus vecinos',
          style: AppTextStyles.bodyMd.copyWith(
            color: AppColors.neutral700,
            fontWeight: FontWeight.w500,
          ),
        ),
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
                '+ Agregar producto',
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
