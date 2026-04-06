import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/merchant_search_item.dart';

class MerchantSearchCard extends StatelessWidget {
  const MerchantSearchCard({
    super.key,
    required this.item,
    this.onTap,
  });

  final MerchantSearchItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.neutral100,
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  Icon(Icons.storefront_outlined, color: AppColors.neutral500),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: AppTextStyles.labelMd,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _VerificationBadge(status: item.verificationStatus),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.categoryLabel.isEmpty ? item.categoryId : item.categoryLabel} · ${item.address}',
                    style: AppTextStyles.bodyXs,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 8,
                        color: item.isOpenNow == true
                            ? AppColors.secondary500
                            : AppColors.neutral400,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        item.isOpenNow == true
                            ? 'Abierto ahora'
                            : (item.openStatusLabel.isEmpty
                                ? 'Sin horario'
                                : item.openStatusLabel),
                        style: AppTextStyles.bodyXs,
                      ),
                      const Spacer(),
                      Text(_formatDistance(item.distanceMeters),
                          style: AppTextStyles.bodyXs),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDistance(double? meters) {
    if (meters == null) return '--';
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }
}

class _VerificationBadge extends StatelessWidget {
  const _VerificationBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'verified' || 'validated' => ('Verificado', Colors.green),
      'claimed' => ('Reclamado', Colors.blue),
      'referential' => ('Referencial', Colors.teal),
      'community_submitted' => ('No verificado', Colors.amber.shade800),
      _ => ('Pendiente', Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: AppTextStyles.bodyXs.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
