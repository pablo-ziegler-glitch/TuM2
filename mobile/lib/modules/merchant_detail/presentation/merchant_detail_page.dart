import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../application/merchant_detail_controller.dart';
import '../application/merchant_detail_error_mapper.dart';
import '../application/merchant_detail_state.dart';
import 'widgets/merchant_cta_row.dart';
import 'widgets/merchant_detail_error_state.dart';
import 'widgets/merchant_detail_not_found_state.dart';
import 'widgets/merchant_detail_skeleton.dart';
import 'widgets/merchant_disclaimer.dart';
import 'widgets/merchant_featured_products_section.dart';
import 'widgets/merchant_header.dart';
import 'widgets/merchant_schedule_section.dart';
import 'widgets/pharmacy_duty_banner.dart';

class MerchantDetailPage extends ConsumerWidget {
  const MerchantDetailPage({
    super.key,
    required this.merchantId,
  });

  final String merchantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(merchantDetailControllerProvider(merchantId));
    final controller =
        ref.read(merchantDetailControllerProvider(merchantId).notifier);
    final state = asyncState.valueOrNull;
    final isDutyVariant = state?.merchant.hasPharmacyDutyToday ?? false;

    return Scaffold(
      backgroundColor: AppColors.merchantSurface,
      appBar: AppBar(
        backgroundColor: AppColors.merchantSurface,
        elevation: 0,
        title: Text(isDutyVariant ? 'Guía Amiga' : 'Editorial'),
        actions: [
          IconButton(
            key: const Key('merchant_appbar_share'),
            icon: const Icon(Icons.share_outlined),
            onPressed: controller.onShareTap,
          ),
        ],
      ),
      body: asyncState.when(
        loading: () => const MerchantDetailSkeleton(),
        error: (error, _) {
          if (error is MerchantDetailNotFoundException) {
            return const MerchantDetailNotFoundState();
          }

          final errorType = classifyMerchantDetailError(error);
          return MerchantDetailErrorState(
            message: errorType == MerchantDetailErrorType.connection
                ? 'No pudimos cargar la ficha. Revisá tu conexión e intentá de nuevo.'
                : 'Este comercio no está disponible por el momento.',
            onRetry: controller.retry,
          );
        },
        data: (state) => _MerchantDetailReady(
          state: state,
          onCallTap: controller.onCallTap,
          onDirectionsTap: controller.onDirectionsTap,
          onShareTap: controller.onShareTap,
        ),
      ),
    );
  }
}

class _MerchantDetailReady extends StatelessWidget {
  const _MerchantDetailReady({
    required this.state,
    required this.onCallTap,
    required this.onDirectionsTap,
    required this.onShareTap,
  });

  final MerchantDetailState state;
  final Future<void> Function() onCallTap;
  final Future<void> Function() onDirectionsTap;
  final Future<void> Function() onShareTap;

  @override
  Widget build(BuildContext context) {
    final isDutyVariant = state.merchant.hasPharmacyDutyToday;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isDutyVariant) ...[
            PharmacyDutyBanner(
              duty: state.pharmacyDuty,
              phonePrimary: state.merchant.phonePrimary,
            ),
            const SizedBox(height: 16),
          ],
          MerchantHeader(
            merchant: state.merchant,
            badge: state.badge,
            distanceLabel: state.distanceLabel,
            isDutyVariant: isDutyVariant,
          ),
          if (!isDutyVariant) ...[
            const SizedBox(height: 16),
            MerchantDisclaimer(
              merchant: state.merchant,
            ),
          ],
          const SizedBox(height: 18),
          MerchantCtaRow(
            hasPhone: state.merchant.hasPhone,
            onCallTap: onCallTap,
            onDirectionsTap: onDirectionsTap,
            onShareTap: onShareTap,
            isDutyVariant: isDutyVariant,
          ),
          const SizedBox(height: 22),
          MerchantScheduleSection(
            openStatusLabel: state.merchant.openStatusLabel,
            schedule: state.schedule,
            signals: state.signals,
          ),
          const SizedBox(height: 24),
          MerchantFeaturedProductsSection(
            products: state.featuredProducts,
          ),
          if (isDutyVariant) ...[
            const SizedBox(height: 22),
            MerchantDisclaimer(
              merchant: state.merchant,
            ),
          ],
        ],
      ),
    );
  }
}
