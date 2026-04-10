import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class MerchantCtaRow extends StatelessWidget {
  const MerchantCtaRow({
    super.key,
    required this.hasPhone,
    required this.onCallTap,
    required this.onDirectionsTap,
    required this.onShareTap,
    required this.isDutyVariant,
  });

  final bool hasPhone;
  final Future<void> Function() onCallTap;
  final Future<void> Function() onDirectionsTap;
  final Future<void> Function() onShareTap;
  final bool isDutyVariant;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            key: const Key('merchant_cta_call'),
            onPressed: hasPhone ? () => onCallTap() : null,
            icon: const Icon(Icons.call_outlined),
            label: Text(isDutyVariant ? 'Llamar farmacia' : 'Llamar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary500,
              foregroundColor: AppColors.surface,
              padding: const EdgeInsets.symmetric(vertical: 13),
              textStyle: AppTextStyles.labelMd.copyWith(
                fontWeight: FontWeight.w700,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            key: const Key('merchant_cta_directions'),
            onPressed: () => onDirectionsTap(),
            icon: const Icon(Icons.directions_outlined),
            label: const Text('Cómo llegar'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.neutral700,
              side: const BorderSide(color: AppColors.neutral300),
              padding: const EdgeInsets.symmetric(vertical: 13),
              textStyle: AppTextStyles.labelMd.copyWith(
                fontWeight: FontWeight.w700,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        IconButton.filledTonal(
          key: const Key('merchant_cta_share'),
          onPressed: () => onShareTap(),
          icon: const Icon(Icons.share_outlined),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.merchantSurfaceHighest,
            foregroundColor: AppColors.neutral700,
          ),
        ),
      ],
    );
  }
}
