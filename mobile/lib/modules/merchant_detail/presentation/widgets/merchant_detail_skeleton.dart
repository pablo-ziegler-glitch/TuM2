import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../merchant_detail_copy.dart';

class MerchantDetailSkeleton extends StatelessWidget {
  const MerchantDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('merchant_detail_loading_state'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(height: 16),
            const Text(
              MerchantDetailCopy.loadingPrimary,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMd,
            ),
            const SizedBox(height: 6),
            Text(
              MerchantDetailCopy.loadingSecondary,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySm.copyWith(
                color: AppColors.neutral600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              MerchantDetailCopy.loadingTertiary,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyXs.copyWith(
                color: AppColors.neutral600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
