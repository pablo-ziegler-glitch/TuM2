import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../widgets/search_filters_sheet.dart';

/// Estado visual de la pantalla de resultados.
enum _ResultsMode { loading, results, empty, error, openNow, verified }

/// SEARCH-02 — Resultados de búsqueda.
///
/// Muestra resultados filtrados por query de texto o categoría.
/// Maneja los estados: cargando, resultados, sin resultados, error de red,
/// "abierto ahora" y "negocios verificados".
class SearchResultsScreen extends StatefulWidget {
  /// Término buscado (puede venir de query param ?q=).
  final String query;

  /// Si es true muestra el filtro "Abierto ahora" activo por defecto.
  final bool openNowFilter;

  const SearchResultsScreen({
    super.key,
    this.query = '',
    this.openNowFilter = false,
  });

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  late _ResultsMode _mode;
  late String _query;

  // Datos de ejemplo para el diseño
  static const _mockResults = [
    (
      name: 'Kiosco El Infinito',
      type: 'Kiosco',
      address: 'Av. Santa Fe 2345',
      distance: '250m',
      zone: 'Palermo Soho',
      rating: 4.3,
      status: 'ABIERTO',
      statusColor: _statusGreen,
      is24h: false,
    ),
    (
      name: 'MaxiKiosco Javi',
      type: 'Kiosco',
      address: 'Honduras 4890',
      distance: '380m',
      zone: 'Palermo Viejo',
      rating: 4.1,
      status: 'ABIERTO',
      statusColor: _statusGreen,
      is24h: false,
    ),
    (
      name: 'Open 26',
      type: 'Kiosco',
      address: 'Thames 1450',
      distance: '510m',
      zone: 'Palermo',
      rating: 4.5,
      status: 'ABIERTO · 24hs',
      statusColor: _statusPurple,
      is24h: true,
    ),
    (
      name: 'Kiosco de la Biblioteca',
      type: 'Kiosco',
      address: 'Borges 2241',
      distance: '720m',
      zone: 'Palermo',
      rating: 3.8,
      status: 'CERRADO',
      statusColor: _statusOrange,
      is24h: false,
    ),
  ];

  static const _mockOpenNow = [
    (
      name: 'Café de la Esquina',
      type: 'Cafetería',
      distance: '180m',
      action: 'Ver Más',
      actionStyle: _ActionStyle.outline,
    ),
    (
      name: 'Hotel Boutique Soho',
      type: 'Hotel',
      distance: '340m',
      action: 'Reservar',
      actionStyle: _ActionStyle.filled,
    ),
    (
      name: 'La Florería',
      type: 'Florería',
      distance: '450m',
      action: 'Top Ventas',
      actionStyle: _ActionStyle.badge,
    ),
    (
      name: 'Mercado Local',
      type: 'Mercado',
      distance: '600m',
      action: 'Producto Fresco',
      actionStyle: _ActionStyle.badge,
    ),
  ];

  static const _statusGreen = Color(0xFF0F766E);
  static const _statusOrange = Color(0xFFFF8D46);
  static const _statusPurple = Color(0xFF7C3AED);

  @override
  void initState() {
    super.initState();
    _query = widget.query;
    _mode = widget.openNowFilter ? _ResultsMode.openNow : _ResultsMode.loading;
    if (!widget.openNowFilter) _simulateLoad();
  }

  /// Simula carga de datos (en producción será reemplazado por Firestore query).
  Future<void> _simulateLoad() async {
    await Future.delayed(const Duration(milliseconds: 900));
    if (mounted) {
      setState(() {
        _mode = _query.toLowerCase() == 'xyz_no_results'
            ? _ResultsMode.empty
            : _ResultsMode.results;
      });
    }
  }

