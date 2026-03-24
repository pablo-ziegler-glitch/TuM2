import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// HOME-02 — Vista "Abierto ahora".
///
/// Muestra todos los comercios de la zona activa que están abiertos en este
/// momento. Permite filtrar por categoría y acceder al detalle de cada uno.
///
/// Fuente: `merchant_public` filtrado `isOpenNow == true` ordenado por
/// `sortBoost desc` + distancia.
class AbiertoAhoraScreen extends StatefulWidget {
  const AbiertoAhoraScreen({super.key});

  @override
  State<AbiertoAhoraScreen> createState() => _AbiertoAhoraScreenState();
}

class _AbiertoAhoraScreenState extends State<AbiertoAhoraScreen> {
  String _selectedCategory = 'Todos';

  static const _categories = [
    'Todos',
    'Cafeterías',
    'Kioscos',
    'Almacenes',
    'Panaderías',
    'Farmacias',
  ];

  // Datos de ejemplo para el diseño
  static const _mockCommerces = [
    (
      name: 'Café de la Esquina',
      type: 'Cafetería',
      address: 'Thames 1820',
      distance: '180m',
      zone: 'Palermo',
      rating: 4.7,
      closesAt: 'Cierra a las 23hs',
      action: 'Ver más',
      actionFilled: false,
    ),
    (
      name: 'MaxiKiosco Javi',
      type: 'Kiosco',
      address: 'Honduras 4890',
      distance: '290m',
      zone: 'Palermo Viejo',
      rating: 4.1,
      closesAt: 'Abierto 24hs',
      action: 'Ir',
      actionFilled: true,
    ),
    (
      name: 'La Florería',
      type: 'Florería',
      address: 'Gurruchaga 1502',
      distance: '380m',
      zone: 'Palermo',
      rating: 4.9,
      closesAt: 'Cierra a las 20hs',
      action: 'Ver más',
      actionFilled: false,
    ),
    (
      name: 'Mercado Local',
      type: 'Mercado',
      address: 'Av. Santa Fe 3200',
      distance: '540m',
      zone: 'Palermo',
      rating: 4.4,
      closesAt: 'Cierra a las 22hs',
      action: 'Ver más',
      actionFilled: false,
    ),
    (
      name: 'Hotel Boutique Soho',
      type: 'Hotel',
      address: 'El Salvador 4724',
      distance: '620m',
      zone: 'Palermo Soho',
      rating: 4.6,
      closesAt: 'Abierto 24hs',
      action: 'Reservar',
      actionFilled: true,
    ),
    (
      name: 'Open 26',
      type: 'Kiosco',
      address: 'Thames 1450',
      distance: '690m',
      zone: 'Palermo',
      rating: 4.5,
      closesAt: 'Abierto 24hs',
      action: 'Ir',
      actionFilled: true,
    ),
  ];

