import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/merchant_product.dart';

class ProductPublicPreviewCard extends StatelessWidget {
  const ProductPublicPreviewCard({
    super.key,
    required this.merchantName,
    required this.name,
    required this.description,
    required this.priceLabel,
    required this.priceMode,
    required this.stockStatus,
    required this.visibilityStatus,
    required this.status,
    required this.imageProvider,
  });

  final String merchantName;
  final String name;
  final String description;
  final String priceLabel;
  final ProductPriceMode priceMode;
  final ProductStockStatus stockStatus;
  final ProductVisibilityStatus visibilityStatus;
  final ProductStatus status;
  final ImageProvider<Object>? imageProvider;

  @override
  Widget build(BuildContext context) {
    final canBeVisible = status == ProductStatus.active &&
        visibilityStatus == ProductVisibilityStatus.visible;
    final visibilityLabel =
        canBeVisible ? 'Los vecinos lo pueden ver' : 'Solo lo ves vos';
    final resolvedPrice = switch (priceMode) {
      ProductPriceMode.consult => 'Consultar precio',
      ProductPriceMode.none => 'Sin precio visible',
      ProductPriceMode.fixed => normalizeProductField(priceLabel).isEmpty
          ? 'Sin precio visible'
          : normalizeProductField(priceLabel),
    };
    final resolvedDescription = normalizeProductField(description);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.merchantSurfaceLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            resolvedPrice,
            style: AppTextStyles.headingLg.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.neutral900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            normalizeProductField(name).isEmpty
                ? 'Nombre del producto'
                : normalizeProductField(name),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.headingSm.copyWith(
              color: AppColors.neutral900,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              width: double.infinity,
              height: 220,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: AppColors.neutral200,
                    child: imageProvider == null
                        ? const Icon(
                            Icons.inventory_2_outlined,
                            color: AppColors.neutral500,
                            size: 56,
                          )
                        : Image(
                            image: imageProvider!,
                            fit: BoxFit.cover,
                          ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: canBeVisible
                            ? AppColors.secondary100
                            : AppColors.tertiary100.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        stockStatus == ProductStockStatus.outOfStock
                            ? 'Agotado'
                            : 'Disponible',
                        style: AppTextStyles.labelSm.copyWith(
                          color: canBeVisible
                              ? AppColors.secondary700
                              : AppColors.tertiary800,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (resolvedDescription.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              resolvedDescription,
              style: AppTextStyles.bodySm.copyWith(
                color: AppColors.neutral700,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.storefront,
                size: 16,
                color: AppColors.neutral600,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  normalizeProductField(merchantName).isEmpty
                      ? 'Tu comercio'
                      : normalizeProductField(merchantName),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelSm.copyWith(
                    color: AppColors.neutral700,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                visibilityLabel,
                style: AppTextStyles.bodyXs.copyWith(
                  color:
                      canBeVisible ? AppColors.successFg : AppColors.warningFg,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Información cargada por el comercio',
            style: AppTextStyles.bodyXs.copyWith(
              color: AppColors.neutral600,
            ),
          ),
        ],
      ),
    );
  }
}
