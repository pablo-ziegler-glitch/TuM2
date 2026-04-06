import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../domain/merchant_detail_view_data.dart';

class MerchantTrustBadges extends StatelessWidget {
  const MerchantTrustBadges({
    super.key,
    required this.badges,
  });

  final List<MerchantTrustBadgeViewData> badges;

  @override
  Widget build(BuildContext context) {
    if (badges.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: badges
          .map(
            (badge) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: badge.backgroundColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                badge.label,
                style: AppTextStyles.labelSm.copyWith(
                  color: badge.foregroundColor,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}