  List<({
    String name,
    String type,
    String address,
    String distance,
    String zone,
    double rating,
    String closesAt,
    String action,
    bool actionFilled,
  })> get _filtered {
    if (_selectedCategory == 'Todos') return _mockCommerces.toList();
    return _mockCommerces
        .where((c) => c.type.contains(_selectedCategory.replaceAll('s', '')))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final results = _filtered;
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(
        children: [
          _buildHeader(context),
          _buildStatusBar(results.length),
          _buildCategoryFilter(),
          Expanded(
            child: results.isEmpty
                ? _buildEmpty()
                : ListView.builder(
                    padding:
                        const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    itemCount: results.length,
                    itemBuilder: (_, i) => _CommerceCard(
                      commerce: results[i],
                      onTap: () => context.push(
                        AppRoutes.commerceDetailPath(
                          results[i].name
                              .toLowerCase()
                              .replaceAll(' ', '-'),
                        ),
                      ),
                    ),
                  ),
          ),
          _buildMapBar(context),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: EdgeInsets.fromLTRB(
          16, MediaQuery.of(context).padding.top + 12, 16, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Icon(Icons.arrow_back,
                  color: AppColors.neutral700, size: 22),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PALERMO',
                  style: AppTextStyles.labelSm.copyWith(
                    color: AppColors.neutral500,
                    letterSpacing: 1.2,
                  ),
                ),
                Text('Abierto ahora', style: AppTextStyles.headingSm),
              ],
            ),
          ),
          // Indicador activo
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.secondary50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.secondary500,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  'En vivo',
                  style: AppTextStyles.labelSm
                      .copyWith(color: AppColors.secondary700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Barra de estado ────────────────────────────────────────────────────────

  Widget _buildStatusBar(int count) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Icon(Icons.storefront_outlined,
              size: 15, color: AppColors.neutral500),
          const SizedBox(width: 5),
          Text(
            '$count comercios abiertos ahora',
            style: AppTextStyles.bodySm,
          ),
          const Spacer(),
          Text(
            _horaActual(),
            style: AppTextStyles.labelSm
                .copyWith(color: AppColors.neutral500),
          ),
        ],
      ),
    );
  }

  String _horaActual() {
    final now = DateTime.now();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  // ── Filtros de categoría ──────────────────────────────────────────────────

  Widget _buildCategoryFilter() {
    return Container(
      color: AppColors.surface,
      child: Column(
        children: [
          const Divider(height: 1, color: AppColors.neutral100),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 0, 10),
            child: SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(right: 16),
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final cat = _categories[i];
                  final selected = cat == _selectedCategory;
                  return GestureDetector(
                    onTap: () =>
                        setState(() => _selectedCategory = cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary500
                            : AppColors.scaffoldBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: selected
                              ? AppColors.primary500
                              : AppColors.neutral300,
                        ),
                      ),
                      child: Text(
                        cat,
                        style: AppTextStyles.labelSm.copyWith(
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
          ),
        ],
      ),
    );
  }

  // ── Lista vacía ───────────────────────────────────────────────────────────

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.neutral100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.storefront_outlined,
                  size: 30, color: AppColors.neutral400),
            ),
            const SizedBox(height: 16),
            Text(
              'Sin ${_selectedCategory.toLowerCase()} abiertas',
              style: AppTextStyles.headingSm,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'No encontramos ${_selectedCategory.toLowerCase()} '
              'abiertas en este momento cerca de vos.',
              style: AppTextStyles.bodySm,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () =>
                  setState(() => _selectedCategory = 'Todos'),
              child: Text(
                'Ver todos los rubros',
                style: AppTextStyles.labelMd
                    .copyWith(color: AppColors.primary500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Barra "Ver en mapa" ───────────────────────────────────────────────────

  Widget _buildMapBar(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(AppRoutes.searchMap),
      child: Container(
        color: AppColors.primary500,
        padding: EdgeInsets.fromLTRB(
            20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.map_outlined, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              'Ver en el mapa',
              style:
                  AppTextStyles.labelMd.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tarjeta de comercio ───────────────────────────────────────────────────────

class _CommerceCard extends StatelessWidget {
  final ({
    String name,
    String type,
    String address,
    String distance,
    String zone,
    double rating,
    String closesAt,
    String action,
    bool actionFilled,
  }) commerce;
  final VoidCallback onTap;

  const _CommerceCard({required this.commerce, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = commerce;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            // Thumbnail
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.neutral100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.storefront_outlined,
                  color: AppColors.neutral400, size: 26),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.name,
                      style: AppTextStyles.labelMd,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('${c.type} · ${c.zone}',
                      style: AppTextStyles.bodyXs),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.near_me_outlined,
                          size: 12, color: AppColors.neutral500),
                      const SizedBox(width: 3),
                      Text(c.distance, style: AppTextStyles.bodyXs),
                      const SizedBox(width: 8),
                      Icon(Icons.access_time_rounded,
                          size: 12, color: AppColors.secondary500),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          c.closesAt,
                          style: AppTextStyles.bodyXs.copyWith(
                              color: AppColors.secondary700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Rating + Acción
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    Icon(Icons.star_rounded,
                        size: 13, color: AppColors.tertiary500),
                    const SizedBox(width: 2),
                    Text(c.rating.toStringAsFixed(1),
                        style: AppTextStyles.bodyXs
                            .copyWith(color: AppColors.neutral800)),
                  ],
                ),
                const SizedBox(height: 6),
                c.actionFilled
                    ? ElevatedButton(
                        onPressed: onTap,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary500,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          minimumSize: Size.zero,
                          textStyle: AppTextStyles.labelSm,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(7)),
                        ),
                        child: Text(c.action),
                      )
                    : OutlinedButton(
                        onPressed: onTap,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary500,
                          side: const BorderSide(
                              color: AppColors.primary300),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          minimumSize: Size.zero,
                          textStyle: AppTextStyles.labelSm,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(7)),
                        ),
                        child: Text(c.action),
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