  Future<void> _retry() async {
    setState(() => _mode = _ResultsMode.loading);
    await _simulateLoad();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(
        children: [
          _buildHeader(context),
          if (_mode == _ResultsMode.results ||
              _mode == _ResultsMode.openNow ||
              _mode == _ResultsMode.verified)
            _buildResultsMeta(),
          Expanded(
            child: switch (_mode) {
              _ResultsMode.loading => _buildLoadingState(),
              _ResultsMode.results => _buildResultsList(context),
              _ResultsMode.empty => _buildEmptyState(context),
              _ResultsMode.error => _buildErrorState(),
              _ResultsMode.openNow => _buildOpenNowList(context),
              _ResultsMode.verified => _buildVerifiedList(context),
            },
          ),
          if (_mode == _ResultsMode.results || _mode == _ResultsMode.openNow)
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
          16, MediaQuery.of(context).padding.top + 12, 16, 10),
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
            child: GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.scaffoldBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 10),
                    Icon(Icons.search,
                        color: AppColors.neutral400, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _query.isEmpty ? 'Buscar...' : _query,
                        style: AppTextStyles.bodyMd.copyWith(
                          color: _query.isEmpty
                              ? AppColors.neutral400
                              : AppColors.neutral900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => SearchFiltersSheet.show(context),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primary50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.tune_rounded,
                  color: AppColors.primary500, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  // ── Metadatos de resultados (zona + cantidad) ─────────────────────────────

  Widget _buildResultsMeta() {
    final count = _mode == _ResultsMode.openNow
        ? _mockOpenNow.length
        : _mockResults.length;
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primary50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_on_outlined,
                    size: 13, color: AppColors.primary500),
                const SizedBox(width: 3),
                Text('Palermo',
                    style: AppTextStyles.labelSm
                        .copyWith(color: AppColors.primary600)),
              ],
            ),
          ),
          if (_mode == _ResultsMode.openNow) ...[
            const SizedBox(width: 6),
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
                  Icon(Icons.circle,
                      size: 7, color: AppColors.secondary500),
                  const SizedBox(width: 4),
                  Text('Abierto ahora',
                      style: AppTextStyles.labelSm
                          .copyWith(color: AppColors.secondary600)),
                ],
              ),
            ),
          ],
          const Spacer(),
          Text(
            '$count resultados',
            style: AppTextStyles.bodySm,
          ),
        ],
      ),
    );
  }

  // ── ESTADO: cargando ─────────────────────────────────────────────────────

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      itemCount: 5,
      itemBuilder: (_, __) => _SkeletonCard(),
    );
  }

  // ── ESTADO: resultados ───────────────────────────────────────────────────

  Widget _buildResultsList(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      itemCount: _mockResults.length,
      itemBuilder: (_, i) {
        final r = _mockResults[i];
        return GestureDetector(
          onTap: () => context
              .push(AppRoutes.commerceDetailPath(r.name.toLowerCase().replaceAll(' ', '-'))),
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
                    offset: const Offset(0, 2))
              ],
            ),
            child: Row(
              children: [
                // Thumbnail
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.neutral200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.store_outlined,
                      color: AppColors.neutral500, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(r.name,
                                style: AppTextStyles.labelMd,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: r.statusColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              r.status,
                              style: AppTextStyles.bodyXs.copyWith(
                                color: r.statusColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text('${r.address} · ${r.zone}',
                          style: AppTextStyles.bodyXs,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.near_me_outlined,
                              size: 12, color: AppColors.neutral500),
                          const SizedBox(width: 3),
                          Text(r.distance, style: AppTextStyles.bodyXs),
                          const Spacer(),
                          Icon(Icons.star_rounded,
                              size: 14, color: AppColors.tertiary500),
                          const SizedBox(width: 2),
                          Text('${r.rating}',
                              style: AppTextStyles.bodyXs
                                  .copyWith(color: AppColors.neutral800)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── ESTADO: "Abierto ahora" ──────────────────────────────────────────────

  Widget _buildOpenNowList(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      children: [
        // Chip activo indicador
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Wrap(
            spacing: 6,
            children: [
              _chip('BUSCANDO ACTIVA', AppColors.neutral200, AppColors.neutral700),
              _chip('Cerca de ti', AppColors.primary50, AppColors.primary600),
              _chip('Abierto ahora', AppColors.secondary50, AppColors.secondary700),
            ],
          ),
        ),
        ..._mockOpenNow.map((r) => _OpenNowCard(item: r, context: context)),
        const SizedBox(height: 16),
        // Mini mapa
        Container(
          height: 90,
          decoration: BoxDecoration(
            color: const Color(0xFF4A6741),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Icon(Icons.map_outlined,
                    color: Colors.white.withOpacity(0.1), size: 70),
              ),
              Center(
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: AppColors.primary500,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.location_on,
                      color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'Llegaste al final de los resultados ahora.',
            style: AppTextStyles.bodyXs,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: GestureDetector(
            onTap: () {},
            child: Text(
              'Ver tiendas cerradas',
              style: AppTextStyles.labelSm
                  .copyWith(color: AppColors.primary500),
            ),
          ),
        ),
      ],
    );
  }

  // ── ESTADO: negocios verificados ─────────────────────────────────────────

  Widget _buildVerifiedList(BuildContext context) {
    final items = [
      (
        name: 'Origen Coffee Studio',
        type: 'Cafetería · Palermo',
        rating: 4.2,
        verified: true,
        hasPhoto: false,
      ),
      (
        name: 'La Finca Azul',
        type: 'Restaurante · Recoleta',
        rating: 4.5,
        verified: true,
        hasPhoto: false,
      ),
      (
        name: 'Botanica El Olmo',
        type: 'Floristería · San Telmo',
        rating: 4.0,
        verified: false,
        hasPhoto: false,
      ),
      (
        name: 'Taller de Cerámica Alva',
        type: 'Arte & Diseño · Palermo',
        rating: 4.7,
        verified: true,
        hasPhoto: true,
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header descriptivo
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Negocios Verificados', style: AppTextStyles.headingSm),
              const SizedBox(height: 4),
              Text(
                'Establecimientos que han superado nuestros estándares de confianza y calidad.',
                style: AppTextStyles.bodySm,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Filtros
        Row(
          children: [
            _chip('Más reciente', AppColors.neutral200, AppColors.neutral700),
            const SizedBox(width: 8),
            _chip('Más relevante', AppColors.primary50, AppColors.primary600),
          ],
        ),
        const SizedBox(height: 12),
        // Chips categoría
        Wrap(
          spacing: 8,
          children: [
            _chipBadge('VERIFICADO', AppColors.primary500),
            _chipBadge('RECOMENDADO', AppColors.secondary500),
          ],
        ),
        const SizedBox(height: 14),
        // Lista
        ...items.map(
          (item) => GestureDetector(
            onTap: () => context.push(
                AppRoutes.commerceDetailPath(item.name.toLowerCase().replaceAll(' ', '-'))),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.hasPhoto)
                    Container(
                      height: 100,
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B6914),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Icon(Icons.storefront_outlined,
                            color: Colors.white.withOpacity(0.3), size: 40),
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(item.name, style: AppTextStyles.labelMd),
                      ),
                      Row(
                        children: [
                          Icon(Icons.star_rounded,
                              size: 14, color: AppColors.tertiary500),
                          const SizedBox(width: 2),
                          Text('${item.rating}',
                              style: AppTextStyles.bodyXs
                                  .copyWith(color: AppColors.neutral800)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(item.type, style: AppTextStyles.bodyXs),
                  if (item.verified) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.verified_outlined,
                            size: 14, color: AppColors.primary500),
                        const SizedBox(width: 4),
                        Text('Verificado por TuM2',
                            style: AppTextStyles.labelSm.copyWith(
                                color: AppColors.primary600)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        // Sección de sellos explicativos
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('¿Qué significan estos sellos?',
                  style: AppTextStyles.headingSm),
              const SizedBox(height: 12),
              _buildSelloRow(
                icon: Icons.verified_outlined,
                color: AppColors.primary500,
                title: 'Sello Verificado',
                desc: 'El local fue visitado y verificado por nuestro equipo editorial.',
              ),
              const SizedBox(height: 10),
              _buildSelloRow(
                icon: Icons.star_outline_rounded,
                color: AppColors.tertiary500,
                title: 'Perfil Destacado',
                desc: 'Negocios con perfil completo y alta participación en la plataforma.',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSelloRow({
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.labelMd),
              const SizedBox(height: 2),
              Text(desc, style: AppTextStyles.bodyXs),
            ],
          ),
        ),
      ],
    );
  }

  // ── ESTADO: sin resultados ───────────────────────────────────────────────

  Widget _buildEmptyState(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 16),
        Text(
          'No encontramos lo que buscás, pero mirá esto cerca...',
          style: AppTextStyles.headingSm,
        ),
        const SizedBox(height: 8),
        Text(
          'Intentamos buscar en toda la zona pero no hubo coincidencias. '
          '¿Quisiste buscar algo similar?',
          style: AppTextStyles.bodySm,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.zoom_out_map, size: 18),
            label: const Text('Ampliar zona'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary500,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              textStyle: AppTextStyles.labelMd,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text('Categorías populares cerca',
            style: AppTextStyles.labelSm
                .copyWith(color: AppColors.neutral600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ['Gastronomía', 'Modo Local', 'Servicios']
              .map((c) => _chip(c, AppColors.surface, AppColors.neutral800))
              .toList(),
        ),
        const SizedBox(height: 20),
        Text('Recomendados para vos', style: AppTextStyles.headingSm),
        const SizedBox(height: 12),
        // Comercios recomendados
        ...[
          (
            name: 'La Panera Rosa',
            type: 'Pastelería · Palermo',
            rating: 4.8,
            desc:
                'Pastelería artesanal y café de especialidad en un ambiente acogedor y moderno.',
          ),
          (
            name: 'Concept Store BUE',
            type: 'Diseño · San Telmo',
            rating: 4.5,
            desc:
                'Selección curada de diseño local, accesorios y objetos de decoración únicos.',
          ),
        ].map(
          (r) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badge distancia
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.neutral100,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text('A 1.2KM',
                      style: AppTextStyles.bodyXs
                          .copyWith(fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                        child: Text(r.name, style: AppTextStyles.labelMd)),
                    Row(children: [
                      Icon(Icons.star_rounded,
                          size: 14, color: AppColors.tertiary500),
                      Text(' ${r.rating}', style: AppTextStyles.bodyXs),
                    ]),
                  ],
                ),
                const SizedBox(height: 3),
                Text(r.desc,
                    style: AppTextStyles.bodySm, maxLines: 2),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {},
                  child: Text('Explorar comercio →',
                      style: AppTextStyles.labelSm
                          .copyWith(color: AppColors.primary500)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Acciones finales
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('¿No encontrás lo que buscás?',
                  style: AppTextStyles.labelMd),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 42,
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.add_business_outlined, size: 16),
                  label: const Text('Sugerir un comercio'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary500,
                    side: const BorderSide(color: AppColors.primary300),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.help_outline,
                    size: 18, color: AppColors.neutral600),
                title: Text('Centro de ayuda',
                    style: AppTextStyles.bodyMd),
                subtitle: Text('Consejos para una mejor búsqueda',
                    style: AppTextStyles.bodyXs),
                trailing: Icon(Icons.chevron_right,
                    color: AppColors.neutral400),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── ESTADO: error de red ─────────────────────────────────────────────────

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.neutral100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.wifi_off_rounded,
                  size: 40, color: AppColors.neutral500),
            ),
            const SizedBox(height: 20),
            Text('Parece que no hay conexión',
                style: AppTextStyles.headingSm, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Estamos teniendo problemas para contactar con nuestro servidor. '
              'Por favor, revisá tu conexión a Internet e intentalo de nuevo.',
              style: AppTextStyles.bodySm,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 160,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary500,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('OPCIONES OFFLINE',
                  style: AppTextStyles.labelSm.copyWith(
                      color: AppColors.neutral500, letterSpacing: 1.1)),
            ),
            const SizedBox(height: 10),
            _offlineOption(Icons.history, 'Últimas búsquedas',
                'Accedé a las zonas que visitaste recientemente sin conexión.'),
            const SizedBox(height: 8),
            _offlineOption(Icons.map_outlined, 'Mapa guardado',
                'Navegá las calles del barrio con la cartografía local descargada.'),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              children: ['Palermo', 'Belgrano', 'Recoleta']
                  .map((z) => _chip(z, AppColors.neutral100, AppColors.neutral800))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _offlineOption(IconData icon, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.neutral100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.neutral600, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.labelMd),
              Text(desc, style: AppTextStyles.bodyXs),
            ],
          ),
        ),
      ],
    );
  }

  // ── Barra "Vista en el mapa" ──────────────────────────────────────────────

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
            Text('Vista en mapa',
                style: AppTextStyles.labelMd.copyWith(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _chip(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Text(label,
          style: AppTextStyles.labelSm.copyWith(color: fg)),
    );
  }

  Widget _chipBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
          style: AppTextStyles.labelSm
              .copyWith(color: color, fontWeight: FontWeight.w600)),
    );
  }
}

