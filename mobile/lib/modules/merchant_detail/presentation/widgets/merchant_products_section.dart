import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/merchant_detail_view_data.dart';
import '../merchant_detail_copy.dart';

class MerchantProductsSection extends StatelessWidget {
  const MerchantProductsSection({
    super.key,
    required this.products,
    required this.onProductTap,
  });

  final AsyncValue<List<MerchantProductViewData>> products;
  final void Function(MerchantProductViewData product) onProductTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Productos destacados', style: AppTextStyles.headingSm),
            const Spacer(),
            Text(
              'Ver todo',
              style: AppTextStyles.labelSm.copyWith(
                color: AppColors.primary600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        products.when(
          loading: _buildLoading,
          error: (_, __) => _buildSoftError(),
          data: (items) {
            if (items.isEmpty) return _buildEmptyState();
            return _buildList(items);
          },
        ),
      ],
    );
  }

  Widget _buildLoading() {
    return SizedBox(
      height: 138,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, __) => Container(
          width: 180,
          decoration: BoxDecoration(
            color: AppColors.neutral100,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildSoftError() {
    return const Text(
      'No pudimos cargar productos destacados por ahora.',
      style: AppTextStyles.bodySm,
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.neutral300,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.neutral100,
              borderRadius: BorderRadius.circular(32),
            ),
            child: const Icon(
              Icons.shopping_bag_outlined,
              color: AppColors.neutral500,
              size: 30,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Selección en proceso',
            style: AppTextStyles.labelMd.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            MerchantDetailCopy.emptyProducts,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySm,
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<MerchantProductViewData> items) {
    return SizedBox(
      height: 138,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, index) {
          final product = items[index];
          return InkWell(
            key: Key('merchant_product_card_${product.productId}'),
            onTap: () => onProductTap(product),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 188,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.neutral200),
              ),
              child: Row(
                children: [
                  _ProductThumb(imageUrl: product.imageUrl),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          product.name,
                          style: AppTextStyles.labelMd,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (product.priceLabel.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            product.priceLabel,
                            style: AppTextStyles.bodySm.copyWith(
                              color: AppColors.primary600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProductThumb extends StatelessWidget {
  const _ProductThumb({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.neutral100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.inventory_2_outlined,
          color: AppColors.neutral500,
          size: 20,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        imageUrl!,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.neutral100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.inventory_2_outlined,
            color: AppColors.neutral500,
            size: 20,
          ),
        ),
      ),
    );
  }
}
