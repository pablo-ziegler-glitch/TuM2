import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../product/presentation/providers/product_providers.dart';
import '../providers/store_providers.dart';

class PublicStoreScreen extends ConsumerWidget {
  final String storeId;

  const PublicStoreScreen({super.key, required this.storeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storeAsync = ref.watch(storeDetailProvider(storeId));
    final productsAsync = ref.watch(storeProductsProvider(storeId));

    return Scaffold(
      body: storeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (store) {
          if (store == null) {
            return const Center(child: Text('Comercio no encontrado'));
          }

          return CustomScrollView(
            slivers: [
              // App bar with store image
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: store.imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: store.imageUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            color: TuM2Colors.surfaceVariant,
                            child: const Icon(Icons.storefront, size: 64,
                                color: TuM2Colors.onSurfaceVariant),
                          ),
                        )
                      : Container(
                          color: TuM2Colors.surfaceVariant,
                          child: const Icon(Icons.storefront,
                              size: 64, color: TuM2Colors.onSurfaceVariant),
                        ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name + category
                      Text(store.name, style: TuM2TextStyles.headlineLarge),
                      const SizedBox(height: 4),
                      Text(store.category,
                          style: TuM2TextStyles.bodyMedium
                              .copyWith(color: TuM2Colors.onSurfaceVariant)),
                      const SizedBox(height: 12),

                      // Open status
                      _OpenStatusRow(
                        isOpenNow: store.isOpenNow,
                        isLateNight: store.isLateNightNow,
                        isOnDuty: store.isOnDutyToday,
                        freshnessHours: store.operationalFreshnessHours,
                      ),
                      const SizedBox(height: 16),

                      // Active signals
                      if (store.hasActiveSpecialSignal ||
                          store.isOnDutyToday) ...[
                        _SignalBadges(store: store),
                        const SizedBox(height: 16),
                      ],

                      // Address
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 16, color: TuM2Colors.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(store.address,
                                style: TuM2TextStyles.bodySmall.copyWith(
                                    color: TuM2Colors.onSurfaceVariant)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Description
                      if (store.description.isNotEmpty) ...[
                        Text(store.description, style: TuM2TextStyles.bodyMedium),
                        const SizedBox(height: 16),
                      ],

                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.favorite_outline),
                              label: const Text('Favoritos'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.share_outlined),
                              label: const Text('Compartir'),
                            ),
                          ),
                        ],
                      ),

                      const Divider(height: 40),
                      Text('Productos', style: TuM2TextStyles.titleLarge),
                    ],
                  ),
                ),
              ),

              // Products list
              productsAsync.when(
                loading: () => const SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => const SliverToBoxAdapter(child: SizedBox()),
                data: (products) {
                  if (products.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Este comercio aún no cargó productos.',
                          style: TuM2TextStyles.bodyMedium
                              .copyWith(color: TuM2Colors.onSurfaceVariant),
                        ),
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => _ProductTile(product: products[i]),
                        childCount: products.length,
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.8,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                      ),
                    ),
                  );
                },
              ),

              const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
            ],
          );
        },
      ),
    );
  }
}

class _OpenStatusRow extends StatelessWidget {
  final bool isOpenNow;
  final bool isLateNight;
  final bool isOnDuty;
  final int freshnessHours;

  const _OpenStatusRow({
    required this.isOpenNow,
    required this.isLateNight,
    required this.isOnDuty,
    required this.freshnessHours,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isOpenNow
                ? TuM2Colors.successLight
                : TuM2Colors.errorLight,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isOpenNow
                      ? TuM2Colors.openGreen
                      : TuM2Colors.closedRed,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                isOpenNow ? 'Abierto ahora' : 'Cerrado',
                style: TuM2TextStyles.labelSmall.copyWith(
                  color: isOpenNow
                      ? TuM2Colors.openGreen
                      : TuM2Colors.closedRed,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          TuM2DateUtils.freshnessLabel(freshnessHours),
          style: TuM2TextStyles.bodySmall
              .copyWith(color: TuM2Colors.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _SignalBadges extends StatelessWidget {
  final dynamic store;

  const _SignalBadges({required this.store});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (store.isOnDutyToday)
          _Badge(label: 'Farmacia de turno', color: TuM2Colors.dutyBlue),
        if (store.isLateNightNow)
          _Badge(label: 'Hasta tarde', color: TuM2Colors.lateNightPurple),
        if (store.hasActiveSpecialSignal)
          _Badge(
              label: 'Horario especial', color: TuM2Colors.warning),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
          style: TuM2TextStyles.labelSmall.copyWith(color: color)),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final dynamic product;

  const _ProductTile({required this.product});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: TuM2Colors.outline),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: product.imageUrls?.isNotEmpty == true
                  ? CachedNetworkImage(
                      imageUrl: product.imageUrls.first,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorWidget: (_, __, ___) => Container(
                        color: TuM2Colors.surfaceVariant,
                        child: const Icon(Icons.image_outlined,
                            color: TuM2Colors.onSurfaceVariant),
                      ),
                    )
                  : Container(
                      color: TuM2Colors.surfaceVariant,
                      child: const Icon(Icons.image_outlined,
                          color: TuM2Colors.onSurfaceVariant),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name,
                    style: TuM2TextStyles.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(
                  '\$${product.price.toStringAsFixed(0)}',
                  style: TuM2TextStyles.titleMedium
                      .copyWith(color: TuM2Colors.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
