import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../application/merchant_detail_controller.dart';
import '../application/merchant_detail_error_mapper.dart';
import '../application/merchant_detail_state.dart';
import '../domain/merchant_detail_view_data.dart';
import 'merchant_detail_copy.dart';
import 'widgets/merchant_address_cta_block.dart';
import 'widgets/merchant_detail_error_state.dart';
import 'widgets/merchant_detail_header.dart';
import 'widgets/merchant_detail_not_found_state.dart';
import 'widgets/merchant_detail_skeleton.dart';
import 'widgets/merchant_operational_signals_block.dart';
import 'widgets/merchant_products_section.dart';
import 'widgets/merchant_schedule_section.dart';
import 'widgets/merchant_trust_badges.dart';

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

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: const Text('Comercio'),
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
                ? MerchantDetailCopy.connectionError
                : MerchantDetailCopy.genericError,
            onRetry: controller.retry,
          );
        },
        data: (state) => _MerchantDetailReady(
          state: state,
          onDirectionsTap: controller.onDirectionsTap,
          onScheduleExpandedChanged: controller.onScheduleExpandedChanged,
          onProductTap: (product) {
            controller.onProductTap(product.productId);
            context.push(
              AppRoutes.commerceProductDetailPath(
                merchantId: merchantId,
                productId: product.productId,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MerchantDetailReady extends StatelessWidget {
  const _MerchantDetailReady({
    required this.state,
    required this.onDirectionsTap,
    required this.onScheduleExpandedChanged,
    required this.onProductTap,
  });

  final MerchantDetailState state;
  final Future<void> Function() onDirectionsTap;
  final ValueChanged<bool> onScheduleExpandedChanged;
  final void Function(MerchantProductViewData product) onProductTap;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MerchantDetailHeader(
            core: state.core,
            trustBadges: state.core.trustBadges,
          ),
          const SizedBox(height: 10),
          Text(
            state.core.openStatusLabel,
            style: AppTextStyles.bodySm,
          ),
          if (state.core.trustBadges.isNotEmpty) ...[
            const SizedBox(height: 10),
            MerchantTrustBadges(badges: state.core.trustBadges),
          ],
          if (_showCommunityNotice(state.core.trustBadges)) ...[
            const SizedBox(height: 12),
            const _CommunityInfoNotice(),
          ],
          const SizedBox(height: 16),
          MerchantAddressCtaBlock(
            address: state.core.address,
            distanceLabel: state.distanceLabel,
            onHowToGetTap: onDirectionsTap,
          ),
          const SizedBox(height: 18),
          MerchantOperationalSignalsBlock(signals: state.signals),
          if (state.signals.hasValue &&
              (state.signals.valueOrNull?.isNotEmpty ?? false))
            const SizedBox(height: 18),
          MerchantProductsSection(
            products: state.products,
            onProductTap: onProductTap,
          ),
          const SizedBox(height: 18),
          MerchantScheduleSection(
            schedule: state.schedule,
            isExpanded: state.isScheduleExpanded,
            onExpandedChanged: onScheduleExpandedChanged,
          ),
        ],
      ),
    );
  }

  bool _showCommunityNotice(List<MerchantTrustBadgeViewData> badges) {
    return badges.any(
      (badge) =>
          badge.type == MerchantTrustBadgeType.community ||
          badge.type == MerchantTrustBadgeType.referential,
    );
  }
}

class _CommunityInfoNotice extends StatelessWidget {
  const _CommunityInfoNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.tertiary50,
            ),
            child: const Icon(
              Icons.info_outline,
              size: 18,
              color: AppColors.tertiary700,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Información de la comunidad',
                  style: AppTextStyles.labelMd,
                ),
                SizedBox(height: 4),
                Text(
                  'Los datos pueden cambiar; esta información está en revisión.',
                  style: AppTextStyles.bodySm,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
