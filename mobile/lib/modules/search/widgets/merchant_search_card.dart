import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/merchant_search_item.dart';

class MerchantSearchCard extends StatelessWidget {
  const MerchantSearchCard({
    super.key,
    required this.item,
    required this.onTap,
    this.onMapTap,
    this.imageSeed = 0,
  });

  final MerchantSearchItem item;
  final VoidCallback onTap;
  final VoidCallback? onMapTap;
  final int imageSeed;

  @override
  Widget build(BuildContext context) {
    final openNow = item.isOpenNow == true;
    final distanceText = item.distanceMeters == null
        ? null
        : _distanceLabel(item.distanceMeters!);
    final hasTrustedVerification =
        _verificationRank(item.verificationStatus) >= 5;
    final imageUrl = _imageForCard(item: item, seed: imageSeed);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.neutral900.withValues(alpha: 0.04),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 170,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: AppColors.primary100,
                          alignment: Alignment.center,
                          child: Icon(
                            _categoryIcon(item.categoryId),
                            color: AppColors.primary600,
                            size: 42,
                          ),
                        ),
                      ),
                      if (openNow)
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.secondary500,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'ABIERTO AHORA',
                              style: AppTextStyles.bodyXs.copyWith(
                                color: AppColors.surface,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              style: AppTextStyles.headingSm.copyWith(
                                fontSize: 30,
                                height: 1.0,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (hasTrustedVerification)
                            const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Icon(
                                Icons.verified,
                                color: AppColors.primary500,
                                size: 18,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        item.categoryLabel.isNotEmpty
                            ? item.categoryLabel
                            : item.categoryId,
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.neutral700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (item.addressSummary.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 16,
                              color: AppColors.neutral700,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                item.addressSummary,
                                style: AppTextStyles.bodySm.copyWith(
                                  color: AppColors.neutral700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (distanceText != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.secondary100,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                distanceText,
                                style: AppTextStyles.labelSm.copyWith(
                                  color: AppColors.secondary700,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          const Spacer(),
                          _PrimaryActionButton(
                            onTap: onMapTap ?? onTap,
                            label: 'Ver en mapa',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static int _verificationRank(String verificationStatus) {
    switch (verificationStatus) {
      case 'verified':
        return 6;
      case 'validated':
        return 5;
      case 'claimed':
        return 4;
      case 'referential':
        return 3;
      case 'community_submitted':
        return 2;
      default:
        return 1;
    }
  }

  static String _imageForCard({
    required MerchantSearchItem item,
    required int seed,
  }) {
    const genericImages = [
      'https://lh3.googleusercontent.com/aida-public/AB6AXuCe4ciMQ5NIPhKCeJJHqnjYv0x1it2vpH_UDfTQnGdNun3gC0tyHurDTrlKey7hco9L_gkrvFuKJPVZE1EOxKfDkm9d6U0ZzhhsxMIg5TCj8wvdaS7qorNXKbGEzVZfMmoDeq3W7SNyd8qyAvu62d9vFlupFnx55ORyb7NcT4nkcxUxJ_P-IcQZMHDmofZrctp_OFd9wu76y6rm1dALPP6ELZ6GaPIkQlPZB2uyhSQ3ViixESmmY511itcYU_1dv7SuQo8kjpoF7Dlv',
      'https://lh3.googleusercontent.com/aida-public/AB6AXuAMERvKO2CB6FcApfJk-Jtr8DM3wTnpcjI191X-xgqTF3zGEXyigJ2_-pwziSsdhlZbKpbLMqe1ZK0IlaCSJ3hgowN0MNiuXq_hIFQFilmYyV3CgZ4JtfZqeOaSHDTDVoe_KuznRzWBLpkmmtpqZNBukr6lLljzyINdhoSi-2GSBbudg2zIqcP8HZQkL0AzTcWss-pn_bJxwpPB_GXS1-dLPs3sKpWBNTziyu0wFDw8Iu2i-qeKaBHwsv32SOKsDzKUIwUZ_76_dOkM',
      'https://lh3.googleusercontent.com/aida-public/AB6AXuASqfioR6jW9iOydIqUXrizDj2RBHAAQf6rIrByTAMrq9gG3FJ2vGDk-kYUQWU3oM1EzR_6Xhp8SmzgVXQiKgmDbrqtDDr0WZSoRlCoD2wE5gMAGI3NBTw-e5B1fZGWZZXetEmm5K_bDACmQylaWC9i7Wr68WTOaEIRgNE7O0yc2zi5t6D9j4mQyqaGPhR2g-jcJS6tb87r6kW-OgCfDt24G7g6wT-UjZPp8VRlpJ_y-I-6Q-dKjZA8gKl9K9X3FZT_8sqoUH5hPdME',
    ];
    final lowerCategory = item.categoryId.toLowerCase();
    if (lowerCategory.contains('pharmacy') || lowerCategory.contains('farm')) {
      return 'https://images.unsplash.com/photo-1587854692152-cbe660dbde88?auto=format&fit=crop&w=1200&q=80';
    }
    if (lowerCategory.contains('kiosk')) {
      return 'https://images.unsplash.com/photo-1604719312566-8912e9c8a213?auto=format&fit=crop&w=1200&q=80';
    }
    if (lowerCategory.contains('veter')) {
      return 'https://images.unsplash.com/photo-1576201836106-db1758fd1c97?auto=format&fit=crop&w=1200&q=80';
    }
    return genericImages[seed % genericImages.length];
  }

  static IconData _categoryIcon(String categoryId) {
    final lower = categoryId.toLowerCase();
    if (lower.contains('pharmacy') || lower.contains('farm')) {
      return Icons.local_pharmacy_outlined;
    }
    if (lower.contains('kiosk')) {
      return Icons.storefront_outlined;
    }
    if (lower.contains('veter')) {
      return Icons.pets_outlined;
    }
    return Icons.store_mall_directory_outlined;
  }

  static String _distanceLabel(int meters) {
    if (meters < 1000) return 'A ${meters}m';
    final km = meters / 1000.0;
    return 'A ${km.toStringAsFixed(1)}km';
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.onTap,
    required this.label,
  });

  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [Color(0xFF0044AA), Color(0xFF0E5BD8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Text(
              label,
              style: AppTextStyles.labelSm.copyWith(
                color: AppColors.surface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
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
