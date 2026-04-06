import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class ProductDetailPage extends StatelessWidget {
  const ProductDetailPage({
    super.key,
    required this.merchantId,
    required this.productId,
  });

  final String merchantId;
  final String productId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: const Text('Producto'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Detalle de producto',
              style: AppTextStyles.headingMd,
            ),
            const SizedBox(height: 8),
            Text('merchantId: $merchantId', style: AppTextStyles.bodySm),
            const SizedBox(height: 4),
            Text('productId: $productId', style: AppTextStyles.bodySm),
          ],
        ),
      ),
    );
  }
}
