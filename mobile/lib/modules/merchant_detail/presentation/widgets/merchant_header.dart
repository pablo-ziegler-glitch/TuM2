import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/merchant_detail_view_data.dart';

class MerchantHeader extends StatelessWidget {
  const MerchantHeader({
    super.key,
    required this.merchant,
    required this.badge,
    required this.distanceLabel,
    required this.isDutyVariant,
  });

  final MerchantPublicViewData merchant;
  final MerchantStatusBadgeViewData badge;
  final String? distanceLabel;
  final bool isDutyVariant;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.merchantSurfaceLowest,
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeaderCover(
            coverImageUrl: merchant.coverImageUrl,
            categoryLabel: merchant.categoryLabel,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  merchant.name,
                  style: AppTextStyles.headingMd.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  merchant.categoryLabel,
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.neutral700,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: badge.backgroundColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        badge.label,
                        style: AppTextStyles.labelSm.copyWith(
                          color: badge.foregroundColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if ((distanceLabel ?? '').trim().isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.merchantSurfaceHighest,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          distanceLabel!,
                          style: AppTextStyles.labelSm.copyWith(
                            color: AppColors.neutral700,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    if (isDutyVariant)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.tertiary50,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Farmacia de turno',
                          style: AppTextStyles.labelSm.copyWith(
                            color: AppColors.tertiary700,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 18,
                      color: AppColors.neutral700,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        merchant.address,
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.neutral700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCover extends StatelessWidget {
  const _HeaderCover({
    required this.coverImageUrl,
    required this.categoryLabel,
  });

  final String? coverImageUrl;
  final String categoryLabel;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: AppColors.primary100,
      alignment: Alignment.center,
      child: Text(
        categoryLabel,
        style: AppTextStyles.labelMd.copyWith(
          color: AppColors.primary700,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    if ((coverImageUrl ?? '').trim().isEmpty) {
      return SizedBox(height: 160, width: double.infinity, child: fallback);
    }

    return SizedBox(
      height: 160,
      width: double.infinity,
      child: Image.network(
        coverImageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }
}
