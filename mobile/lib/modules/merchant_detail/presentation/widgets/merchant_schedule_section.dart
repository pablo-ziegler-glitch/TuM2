import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/merchant_detail_view_data.dart';

class MerchantScheduleSection extends StatelessWidget {
  const MerchantScheduleSection({
    super.key,
    required this.openStatusLabel,
    required this.schedule,
    required this.signals,
  });

  final String openStatusLabel;
  final AsyncValue<MerchantScheduleViewData?> schedule;
  final AsyncValue<List<MerchantOperationalSignalViewData>> signals;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.merchantSurfaceLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Horarios de atención', style: AppTextStyles.headingSm),
          const SizedBox(height: 6),
          Text(
            openStatusLabel,
            style: AppTextStyles.bodySm.copyWith(
              color: AppColors.neutral700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          _SignalsWrap(signals: signals),
          const SizedBox(height: 14),
          schedule.when(
            loading: () => const Text(
              'Cargando horarios del comercio...',
              style: AppTextStyles.bodySm,
            ),
            error: (_, __) => const Text(
              'Horarios no disponibles por ahora.',
              style: AppTextStyles.bodySm,
            ),
            data: (value) {
              if (value == null || value.days.isEmpty) {
                return const Text(
                  'Horarios no disponibles por ahora.',
                  style: AppTextStyles.bodySm,
                );
              }

              return Column(
                children: value.days
                    .map(
                      (day) => Padding(
                        key: Key('merchant_schedule_day_${day.dayKey}'),
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                day.dayLabel,
                                style: AppTextStyles.labelMd.copyWith(
                                  color: day.isToday
                                      ? AppColors.merchantPrimary
                                      : AppColors.merchantOnSurface,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              day.slotsLabel,
                              style: AppTextStyles.bodySm.copyWith(
                                color: day.isToday
                                    ? AppColors.merchantPrimary
                                    : AppColors.merchantOnSurface,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SignalsWrap extends StatelessWidget {
  const _SignalsWrap({
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
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items
              .map(
                (signal) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: signal.isAlert
                        ? AppColors.errorBg
                        : AppColors.merchantSurfaceHighest,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    signal.label,
                    style: AppTextStyles.labelSm.copyWith(
                      color: signal.isAlert
                          ? AppColors.errorFg
                          : AppColors.merchantOnSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}
