import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class SearchEmptyState extends StatelessWidget {
  const SearchEmptyState({
    super.key,
    required this.isColdStart,
    required this.query,
    required this.isZoneWithoutData,
    required this.openNowActive,
    this.onSuggestCommerce,
  });

  final bool isColdStart;
  final String query;
  final bool isZoneWithoutData;
  final bool openNowActive;
  final VoidCallback? onSuggestCommerce;

  @override
  Widget build(BuildContext context) {
    final title = isZoneWithoutData
        ? 'Todavía no hay comercios cargados para esta zona'
        : 'No encontramos resultados para esta búsqueda';

    final subtitle = isZoneWithoutData
        ? 'Probá cambiar de zona o volver más tarde.'
        : 'Intentá buscar categorías similares o más generales.';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Text(
          title,
          style: AppTextStyles.headingMd.copyWith(
            fontSize: 42,
            height: 1.1,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  _HintBlock(
                    borderColor: AppColors.primary100,
                    title: 'Probá con otro rubro',
                    subtitle: subtitle,
                  ),
                  const SizedBox(height: 18),
                  _HintBlock(
                    borderColor: AppColors.secondary100,
                    title: 'o limpiá los filtros',
                    subtitle: openNowActive
                        ? 'Tenés “Abierto ahora” activo'
                        : 'Hay filtros activos que pueden limitar resultados',
                    trailing: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.secondary500,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            openNowActive ? 'Abierto ahora' : 'Zona activa',
                            style: AppTextStyles.labelSm.copyWith(
                              color: AppColors.surface,
                            ),
                          ),
                        ),
                        Text(
                          'Filtro aplicado',
                          style: AppTextStyles.bodyXs.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const _NoResultsArt(),
          ],
        ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.secondary500, width: 1.8),
            foregroundColor: AppColors.secondary500,
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: onSuggestCommerce ?? () => context.push(AppRoutes.search),
          icon: const Icon(Icons.add_business_outlined),
          label: Text(
            'Sugerir un comercio',
            style: AppTextStyles.labelMd.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Text(
              'Categorías populares cerca',
              style:
                  AppTextStyles.headingSm.copyWith(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            Text(
              'Ver todas',
              style: AppTextStyles.labelSm.copyWith(
                color: AppColors.primary500,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _CategoryPill(
                icon: Icons.local_pharmacy_outlined,
                iconBg: AppColors.secondary100,
                iconFg: AppColors.secondary700,
                label: 'Farmacias',
              ),
              SizedBox(width: 10),
              _CategoryPill(
                icon: Icons.shopping_basket_outlined,
                iconBg: AppColors.tertiary100,
                iconFg: AppColors.tertiary700,
                label: 'Kioscos',
              ),
              SizedBox(width: 10),
              _CategoryPill(
                icon: Icons.pets_outlined,
                iconBg: AppColors.primary100,
                iconFg: AppColors.primary700,
                label: 'Veterinarias',
              ),
            ],
          ),
        ),
        if (isColdStart)
          const Padding(
            padding: EdgeInsets.only(top: 18),
            child: Text(
              'Esta zona está creciendo. Pronto vas a ver más comercios.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyXs,
            ),
          ),
        if (query.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Búsqueda actual: “${query.trim()}”',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyXs.copyWith(color: AppColors.neutral700),
            ),
          ),
      ],
    );
  }
}

class _HintBlock extends StatelessWidget {
  const _HintBlock({
    required this.borderColor,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final Color borderColor;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 14, top: 2, bottom: 2),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: borderColor, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style:
                AppTextStyles.headingSm.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: AppTextStyles.bodySm.copyWith(color: AppColors.neutral700),
          ),
          if (trailing != null) ...[
            const SizedBox(height: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _NoResultsArt extends StatelessWidget {
  const _NoResultsArt();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 86,
      height: 86,
      child: Stack(
        children: [
          Container(
            width: 64,
            height: 64,
            margin: const EdgeInsets.only(top: 10, left: 8),
            decoration: BoxDecoration(
              color: AppColors.neutral100,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.storefront_outlined,
              color: AppColors.primary100,
              size: 30,
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off,
                color: AppColors.errorFg,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.label,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconFg, size: 16),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppTextStyles.labelMd.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
