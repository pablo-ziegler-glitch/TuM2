import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// SEARCH-01 — Pantalla de exploración y búsqueda de comercios.
///
/// Incluye barra de búsqueda, chips de categoría, comercio destacado
/// y grilla de categorías (datos mockeados).
class SearchPlaceholderScreen extends StatefulWidget {
  const SearchPlaceholderScreen({super.key});

  @override
  State<SearchPlaceholderScreen> createState() =>
      _SearchPlaceholderScreenState();
}

class _SearchPlaceholderScreenState extends State<SearchPlaceholderScreen> {
  int _selectedChip = 0;

  static const _filterChips = ['Todo', 'Cafeterías', 'Restaurantes'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CERCA DE TI',
                        style: AppTextStyles.labelSm.copyWith(
                          color: AppColors.neutral500,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text('Explorar', style: AppTextStyles.headingLg),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.tune),
                    color: AppColors.neutral700,
                    onPressed: () {},
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Barra de búsqueda
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.neutral200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, size: 20, color: AppColors.neutral400),
                    const SizedBox(width: 10),
                    Text(
                      'Buscar cafés, tiendas, arte...',
                      style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.neutral400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(_filterChips.length, (i) {
                    final selected = _selectedChip == i;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedChip = i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primary500
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected
                                  ? AppColors.primary500
                                  : AppColors.neutral200,
                            ),
                          ),
                          child: Text(
                            _filterChips[i],
                            style: AppTextStyles.labelMd.copyWith(
                              color: selected
                                  ? Colors.white
                                  : AppColors.neutral700,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 20),

              // Comercio destacado
              GestureDetector(
                onTap: () => context.push(
                  AppRoutes.commerceDetailPath('cafe-esquina'),
                ),
                child: Container(
                  width: double.infinity,
                  height: 160,
                  decoration: BoxDecoration(
                    color: AppColors.neutral800,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Stack(
                    children: [
                      // Fondo placeholder
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: AppColors.neutral200,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.storefront_outlined,
                            size: 48,
                            color: AppColors.neutral300,
                          ),
                        ),
                      ),
                      // Overlay con info
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(16),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.7),
                              ],
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary500,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'DESTACADO',
                                  style: AppTextStyles.labelSm.copyWith(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Café de la Esquina',
                                style: AppTextStyles.headingSm.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'Artesanal & Orgánico',
                                style: AppTextStyles.bodySm.copyWith(
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Grilla de categorías
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.4,
                children: const [
                  _CategoryCard(
                    icon: Icons.shopping_bag_outlined,
                    iconColor: Color(0xFF0E5BD8),
                    title: 'Mercado Local',
                    subtitle: 'Productos frescos hoy',
                  ),
                  _CategoryCard(
                    icon: Icons.palette_outlined,
                    iconColor: Color(0xFF0F766E),
                    title: 'Arte & Diseño',
                    subtitle: 'Nuevas galerías',
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Sección editorial
              Text(
                'Guía de Fin de Semana',
                style: AppTextStyles.headingSm,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.neutral100),
                ),
                child: Text(
                  'Explorá los mejores rincones del barrio: cafés con encanto, tiendas de diseño y galerías de arte que abrieron este mes.',
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.neutral700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Widget de categoría ───────────────────────────────────────────────────────

class _CategoryCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  const _CategoryCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neutral100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: AppTextStyles.labelMd.copyWith(fontWeight: FontWeight.w600),
          ),
          Text(
            subtitle,
            style: AppTextStyles.bodyXs.copyWith(color: AppColors.neutral500),
          ),
        ],
      ),
    );
  }
}
