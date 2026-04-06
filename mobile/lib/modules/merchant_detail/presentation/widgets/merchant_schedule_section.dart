import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/merchant_detail_view_data.dart';

class MerchantScheduleSection extends StatelessWidget {
  const MerchantScheduleSection({
    super.key,
    required this.schedule,
    required this.isExpanded,
    required this.onExpandedChanged,
  });

  final AsyncValue<MerchantScheduleViewData?> schedule;
  final bool isExpanded;
  final ValueChanged<bool> onExpandedChanged;

  @override
  Widget build(BuildContext context) {
    return schedule.when(
      loading: () => const _SectionCard(
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text('Cargando horarios...', style: AppTextStyles.bodySm),
          ],
        ),
      ),
      error: (_, __) => const _SectionCard(
        child: Text(
          'No pudimos actualizar los horarios por ahora.',
          style: AppTextStyles.bodySm,
        ),
      ),
      data: (viewData) {
        if (viewData == null || viewData.days.isEmpty) {
          return const _SectionCard(
            child: Text(
              'Horarios no disponibles por ahora.',
              style: AppTextStyles.bodySm,
            ),
          );
        }

        final today = viewData.days.where((day) => day.isToday).toList();
        final todayLabel =
            today.isEmpty ? null : 'Hoy: ${today.first.slotsLabel}';

        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.secondary50,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Horario verificado por el comercio',
                  style: AppTextStyles.bodyXs.copyWith(
                    color: AppColors.secondary700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                ),
                child: ExpansionTile(
                  key: const Key('merchant_schedule_expansion_tile'),
                  initiallyExpanded: isExpanded,
                  tilePadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  onExpansionChanged: onExpandedChanged,
                  title: const Text('Horarios de atención',
                      style: AppTextStyles.headingSm),
                  subtitle: todayLabel == null
                      ? null
                      : Text(
                          todayLabel,
                          style: AppTextStyles.bodyXs,
                        ),
                  children: viewData.days
                      .map(
                        (day) => Container(
                          key: Key('schedule_day_${day.dayKey}'),
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: day.isToday
                                ? AppColors.primary500
                                : AppColors.neutral100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Text(
                                      day.dayLabel,
                                      style: AppTextStyles.labelSm.copyWith(
                                        color: day.isToday
                                            ? AppColors.surface
                                            : AppColors.neutral700,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (day.isToday) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.surface
                                              .withValues(alpha: 0.2),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          'HOY',
                                          style: AppTextStyles.bodyXs.copyWith(
                                            color: AppColors.surface,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                day.slotsLabel,
                                style: AppTextStyles.labelSm.copyWith(
                                  color: day.isToday
                                      ? AppColors.surface
                                      : AppColors.neutral800,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: child,
    );
  }
}
