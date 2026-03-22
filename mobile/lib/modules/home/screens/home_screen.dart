import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// HOME-01 — Tab Inicio (Customer).
/// Muestra sección "Curated Gems" y acceso rápido a búsqueda.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _Header()),
          SliverToBoxAdapter(child: _SearchBar()),
          SliverToBoxAdapter(child: _SectionHeader()),
          SliverList(
            delegate: SliverChildListDelegate([
              _CommerceCard(
                tag: 'DISTRICT 01',
                name: 'The Paper Atelier',
                subtitle:
                    'Hand-pressed stationary and artisan journals for the modern digital nomad.',
                rating: 4.8,
                onTap: () =>
                    context.push(AppRoutes.commerceDetailPath('paper-atelier')),
              ),
              _CommerceCard(
                tag: 'CENTRAL',
                name: 'Café Aura',
                subtitle:
                    'Cafetería Especializada & Pastelería Artesanal en el corazón del barrio.',
                onTap: () =>
                    context.push(AppRoutes.commerceDetailPath('cafe-aura')),
              ),
              const SizedBox(height: 24),
            ]),
          ),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 20, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WELCOME BACK',
                  style: AppTextStyles.labelSm.copyWith(
                    color: AppColors.neutral500,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text('Neighborhood', style: AppTextStyles.headingLg),
              ],
            ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.neutral200,
            child: Icon(Icons.person_outline,
                color: AppColors.neutral600, size: 22),
          ),
        ],
      ),
    );
  }
}

// ── Search bar decorativa ─────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: GestureDetector(
        onTap: () => context.go(AppRoutes.search),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.neutral200),
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Icon(Icons.search, color: AppColors.neutral400, size: 20),
              const SizedBox(width: 8),
              Text(
                'Search curated shops...',
                style: AppTextStyles.bodyMd
                    .copyWith(color: AppColors.neutral400),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Curated Gems', style: AppTextStyles.headingSm),
          TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'View all',
              style:
                  AppTextStyles.labelMd.copyWith(color: AppColors.primary500),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Commerce card ─────────────────────────────────────────────────────────────

class _CommerceCard extends StatelessWidget {
  const _CommerceCard({
    required this.tag,
    required this.name,
    required this.subtitle,
    required this.onTap,
    this.rating,
  });

  final String tag;
  final String name;
  final String subtitle;
  final VoidCallback onTap;
  final double? rating;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // imagen placeholder
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: Container(
                height: 160,
                color: AppColors.neutral200,
                child: Stack(
                  children: [
                    Center(
                      child: Icon(Icons.storefront,
                          size: 52, color: AppColors.neutral400),
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: _TagBadge(label: tag),
                    ),
                  ],
                ),
              ),
            ),
            // info
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: Text(name, style: AppTextStyles.headingSm)),
                      if (rating != null) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.star_rounded,
                            size: 15, color: AppColors.tertiary500),
                        const SizedBox(width: 2),
                        Text(
                          rating!.toStringAsFixed(1),
                          style: AppTextStyles.labelSm
                              .copyWith(color: AppColors.neutral700),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySm,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tag badge ─────────────────────────────────────────────────────────────────

class _TagBadge extends StatelessWidget {
  const _TagBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.neutral900.withOpacity(0.75),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: AppTextStyles.bodyXs.copyWith(
          color: AppColors.surface,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
