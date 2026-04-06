import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../domain/merchant_detail_view_data.dart';

class MerchantOperationalBadge extends StatelessWidget {
  const MerchantOperationalBadge({
    super.key,
    required this.badge,
  });

  final MerchantOperationalBadgeViewData badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: badge.backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        badge.label,
        style: AppTextStyles.labelSm.copyWith(
          color: badge.foregroundColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
