import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// SEARCH-01 — Tab Buscar / Explorar.
///
/// Pantalla principal de descubrimiento activo. Permite al usuario explorar
/// comercios del barrio por categoría, acceder a shortcuts clave (Abierto ahora,
/// Farmacias de turno) y ver el mapa de la zona.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String _selectedCategory = 'Todo';

  /// Rubros reales de TuM2 — coinciden con los categoryId del modelo de datos.
  static const _categories = [
    'Todo',
    'Farmacias',
    'Kioscos',
    'Almacenes',
    'Veterinarias',
    'Panaderías',
  ];

  void _onCategoryTap(String category) {
    setState(() => _selectedCategory = category);
    if (category != 'Todo') {
      context.push(AppRoutes.searchResults);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(context)),
          SliverToBoxAdapter(child: _buildSearchBar()),
          SliverToBoxAdapter(child: _buildCategories()),
          SliverToBoxAdapter(child: _buildSectionLabel('Accesos rápidos')),
          SliverToBoxAdapter(child: _buildQuickAccess(context)),
          SliverToBoxAdapter(child: _buildSectionLabel('Destacado cerca tuyo')),
          SliverToBoxAdapter(child: _buildHeroCard(context)),
          SliverToBoxAdapter(child: _buildMapCard(context)),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

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
                  'CERCA DE VOS',
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
          // Acceso directo al mapa (SEARCH-03)
          GestureDetector(
            onTap: () => context.push(AppRoutes.searchMap),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.neutral200),
              ),
              child: Icon(Icons.map_outlined,
                  color: AppColors.neutral700, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  // ── Search bar ─────────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: GestureDetector(
        onTap: () => context.push(AppRoutes.searchResults),
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
                'Buscar farmacias, kioscos, almacenes...',
                style: AppTextStyles.bodyMd
                    .copyWith(color: AppColors.neutral400),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Categorías ─────────────────────────────────────────────────────────────

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
              onTap: () => _onCategoryTap(cat),
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

  // ── Label de sección ───────────────────────────────────────────────────────

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Text(label, style: AppTextStyles.headingSm),
    );
  }

  // ── Accesos rápidos ────────────────────────────────────────────────────────

  Widget _buildQuickAccess(BuildContext context) {
    final items = [
      (
        icon: Icons.access_time_rounded,
        iconBg: AppColors.primary50,
        iconColor: AppColors.primary500,
        title: 'Abierto ahora',
        subtitle: 'En tu zona',
        route: AppRoutes.homeAbiertoAhora,
      ),
      (
        icon: Icons.local_pharmacy_outlined,
        iconBg: AppColors.secondary50,
        iconColor: AppColors.secondary500,
        title: 'Farmacias de turno',
        subtitle: 'Guardia activa hoy',
        route: AppRoutes.homeFarmacias,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: List.generate(items.length, (i) {
          final item = items[i];
          return Expanded(
            child: GestureDetector(
              onTap: () => context.push(item.route),
              child: Container(
                margin: EdgeInsets.only(right: i == 0 ? 8 : 0),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
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
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: item.iconBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(item.icon, color: item.iconColor, size: 22),
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
            ),
          );
        }),
      ),
    );
  }

  // ── Hero card destacada ────────────────────────────────────────────────────

  Widget _buildHeroCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: GestureDetector(
        onTap: () =>
            context.push(AppRoutes.commerceDetailPath('farmacia-central')),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 200,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Placeholder de imagen del comercio
                Container(
                  color: AppColors.neutral700,
                  child: Center(
                    child: Icon(Icons.local_pharmacy_outlined,
                        size: 64, color: AppColors.neutral500),
                  ),
                ),
                // Gradient overlay
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
                // Badge "DESTACADO"
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
                // Nombre y subtítulo
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Farmacia Central',
                        style: AppTextStyles.headingSm
                            .copyWith(color: AppColors.surface),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Turno activo · Abierta hasta las 22hs',
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

  // ── Tarjeta "Ver en el mapa" ───────────────────────────────────────────────

  Widget _buildMapCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: GestureDetector(
        onTap: () => context.push(AppRoutes.searchMap),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.tertiary50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.map_outlined,
                    color: AppColors.tertiary500, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ver comercios en el mapa',
                      style: AppTextStyles.labelMd,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Encontrá lo que está abierto ahora cerca de vos',
                      style: AppTextStyles.bodyXs,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.neutral400),
            ],
          ),
        ),
      ),
    );
  }
}
