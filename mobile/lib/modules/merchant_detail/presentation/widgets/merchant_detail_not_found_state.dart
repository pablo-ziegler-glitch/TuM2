import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../merchant_detail_copy.dart';

class MerchantDetailNotFoundState extends StatelessWidget {
  const MerchantDetailNotFoundState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('merchant_detail_not_found_state'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 170,
                  height: 170,
                  decoration: BoxDecoration(
                    color: AppColors.neutral100,
                    borderRadius: BorderRadius.circular(36),
                  ),
                ),
                const Icon(
                  Icons.storefront_outlined,
                  size: 72,
                  color: AppColors.neutral400,
                ),
                Positioned(
                  bottom: 48,
                  right: 48,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      Icons.search_off,
                      color: AppColors.primary500,
                      size: 26,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              MerchantDetailCopy.notFound,
              textAlign: TextAlign.center,
              style: AppTextStyles.headingMd,
            ),
            const SizedBox(height: 12),
            Text(
              'Lo sentimos, el perfil fue desactivado o el enlace no es válido.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.neutral700,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).maybePop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary500,
                foregroundColor: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                elevation: 0,
              ),
              icon: const Icon(Icons.explore_outlined, size: 18),
              label: const Text('Volver a buscar'),
            ),
          ],
        ),
      ),
    );
  }
}