// ── OpenNow card ─────────────────────────────────────────────────────────────

enum _ActionStyle { filled, outline, badge }

class _OpenNowCard extends StatelessWidget {
  final ({
    String name,
    String type,
    String distance,
    String action,
    _ActionStyle actionStyle,
  }) item;
  final BuildContext context;

  const _OpenNowCard({required this.item, required this.context});

  @override
  Widget build(BuildContext ctx) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.neutral200,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.storefront_outlined,
                color: AppColors.neutral500, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: AppTextStyles.labelMd),
                const SizedBox(height: 2),
                Text('${item.type} · ${item.distance}',
                    style: AppTextStyles.bodyXs),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _buildAction(),
        ],
      ),
    );
  }

  Widget _buildAction() {
    switch (item.actionStyle) {
      case _ActionStyle.filled:
        return ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary500,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: Size.zero,
            textStyle: AppTextStyles.labelSm,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(item.action),
        );
      case _ActionStyle.outline:
        return OutlinedButton(
          onPressed: () {},
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary500,
            side: const BorderSide(color: AppColors.primary300),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: Size.zero,
            textStyle: AppTextStyles.labelSm,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(item.action),
        );
      case _ActionStyle.badge:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.secondary50,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(item.action,
              style: AppTextStyles.labelSm
                  .copyWith(color: AppColors.secondary700)),
        );
    }
  }
}

// ── Skeleton card (loading) ───────────────────────────────────────────────────

class _SkeletonCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _box(64, 64, radius: 10),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _box(16, double.infinity),
                const SizedBox(height: 6),
                _box(12, 160),
                const SizedBox(height: 6),
                _box(12, 100),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _box(double h, double w, {double radius = 6}) {
    return Container(
      height: h,
      width: w == double.infinity ? null : w,
      decoration: BoxDecoration(
        color: AppColors.neutral100,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
