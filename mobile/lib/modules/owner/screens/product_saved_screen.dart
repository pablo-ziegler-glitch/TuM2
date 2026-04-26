import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class ProductSavedPayload {
  const ProductSavedPayload({
    required this.productId,
    required this.name,
    required this.priceLabel,
    this.imageUrl,
    required this.isPublic,
    this.imageUploadFailed = false,
  });

  final String productId;
  final String name;
  final String priceLabel;
  final String? imageUrl;
  final bool isPublic;
  final bool imageUploadFailed;
}

class ProductSavedScreen extends StatelessWidget {
  const ProductSavedScreen({
    super.key,
    required this.payload,
  });

  final ProductSavedPayload payload;

  @override
  Widget build(BuildContext context) {
    final imageUrl = (payload.imageUrl ?? '').trim();
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppColors.scaffoldBg,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 540),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 136,
                      height: 136,
                      decoration: BoxDecoration(
                        color: AppColors.secondary500.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    Container(
                      width: 98,
                      height: 98,
                      decoration: BoxDecoration(
                        color: AppColors.secondary500.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.secondary500,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color:
                                AppColors.secondary500.withValues(alpha: 0.28),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Producto publicado',
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                    height: 1.08,
                    letterSpacing: -0.5,
                    color: AppColors.neutral900,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'Listo, ya puede aparecer para los Vecinos de Tu zona.',
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.neutral700,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (payload.imageUploadFailed) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.errorBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: AppColors.errorFg,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'No pudimos cargar la foto. Podés editar el producto y sumarla después.',
                            style: AppTextStyles.bodySm.copyWith(
                              color: AppColors.errorFg,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF0044AA), Color(0xFF0E5BD8)],
                      ),
                    ),
                    child: ElevatedButton(
                      onPressed: () => context.go(AppRoutes.ownerProducts),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Volver a productos',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.go(AppRoutes.ownerProductsNew),
                  child: Text(
                    'Agregar otro',
                    style: AppTextStyles.labelMd.copyWith(
                      color: AppColors.primary500,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                const Divider(color: AppColors.neutral100, height: 1),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 64,
                        height: 64,
                        color: AppColors.neutral100,
                        child: imageUrl.isEmpty
                            ? const Icon(
                                Icons.inventory_2_outlined,
                                color: AppColors.neutral500,
                              )
                            : Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) {
                                  return const Icon(
                                    Icons.broken_image_outlined,
                                    color: AppColors.neutral500,
                                  );
                                },
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'RECIÉN AÑADIDO',
                            style: AppTextStyles.labelSm.copyWith(
                              color: AppColors.primary500,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            payload.priceLabel.trim().isEmpty
                                ? payload.name
                                : '${payload.name} · ${payload.priceLabel}',
                            style: AppTextStyles.bodySm.copyWith(
                              color: AppColors.neutral900,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'El producto se indexó correctamente para tu comercio.',
                            style: AppTextStyles.bodySm.copyWith(
                              color: AppColors.neutral700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.secondary50,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.visibility,
                            size: 14,
                            color: AppColors.secondary500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            payload.isPublic ? 'Público' : 'Oculto',
                            style: AppTextStyles.labelSm.copyWith(
                              color: AppColors.secondary500,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
