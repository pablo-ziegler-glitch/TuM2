import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/merchant_detail_view_data.dart';
import 'merchant_operational_badge.dart';

class MerchantDetailHeader extends StatelessWidget {
  const MerchantDetailHeader({
    super.key,
    required this.core,
    required this.trustBadges,
  });

  final MerchantCoreViewData core;
  final List<MerchantTrustBadgeViewData> trustBadges;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HeroBanner(
          operationalBadge: core.operationalBadge,
          trustBadges: trustBadges,
        ),
        const SizedBox(height: 12),
        Text(
          core.categoryLabel,
          style: AppTextStyles.labelSm.copyWith(
            color: AppColors.secondary700,
            letterSpacing: 0.3,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Text(core.name, style: AppTextStyles.headingLg),
      ],
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({
    required this.operationalBadge,
    required this.trustBadges,
  });

  final MerchantOperationalBadgeViewData operationalBadge;
  final List<MerchantTrustBadgeViewData> trustBadges;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    AppColors.primary600,
                    AppColors.primary500,
                    AppColors.secondary500,
                  ],
                ),
              ),
            ),
            Center(
              child: Icon(
                Icons.storefront_rounded,
                color: Colors.white.withValues(alpha: 0.82),
                size: 76,
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  MerchantOperationalBadge(badge: operationalBadge),
                  ...trustBadges.map(_TrustBadgeChip.new),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrustBadgeChip extends StatelessWidget {
  const _TrustBadgeChip(this.badge);

  final MerchantTrustBadgeViewData badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: badge.backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        badge.label,
        style: AppTextStyles.labelSm.copyWith(
          color: badge.foregroundColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
