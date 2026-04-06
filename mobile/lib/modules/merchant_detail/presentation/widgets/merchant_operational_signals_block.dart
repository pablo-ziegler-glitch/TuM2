import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/merchant_detail_view_data.dart';

class MerchantOperationalSignalsBlock extends StatelessWidget {
  const MerchantOperationalSignalsBlock({
    super.key,
    required this.signals,
  });

  final AsyncValue<List<MerchantOperationalSignalViewData>> signals;

  @override
  Widget build(BuildContext context) {
    return signals.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Señales operativas', style: AppTextStyles.headingSm),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 3.1,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemBuilder: (context, index) {
                final signal = items[index];
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: signal.isAlert
                        ? AppColors.errorBg
                        : AppColors.secondary50,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        signal.isAlert
                            ? Icons.error_outline
                            : Icons.check_circle_outline,
                        size: 16,
                        color: signal.isAlert
                            ? AppColors.errorFg
                            : AppColors.secondary700,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          signal.label,
                          style: AppTextStyles.labelSm.copyWith(
                            color: signal.isAlert
                                ? AppColors.errorFg
                                : AppColors.secondary700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
