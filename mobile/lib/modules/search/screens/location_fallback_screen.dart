import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Pantalla de fallback cuando no se puede acceder a la ubicación GPS.
///
/// Permite al usuario seleccionar manualmente su barrio para personalizar
/// el descubrimiento de comercios cercanos. Se muestra cuando:
/// - El usuario deniega el permiso de ubicación.
/// - El GPS no está disponible.
/// - La zona no puede determinarse automáticamente.
class LocationFallbackScreen extends StatefulWidget {
  const LocationFallbackScreen({super.key});

  @override
  State<LocationFallbackScreen> createState() => _LocationFallbackScreenState();
}

class _LocationFallbackScreenState extends State<LocationFallbackScreen> {
  String? _selectedZone;
  final _controller = TextEditingController();

  static const _suggestedZones = [
    (
      name: 'Palermo',
      sub: 'CABA, ARGENTINA',
      icon: Icons.location_city_outlined,
      popular: false
    ),
    (
      name: 'Recoleta',
      sub: 'CABA, ARGENTINA',
      icon: Icons.location_city_outlined,
      popular: false
    ),
    (
      name: 'Belgrano',
      sub: 'CABA, ARGENTINA',
      icon: Icons.park_outlined,
      popular: true
    ),
    (
      name: 'San Telmo',
      sub: 'Casco Histórico',
      icon: Icons.museum_outlined,
      popular: false
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirmZone() {
    final zone = _selectedZone ?? _controller.text.trim();
    if (zone.isNotEmpty) {
      context.go(AppRoutes.search);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildTopSection(context)),
            SliverToBoxAdapter(child: _buildSearchInput()),
            SliverToBoxAdapter(child: _buildZoneList()),
            SliverToBoxAdapter(child: _buildWhySection()),
            SliverToBoxAdapter(child: _buildMapSection(context)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: GestureDetector(
                  onTap: () => context.go(AppRoutes.search),
                  child: Center(
                    child: Text(
                      'Explorar toda la ciudad',
                      style: AppTextStyles.labelMd
                          .copyWith(color: AppColors.primary500),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Sección superior ──────────────────────────────────────────────────────

  Widget _buildTopSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ícono de GPS deshabilitado
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.tertiary50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.location_off_outlined,
                size: 32, color: AppColors.tertiary500),
          ),
          const SizedBox(height: 16),
          const Text('Encontrá tu próximo\nlugar favorito',
              style: AppTextStyles.headingLg),
          const SizedBox(height: 8),
          const Text(
            'No pudimos acceder a tu ubicación actual. '
            'Seleccioná manualmente tu barrio para explorar lo mejor de tu zona.',
            style: AppTextStyles.bodySm,
          ),
        ],
      ),
    );
  }

  // ── Input de búsqueda manual ──────────────────────────────────────────────

  Widget _buildSearchInput() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.neutral200),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: TextField(
          controller: _controller,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Escribí tu barrio o localidad...',
            hintStyle:
                AppTextStyles.bodyMd.copyWith(color: AppColors.neutral400),
            prefixIcon:
                const Icon(Icons.search, color: AppColors.neutral400, size: 20),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 0, vertical: 14),
          ),
          style: AppTextStyles.bodyMd,
        ),
      ),
    );
  }

  // ── Lista de zonas sugeridas ──────────────────────────────────────────────

  Widget _buildZoneList() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        children: _suggestedZones.map((zone) {
          final isSelected = _selectedZone == zone.name;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedZone = zone.name);
              _controller.clear();
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary50 : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      isSelected ? AppColors.primary400 : AppColors.neutral200,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary100
                          : AppColors.neutral100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      zone.icon,
                      size: 18,
                      color: isSelected
                          ? AppColors.primary500
                          : AppColors.neutral600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(zone.name, style: AppTextStyles.labelMd),
                            if (zone.popular) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.secondary50,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text('Popular',
                                    style: AppTextStyles.bodyXs.copyWith(
                                        color: AppColors.secondary700)),
                              ),
                            ],
                          ],
                        ),
                        Text(zone.sub, style: AppTextStyles.bodyXs),
                      ],
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.check_circle_rounded,
                        color: AppColors.primary500, size: 20),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Sección "¿Por qué?" ───────────────────────────────────────────────────

  Widget _buildWhySection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.neutral200),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.help_outline, size: 18, color: AppColors.neutral600),
                SizedBox(width: 8),
                Text('¿Por qué seleccionar una zona?',
                    style: AppTextStyles.labelMd),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Al elegir un barrio, podemos mostrarte comercios con '
              'aviso rápido, promociones locales exclusivas y eventos '
              'que están sucediendo ahora mismo cerca tuyo.',
              style: AppTextStyles.bodySm,
            ),
          ],
        ),
      ),
    );
  }

  // ── Sección mapa interactivo ──────────────────────────────────────────────

  Widget _buildMapSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        children: [
          // Botón mapa interactivo
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              onPressed: () => context.push(AppRoutes.searchMap),
              icon: const Icon(Icons.map_outlined, size: 18),
              label: const Text('Seleccionar en el mapa interactivo'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary500,
                side: const BorderSide(color: AppColors.primary300),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                textStyle: AppTextStyles.labelMd,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Mini mapa placeholder
          if (_selectedZone != null || _controller.text.isNotEmpty) ...[
            GestureDetector(
              onTap: () => context.push(AppRoutes.searchMap),
              child: Container(
                height: 120,
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
                          color: Colors.white.withValues(alpha: 0.1), size: 80),
                    ),
                    Center(
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: AppColors.primary500,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.location_on,
                            color: Colors.white, size: 20),
                      ),
                    ),
                    Positioned(
                      bottom: 10,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            _selectedZone ?? _controller.text,
                            style: AppTextStyles.labelSm
                                .copyWith(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Confirmar selección
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _confirmZone,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary500,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  textStyle: AppTextStyles.labelMd,
                ),
                child: Text('Confirmar: ${_selectedZone ?? _controller.text}'),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
