import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/merchant_detail_view_data.dart';

class MerchantDisclaimer extends StatelessWidget {
  const MerchantDisclaimer({
    super.key,
    required this.merchant,
  });

  final MerchantPublicViewData merchant;

  @override
  Widget build(BuildContext context) {
    final hasRefreshDate = merchant.lastDataRefreshAt != null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.merchantSurfaceLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline,
            color: AppColors.neutral700,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hasRefreshDate
                  ? 'Datos actualizados recientemente. Verificá horarios por teléfono si necesitás confirmación inmediata.'
                  : 'Los datos del comercio pueden cambiar sin aviso. Te recomendamos confirmar antes de ir.',
              style: AppTextStyles.bodySm.copyWith(
                color: AppColors.neutral700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
