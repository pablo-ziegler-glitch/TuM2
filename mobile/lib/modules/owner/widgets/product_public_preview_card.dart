import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/merchant_product.dart';

class ProductPublicPreviewCard extends StatelessWidget {
  const ProductPublicPreviewCard({
    super.key,
    required this.name,
    required this.priceLabel,
    required this.stockStatus,
    required this.visibilityStatus,
    required this.status,
    required this.imageProvider,
  });

  final String name;
  final String priceLabel;
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

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.neutral100),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 64,
              height: 64,
              color: AppColors.neutral100,
              child: imageProvider == null
                  ? const Icon(Icons.image_outlined,
                      color: AppColors.neutral500)
                  : Image(
                      image: imageProvider!,
                      fit: BoxFit.cover,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  normalizeProductField(name).isEmpty
                      ? 'Nombre del producto'
                      : normalizeProductField(name),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelMd.copyWith(
                    color: AppColors.neutral900,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  normalizeProductField(priceLabel).isEmpty
                      ? 'Precio visible'
                      : normalizeProductField(priceLabel),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.neutral700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  visibilityLabel,
                  style: AppTextStyles.bodyXs.copyWith(
                    color: canBeVisible
                        ? AppColors.successFg
                        : AppColors.warningFg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (stockStatus == ProductStockStatus.outOfStock)
                  Text(
                    'Sin stock',
                    style: AppTextStyles.bodyXs.copyWith(
                      color: AppColors.warningFg,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (status == ProductStatus.inactive)
                  Text(
                    'Inactivo',
                    style: AppTextStyles.bodyXs.copyWith(
                      color: AppColors.errorFg,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
