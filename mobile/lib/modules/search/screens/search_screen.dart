import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// SEARCH-01 — Tab Buscar / Explorar.
/// Muestra categorías, hero card destacada y grilla de accesos rápidos.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String _selectedCategory = 'Todo';

  static const _categories = ['Todo', 'Cafeterías', 'Restaurantes'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(context)),
          SliverToBoxAdapter(child: _buildSearchBar()),
          SliverToBoxAdapter(child: _buildCategories()),
          SliverToBoxAdapter(child: _buildHeroCard(context)),
          SliverToBoxAdapter(child: _buildGrid()),
          SliverToBoxAdapter(child: _buildGuideItem()),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
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
                  'CERCA DE TI',
                  style: AppTextStyles.labelSm.copyWith(
                    color: AppColors.neutral500,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text('Explorar', style: AppTextStyles.headingLg),
              ],
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.neutral200),
            ),
            child: Icon(Icons.grid_view_rounded,
                color: AppColors.neutral700, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
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
              'Buscar cafés, tiendas, arte...',
              style: AppTextStyles.bodyMd
                  .copyWith(color: AppColors.neutral400),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategories() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 0, 0),
      child: SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(right: 20),
          itemCount: _categories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final cat = _categories[i];
            final selected = cat == _selectedCategory;
            return GestureDetector(
              onTap: () => setState(() => _selectedCategory = cat),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary500 : AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected
                        ? AppColors.primary500
                        : AppColors.neutral300,
                  ),
                ),
                child: Text(
                  cat,
                  style: AppTextStyles.labelMd.copyWith(
                    color: selected
                        ? AppColors.surface
                        : AppColors.neutral700,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: GestureDetector(
        onTap: () =>
            context.push(AppRoutes.commerceDetailPath('cafe-esquina')),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 200,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  color: AppColors.neutral700,
                  child: Center(
                    child: Icon(Icons.storefront,
                        size: 64, color: AppColors.neutral500),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.72),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.tertiary500,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'DESTACADO',
                      style: AppTextStyles.bodyXs.copyWith(
                        color: AppColors.surface,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Café de la Esquina',
                        style: AppTextStyles.headingSm
                            .copyWith(color: AppColors.surface),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Artesanal & Orgánico',
                        style: AppTextStyles.bodySm
                            .copyWith(color: AppColors.neutral300),
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

  Widget _buildGrid() {
    final items = [
      (icon: Icons.storefront_outlined, title: 'Mercado Local', subtitle: 'Productos frescos hoy'),
      (icon: Icons.palette_outlined, title: 'Arte & Diseño', subtitle: 'Nuevas galerías'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: List.generate(items.length, (i) {
          final item = items[i];
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: i == 0 ? 8 : 0),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(item.icon,
                        color: AppColors.primary500, size: 22),
                  ),
                  const SizedBox(height: 10),
                  Text(item.title, style: AppTextStyles.labelMd),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    style: AppTextStyles.bodyXs,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildGuideItem() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.secondary50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.menu_book_outlined,
                  color: AppColors.secondary500, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Guía de Fin de Semana: El mejor café...',
                    style: AppTextStyles.labelMd,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text('Edición curada del barrio',
                      style: AppTextStyles.bodyXs),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.neutral400),
          ],
        ),
      ),
    );
  }
}
