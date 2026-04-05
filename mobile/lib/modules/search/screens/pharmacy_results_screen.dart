import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// SEARCH — Especialidad Farmacias.
///
/// Vista dedicada a la categoría de farmacias con énfasis en:
/// - Farmacia de turno destacada (hero card)
/// - Grid de farmacias abiertas ahora
/// - Información de confianza y verificación
///
/// Accedida desde "Farmacias de turno" en los accesos rápidos de SEARCH-01.
class PharmacyResultsScreen extends StatefulWidget {
  const PharmacyResultsScreen({super.key});

  @override
  State<PharmacyResultsScreen> createState() => _PharmacyResultsScreenState();
}

class _PharmacyResultsScreenState extends State<PharmacyResultsScreen> {
  bool _filterTurno = true;
  bool _filterAbierto = false;
  bool _filter24h = false;

  static const _nearbyPharmacies = [
    (name: 'Farmacia Nova', distance: '180m', open: true),
    (name: 'Farmacia Dr. Pérez', distance: '290m', open: true),
    (name: 'Farmacia Palermo', distance: '450m', open: true),
    (name: 'Farmacia del Sol', distance: '680m', open: false),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(context)),
          SliverToBoxAdapter(child: _buildSearchAndFilters()),
          SliverToBoxAdapter(child: _buildHeroFarmacia(context)),
          SliverToBoxAdapter(child: _buildNearbySection()),
          SliverToBoxAdapter(child: _buildTrustSection()),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
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
              child:
                  Icon(Icons.arrow_back, color: AppColors.neutral700, size: 22),
            ),
          ),
          Expanded(
            child: Text('TuM2',
                style: AppTextStyles.headingMd.copyWith(
                  color: AppColors.primary500,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                )),
          ),
          // Zona + estado
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.neutral100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on_outlined,
                        size: 13, color: AppColors.neutral600),
                    const SizedBox(width: 3),
                    Text('Palermo, 34m', style: AppTextStyles.bodyXs),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.secondary50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.circle, size: 7, color: AppColors.secondary500),
                    const SizedBox(width: 4),
                    Text('Abierto ahora',
                        style: AppTextStyles.bodyXs
                            .copyWith(color: AppColors.secondary700)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Search bar + filtros de farmacia ─────────────────────────────────────

  Widget _buildSearchAndFilters() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(
        children: [
          // Search bar (decorativo)
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.scaffoldBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const SizedBox(width: 10),
                Icon(Icons.search, color: AppColors.neutral400, size: 18),
                const SizedBox(width: 6),
                Text('Farmacia',
                    style: AppTextStyles.bodyMd
                        .copyWith(color: AppColors.neutral700)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Filtros específicos de farmacia
          Row(
            children: [
              _filterChip(
                label: 'De Turno',
                active: _filterTurno,
                onTap: () => setState(() => _filterTurno = !_filterTurno),
              ),
              const SizedBox(width: 8),
              _filterChip(
                label: 'Abierto ahora',
                active: _filterAbierto,
                onTap: () => setState(() => _filterAbierto = !_filterAbierto),
              ),
              const SizedBox(width: 8),
              _filterChip(
                label: '24hs',
                active: _filter24h,
                onTap: () => setState(() => _filter24h = !_filter24h),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.primary500 : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? AppColors.primary500 : AppColors.neutral300,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelSm.copyWith(
            color: active ? AppColors.surface : AppColors.neutral700,
          ),
        ),
      ),
    );
  }

  // ── Hero: Farmacia de turno destacada ─────────────────────────────────────

  Widget _buildHeroFarmacia(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 3))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen placeholder de la farmacia
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: Container(
                height: 140,
                width: double.infinity,
                color: const Color(0xFF1A5276),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Center(
                      child: Icon(Icons.local_pharmacy,
                          color: Colors.white.withOpacity(0.2), size: 70),
                    ),
                    // Badge de turno
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.secondary500,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'FARMACIA · DE TURNO',
                          style: AppTextStyles.bodyXs.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Contenido
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Farmacia Central del Parque',
                      style: AppTextStyles.headingSm),
                  const SizedBox(height: 6),
                  Text(
                    'Abierta 24hs hoy. Atención prioritaria por ventanilla '
                    'nocturna. Ubicada a solo 450 metros.',
                    style: AppTextStyles.bodySm,
                  ),
                  const SizedBox(height: 14),
                  // CTA: Cómo llegar
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.directions, size: 18),
                      label: const Text('CÓMO LLEGAR'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary500,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        textStyle: AppTextStyles.labelMd,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // CTA: Llamar
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.phone_outlined, size: 18),
                      label: const Text('LLAMAR AHORA'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.neutral800,
                        side: const BorderSide(color: AppColors.neutral300),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        textStyle: AppTextStyles.labelMd,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Grid de farmacias abiertas cerca ──────────────────────────────────────

  Widget _buildNearbySection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Abiertas ahora cerca de ti', style: AppTextStyles.headingSm),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.6,
            children: _nearbyPharmacies
                .map((p) => _PharmacyCard(pharmacy: p))
                .toList(),
          ),
        ],
      ),
    );
  }

  // ── Sección de confianza ──────────────────────────────────────────────────

  Widget _buildTrustSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.neutral200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tu salud, nuestra prioridad', style: AppTextStyles.headingSm),
            const SizedBox(height: 8),
            Text(
              'Avalamos únicamente farmacias habilitadas por el Ministerio de Salud. '
              'La información de farmacias de turno se actualiza cada 30 minutos '
              'para garantizar exactitud.',
              style: AppTextStyles.bodySm,
            ),
            const SizedBox(height: 14),
            // Badge verificado
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.secondary50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified_outlined,
                      size: 16, color: AppColors.secondary500),
                  const SizedBox(width: 6),
                  Text(
                    'Verificado por profesionales locales',
                    style: AppTextStyles.labelSm
                        .copyWith(color: AppColors.secondary700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Stats
            Row(
              children: [
                Expanded(
                  child: _statBadge(
                    icon: Icons.local_pharmacy_outlined,
                    value: '937',
                    label: 'Farmacias',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _statBadge(
                    icon: Icons.access_time_rounded,
                    value: '24/7',
                    label: 'Atención',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statBadge({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.scaffoldBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary500),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: AppTextStyles.headingSm
                      .copyWith(fontSize: 15, color: AppColors.primary600)),
              Text(label, style: AppTextStyles.bodyXs),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Tarjeta de farmacia cercana ───────────────────────────────────────────────

class _PharmacyCard extends StatefulWidget {
  final ({String name, String distance, bool open}) pharmacy;

  const _PharmacyCard({required this.pharmacy});

  @override
  State<_PharmacyCard> createState() => _PharmacyCardState();
}

class _PharmacyCardState extends State<_PharmacyCard> {
  bool _liked = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.pharmacy;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.secondary50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.local_pharmacy_outlined,
                    size: 16, color: AppColors.secondary500),
              ),
              GestureDetector(
                onTap: () => setState(() => _liked = !_liked),
                child: Icon(
                  _liked ? Icons.favorite : Icons.favorite_border,
                  size: 18,
                  color: _liked ? AppColors.errorFg : AppColors.neutral400,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.name,
                  style: AppTextStyles.labelSm,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.near_me_outlined,
                      size: 11, color: AppColors.neutral500),
                  const SizedBox(width: 2),
                  Text(p.distance, style: AppTextStyles.bodyXs),
                  const Spacer(),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: p.open
                          ? AppColors.secondary500
                          : AppColors.tertiary500,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
