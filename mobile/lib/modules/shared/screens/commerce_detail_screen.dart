import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// HOME-01 Detail — Ficha pública de un comercio.
/// Recibe [commerceId] para futura carga desde Firestore.
/// Por ahora muestra datos estáticos de demo (Café Aura).
class CommerceDetailScreen extends StatelessWidget {
  final String commerceId;

  const CommerceDetailScreen({super.key, required this.commerceId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatusBadge(),
                  const SizedBox(height: 10),
                  Text('Café Aura', style: AppTextStyles.headingLg),
                  const SizedBox(height: 4),
                  Text(
                    'Cafetería Especializada & Pastelería Artesanal',
                    style: AppTextStyles.bodySm,
                  ),
                  const SizedBox(height: 16),
                  _InfoRows(),
                  const SizedBox(height: 16),
                  _MapWidget(),
                  const SizedBox(height: 16),
                  _ActionButtons(),
                  const Divider(height: 36, color: AppColors.neutral200),
                  _HistorySection(),
                  const SizedBox(height: 24),
                  _GallerySection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: AppColors.surface,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: _CircleIconButton(
          icon: Icons.arrow_back,
          onTap: () => context.pop(),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: _CircleIconButton(
            icon: Icons.share_outlined,
            onTap: () {},
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          color: AppColors.neutral200,
          child: Center(
            child: Icon(Icons.storefront,
                size: 64, color: AppColors.neutral400),
          ),
        ),
      ),
    );
  }
}

// ── Badge ABIERTO ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.successBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'ABIERTO',
        style: AppTextStyles.labelSm.copyWith(
          color: AppColors.successFg,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

// ── Info rows ─────────────────────────────────────────────────────────────────

class _InfoRows extends StatelessWidget {
  static const _rows = [
    (icon: Icons.location_on_outlined, text: 'Av. Siempre Viva 742, Palermo'),
    (icon: Icons.access_time_outlined, text: 'Lun-Dom: 08–22h'),
    (icon: Icons.pages_outlined, text: 'Déliric, GR'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _rows
          .map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(row.icon, size: 16, color: AppColors.neutral500),
                  const SizedBox(width: 8),
                  Text(row.text, style: AppTextStyles.bodySm),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

// ── Mapa placeholder ──────────────────────────────────────────────────────────

class _MapWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 140,
        color: AppColors.neutral200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.map_outlined, size: 36, color: AppColors.neutral400),
              const SizedBox(height: 4),
              Text('Buenos Aires', style: AppTextStyles.bodyXs),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Botones de acción ─────────────────────────────────────────────────────────

class _ActionButtons extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary500,
              foregroundColor: AppColors.surface,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            icon: const Icon(Icons.directions_outlined, size: 18),
            label: Text(
              'Cómo llegar',
              style:
                  AppTextStyles.labelMd.copyWith(color: AppColors.surface),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _IconActionButton(icon: Icons.phone_outlined, onTap: () {}),
        const SizedBox(width: 10),
        _IconActionButton(icon: Icons.favorite_border, onTap: () {}),
      ],
    );
  }
}

// ── Historia ──────────────────────────────────────────────────────────────────

class _HistorySection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Nuestra Historia', style: AppTextStyles.headingSm),
        const SizedBox(height: 8),
        Text(
          'Café Aura ha sido el corazón del barrio desde 2010. '
          'Reconocido por su café de especialidad de origen único y '
          'su ambiente acogedor, ideal para trabajar o relajarse.',
          style: AppTextStyles.bodyMd,
        ),
      ],
    );
  }
}

// ── Galería ───────────────────────────────────────────────────────────────────

class _GallerySection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Galería del Local', style: AppTextStyles.headingSm),
            TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'VER TODO',
                style: AppTextStyles.labelSm.copyWith(
                  color: AppColors.primary500,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 80,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 4,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) => ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 80,
                height: 80,
                color: AppColors.neutral200,
                child: Icon(Icons.image_outlined,
                    color: AppColors.neutral400),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Shared ────────────────────────────────────────────────────────────────────

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CircleAvatar(
        backgroundColor: AppColors.surface,
        radius: 18,
        child: Icon(icon, color: AppColors.neutral700, size: 20),
      ),
    );
  }
}

class _IconActionButton extends StatelessWidget {
  const _IconActionButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.neutral200),
        ),
        child: Icon(icon, color: AppColors.neutral700, size: 20),
      ),
    );
  }
}
