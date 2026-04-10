import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/merchant_detail_view_data.dart';

class MerchantFeaturedProductsSection extends StatelessWidget {
  const MerchantFeaturedProductsSection({
    super.key,
    required this.products,
  });

  final AsyncValue<List<MerchantFeaturedProductViewData>> products;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.merchantSurfaceLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Productos destacados', style: AppTextStyles.headingSm),
          const SizedBox(height: 10),
          products.when(
            loading: () => const Text(
              'Cargando productos...',
              style: AppTextStyles.bodySm,
            ),
            error: (_, __) => const Text(
              'No se pudieron cargar los productos.',
              style: AppTextStyles.bodySm,
            ),
            data: (items) {
              if (items.isEmpty) {
                return const Text(
                  'Este comercio todavía no publicó productos destacados.',
                  style: AppTextStyles.bodySm,
                );
              }

              return Column(
                children: items
                    .take(4)
                    .map(
                      (product) => Padding(
                        key: Key(
                          'merchant_featured_product_${product.productId}',
                        ),
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                product.name,
                                style: AppTextStyles.labelMd.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              product.priceLabel,
                              style: AppTextStyles.labelSm.copyWith(
                                color: AppColors.primary500,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }
}
