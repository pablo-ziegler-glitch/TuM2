import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// DETAIL-01 — Ficha pública de comercio.
///
/// Pantalla full-screen (sin tab bar) con imagen de portada expandible,
/// información del comercio, mapa placeholder y galería (datos mockeados —
/// se conectará a Firestore en TuM2-0058).
class CommerceDetailPlaceholderScreen extends StatelessWidget {
  final String commerceId;

  const CommerceDetailPlaceholderScreen({
    super.key,
    required this.commerceId,
  });

  @override
  Widget build(BuildContext context) {
    // Datos mockeados — se reemplazarán con datos reales en TuM2-0058
    const commerceName = 'Café Aura';
    const category = 'Cafetería Especializada & Pastelería Artesanal';
    const address = 'Av. Siempre Viva 742, Palermo';
    const schedule = 'Lun-Dom: 08-22';
    const payment = 'Débito, QR...';
    final isOpen = commerceId.isNotEmpty;
    const story =
        'Café Aura ha sido el corazón del barrio desde 2010. Reconocido por su '
        'café de especialidad de origen único y su ambiente acogedor, ideal para '
        'trabajar o relajarse con amigos.';

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          // AppBar con imagen expandible
          SliverAppBar(
            expandedHeight: 220,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.surface,
            scrolledUnderElevation: 0,
            leading: BackButton(
              color: AppColors.neutral900,
              onPressed: () => context.pop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share_outlined, color: AppColors.neutral900),
                onPressed: () {},
              ),
            ],
            title: const Text(commerceName, style: AppTextStyles.headingSm),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: AppColors.neutral100,
                child: const Icon(
                  Icons.storefront_outlined,
                  size: 64,
                  color: AppColors.neutral300,
                ),
              ),
            ),
          ),

          // Contenido
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badge de estado
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isOpen ? AppColors.successBg : AppColors.errorBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isOpen ? 'ABIERTO' : 'CERRADO',
                      style: AppTextStyles.labelSm.copyWith(
                        color: isOpen ? AppColors.successFg : AppColors.errorFg,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Nombre y categoría
                  const Text(commerceName, style: AppTextStyles.headingMd),
                  const SizedBox(height: 4),
                  Text(
                    category,
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.neutral500,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Info rows
                  const _InfoRow(
                    icon: Icons.location_on_outlined,
                    text: address,
                  ),
                  const SizedBox(height: 8),
                  const Row(
                    children: [
                      Expanded(
                        child: _InfoRow(
                          icon: Icons.schedule_outlined,
                          text: schedule,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _InfoRow(
                          icon: Icons.credit_card_outlined,
                          text: payment,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Mapa placeholder
                  Container(
                    width: double.infinity,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.neutral100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.neutral200),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.map_outlined,
                        size: 36,
                        color: AppColors.neutral300,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // CTAs
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.directions_outlined, size: 18),
                          label: const Text('Cómo llegar'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary500,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _CircleIconButton(
                        icon: Icons.phone_outlined,
                        onTap: () {},
                      ),
                      const SizedBox(width: 8),
                      _CircleIconButton(
                        icon: Icons.favorite_border,
                        onTap: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Nuestra Historia
                  const Text('Nuestra Historia', style: AppTextStyles.headingSm),
                  const SizedBox(height: 8),
                  Text(
                    story,
                    style: AppTextStyles.bodyMd.copyWith(
                      color: AppColors.neutral700,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Galería
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Galería del Local', style: AppTextStyles.headingSm),
                      TextButton(
                        onPressed: () {},
                        child: Text(
                          'VER TODO',
                          style: AppTextStyles.labelSm.copyWith(
                            color: AppColors.primary500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _GalleryThumb(),
                      const SizedBox(width: 8),
                      _GalleryThumb(),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.neutral500),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodySm.copyWith(color: AppColors.neutral700),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.neutral200),
        ),
        child: Icon(icon, size: 20, color: AppColors.neutral700),
      ),
    );
  }
}

class _GalleryThumb extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 90,
      decoration: BoxDecoration(
        color: AppColors.neutral100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(
        Icons.image_outlined,
        size: 32,
        color: AppColors.neutral300,
      ),
    );
  }
}
