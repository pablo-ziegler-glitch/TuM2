import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../merchant_detail_copy.dart';

class MerchantAddressCtaBlock extends StatelessWidget {
  const MerchantAddressCtaBlock({
    super.key,
    required this.address,
    required this.distanceLabel,
    required this.onHowToGetTap,
  });

  final String address;
  final String? distanceLabel;
  final Future<void> Function() onHowToGetTap;

  @override
  Widget build(BuildContext context) {
    final hasDistance = distanceLabel != null && distanceLabel!.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 136,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.neutral200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              children: [
                Center(
                  child: Icon(
                    Icons.map_outlined,
                    size: 42,
                    color: AppColors.neutral500.withValues(alpha: 0.45),
                  ),
                ),
                Center(
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.primary500,
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(
                        color: AppColors.surface,
                        width: 3,
                      ),
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      color: AppColors.surface,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 18,
                color: AppColors.neutral500,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  address,
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.neutral800,
                  ),
                ),
              ),
            ],
          ),
          if (hasDistance) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.near_me_outlined,
                  size: 16,
                  color: AppColors.neutral500,
                ),
                const SizedBox(width: 8),
                Text(
                  distanceLabel!,
                  style: AppTextStyles.bodyXs.copyWith(
                    color: AppColors.neutral700,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              key: const Key('merchant_how_to_arrive_button'),
              onPressed: onHowToGetTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary600,
                foregroundColor: AppColors.surface,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.directions_outlined, size: 18),
              label: Text(
                MerchantDetailCopy.howToGet,
                style: AppTextStyles.labelMd.copyWith(
                  color: AppColors.surface,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
