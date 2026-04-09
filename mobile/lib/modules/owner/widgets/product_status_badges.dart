import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/merchant_product.dart';

class ProductStatusBadges extends StatelessWidget {
  const ProductStatusBadges({
    super.key,
    required this.product,
  });

  final MerchantProduct product;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _Badge(
          label: product.stockStatus == ProductStockStatus.available
              ? 'Disponible'
              : 'Sin stock',
          backgroundColor: product.stockStatus == ProductStockStatus.available
              ? AppColors.successBg
              : AppColors.warningBg,
          foregroundColor: product.stockStatus == ProductStockStatus.available
              ? AppColors.successFg
              : AppColors.tertiary700,
        ),
        _Badge(
          label: product.visibilityStatus == ProductVisibilityStatus.visible
              ? 'Visible'
              : 'Oculto',
          backgroundColor:
              product.visibilityStatus == ProductVisibilityStatus.visible
                  ? AppColors.primary50
                  : AppColors.neutral100,
          foregroundColor:
              product.visibilityStatus == ProductVisibilityStatus.visible
                  ? AppColors.primary700
                  : AppColors.neutral700,
        ),
        if (product.status == ProductStatus.inactive)
          const _Badge(
            label: 'Inactivo',
            backgroundColor: AppColors.errorBg,
            foregroundColor: AppColors.errorFg,
          ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSm.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
