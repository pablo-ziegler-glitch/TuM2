import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/merchant_product.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.onTapActions,
    required this.onStockStatusChanged,
    this.isBusy = false,
  });

  final MerchantProduct product;
  final VoidCallback onTapActions;
  final ValueChanged<ProductStockStatus> onStockStatusChanged;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final isVisible = product.status == ProductStatus.active &&
        product.visibilityStatus == ProductVisibilityStatus.visible;
    final isInactive = product.status == ProductStatus.inactive;
    final isOutOfStock = product.stockStatus == ProductStockStatus.outOfStock;
    final contentColor =
        isInactive ? AppColors.neutral500 : AppColors.neutral900;
    final priceColor = isInactive ? AppColors.neutral500 : AppColors.primary500;
    final tileColor = isInactive ? AppColors.neutral100 : AppColors.surface;

    return Container(
      color: tileColor,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          _ProductThumb(
            imageUrl: product.imageUrl,
            isInactive: isInactive,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelMd.copyWith(
                    color: contentColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  product.displayPriceLabel.isEmpty
                      ? 'Sin precio'
                      : product.displayPriceLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySm.copyWith(
                    color: priceColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      isOutOfStock ? 'SIN STOCK' : 'DISPONIBLE',
                      style: AppTextStyles.labelSm.copyWith(
                        color: isOutOfStock
                            ? AppColors.tertiary700
                            : AppColors.secondary500,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (isInactive) ...[
                      const SizedBox(width: 6),
                      Text(
                        'INACTIVO',
                        style: AppTextStyles.labelSm.copyWith(
                          color: AppColors.errorFg,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                isInactive ? 'OCULTO' : (isVisible ? 'VISIBLE' : 'PAUSADO'),
                style: AppTextStyles.labelSm.copyWith(
                  color:
                      isVisible ? AppColors.primary500 : AppColors.neutral500,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              FilledButton.tonal(
                onPressed: isBusy || isInactive
                    ? null
                    : () => onStockStatusChanged(
                          isOutOfStock
                              ? ProductStockStatus.available
                              : ProductStockStatus.outOfStock,
                        ),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(
                  isOutOfStock ? 'Marcar disponible' : 'Marcar agotado',
                ),
              ),
            ],
          ),
          const SizedBox(width: 2),
          IconButton(
            tooltip: 'Acciones',
            onPressed: isBusy ? null : onTapActions,
            icon: isBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(
                    Icons.more_vert,
                    color: AppColors.neutral700,
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProductThumb extends StatelessWidget {
  const _ProductThumb({
    required this.imageUrl,
    required this.isInactive,
  });

  final String? imageUrl;
  final bool isInactive;

  @override
  Widget build(BuildContext context) {
    final normalized = (imageUrl ?? '').trim();
    final opacity = isInactive ? 0.5 : 1.0;
    return Opacity(
      opacity: opacity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 44,
          height: 44,
          color: AppColors.neutral100,
          child: normalized.isEmpty
              ? const Icon(
                  Icons.inventory_2_outlined,
                  color: AppColors.neutral500,
                  size: 20,
                )
              : Image.network(
                  normalized,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.low,
                  errorBuilder: (_, __, ___) {
                    return const Icon(
                      Icons.broken_image_outlined,
                      color: AppColors.neutral500,
                      size: 20,
                    );
                  },
                ),
        ),
      ),
    );
  }
}
