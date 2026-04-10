import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/merchant_detail_view_data.dart';

class PharmacyDutyBanner extends StatelessWidget {
  const PharmacyDutyBanner({
    super.key,
    required this.duty,
    required this.phonePrimary,
  });

  final AsyncValue<PharmacyDutyViewData?> duty;
  final String? phonePrimary;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('pharmacy_duty_banner'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.tertiary50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.tertiary100),
      ),
      child: duty.when(
        loading: () => _DutyText(
          title: 'Farmacia de turno',
          subtitle: 'Cargando información de guardia...',
          phonePrimary: phonePrimary,
        ),
        error: (_, __) => _DutyText(
          title: 'Farmacia de turno',
          subtitle: 'Información de guardia no disponible',
          phonePrimary: phonePrimary,
        ),
        data: (value) {
          final endsAt = value?.endsAt;
          final subtitle = endsAt == null
              ? 'Horario de finalización no disponible'
              : 'Guardia activa hasta las ${_formatHourMinute(endsAt)}';
          return _DutyText(
            title: 'Farmacia de turno',
            subtitle: subtitle,
            phonePrimary: phonePrimary,
          );
        },
      ),
    );
  }

  static String _formatHourMinute(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _DutyText extends StatelessWidget {
  const _DutyText({
    required this.title,
    required this.subtitle,
    required this.phonePrimary,
  });

  final String title;
  final String subtitle;
  final String? phonePrimary;

  @override
  Widget build(BuildContext context) {
    final phone = (phonePrimary ?? '').trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.labelMd.copyWith(
            color: AppColors.tertiary700,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: AppTextStyles.bodySm.copyWith(
            color: AppColors.neutral700,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (phone.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'Tel: $phone',
            style: AppTextStyles.bodyXs.copyWith(
              color: AppColors.neutral700,
            ),
          ),
        ],
      ],
    );
  }
}
