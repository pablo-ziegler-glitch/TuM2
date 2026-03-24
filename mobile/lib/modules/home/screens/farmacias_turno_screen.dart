import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// HOME-03 — Vista "Farmacias de turno".
///
/// Muestra las farmacias que están de guardia hoy en la zona activa.
/// La primera entrada es la farmacia de turno activa en este momento;
/// las siguientes son las farmacias en rotación del día.
///
/// Fuente: `merchant_public` filtrado `isOnDutyToday == true`
///         + colección `pharmacy_duties`.
/// Salida: → DETAIL-01, → mapa nativo, → llamada nativa.
class FarmaciasTurnoScreen extends StatelessWidget {
  const FarmaciasTurnoScreen({super.key});

  // Datos de ejemplo para el diseño
  static const _dutyPharmacies = [
    (
      name: 'Farmacia Central del Parque',
      address: 'Av. Santa Fe 3480, Palermo',
      phone: '011 4831-2200',
      distance: '450m',
      hours: 'Turno activo: 22:00 → 08:00',
      isActive: true,
      rating: 4.6,
    ),
    (
      name: 'Farmacia Nova',
      address: 'Thames 1820, Palermo',
      phone: '011 4832-1100',
      distance: '780m',
      hours: 'Turno: 08:00 → 14:00',
      isActive: false,
      rating: 4.3,
    ),
    (
      name: 'Farmacia Dr. Pérez',
      address: 'Honduras 5180, Palermo',
      phone: '011 4833-9900',
      distance: '920m',
      hours: 'Turno: 14:00 → 22:00',
      isActive: false,
      rating: 4.1,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(context)),
          SliverToBoxAdapter(child: _buildHoy()),
          SliverToBoxAdapter(child: _buildActivaHero(context)),
          SliverToBoxAdapter(child: _buildRestantesHeader()),
          ..._dutyPharmacies.skip(1).map(
                (p) => SliverToBoxAdapter(
                  child: _PharmacyListItem(pharmacy: p, context: context),
                ),
              ),
          SliverToBoxAdapter(child: _buildDisclaimer()),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    final now = DateTime.now();
    final weekdays = [
      'Lunes', 'Martes', 'Miércoles', 'Jueves',
      'Viernes', 'Sábado', 'Domingo'
    ];
    final months = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
    ];
    final dateStr =
        '${weekdays[now.weekday - 1]} ${now.day} de ${months[now.month - 1]}';

    return Container(
      color: AppColors.surface,
      padding: EdgeInsets.fromLTRB(
          16, MediaQuery.of(context).padding.top + 12, 16, 14),
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
                  dateStr.toUpperCase(),
                  style: AppTextStyles.labelSm.copyWith(
                    color: AppColors.neutral500,
                    letterSpacing: 1.1,
                  ),
                ),
                Text('Farmacias de turno',
                    style: AppTextStyles.headingSm),
              ],
            ),
          ),
          // Badge "HOY"
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.secondary500,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'HOY',
              style: AppTextStyles.labelSm.copyWith(
                color: Colors.white,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Zona activa ────────────────────────────────────────────────────────────

  Widget _buildHoy() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          Icon(Icons.location_on_outlined,
              size: 15, color: AppColors.neutral500),
          const SizedBox(width: 4),
          Text('Palermo · 3 farmacias de turno hoy',
              style: AppTextStyles.bodySm),
        ],
      ),
    );
  }

  // ── Hero: farmacia activa ahora ───────────────────────────────────────────

  Widget _buildActivaHero(BuildContext context) {
    final p = _dutyPharmacies.first;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen placeholder con badge ACTIVA AHORA
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: Container(
                height: 120,
                width: double.infinity,
                color: const Color(0xFF1A5276),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Center(
                      child: Icon(Icons.local_pharmacy,
                          color: Colors.white.withOpacity(0.15), size: 60),
                    ),
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
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'ACTIVA AHORA',
                              style: AppTextStyles.bodyXs.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Row(
                        children: [
                          Icon(Icons.star_rounded,
                              size: 13, color: AppColors.tertiary300),
                          const SizedBox(width: 2),
                          Text(
                            p.rating.toStringAsFixed(1),
                            style: AppTextStyles.bodyXs
                                .copyWith(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Contenido
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name, style: AppTextStyles.headingSm),
                  const SizedBox(height: 8),
                  _infoRow(Icons.location_on_outlined, p.address),
                  const SizedBox(height: 4),
                  _infoRow(Icons.access_time_rounded, p.hours,
                      color: AppColors.secondary600),
                  const SizedBox(height: 4),
                  _infoRow(Icons.near_me_outlined, p.distance),
                  const SizedBox(height: 14),
                  // Acciones
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => context.push(
                            AppRoutes.commerceDetailPath(
                              p.name.toLowerCase().replaceAll(' ', '-'),
                            ),
                          ),
                          icon: const Icon(Icons.directions, size: 16),
                          label: const Text('Cómo llegar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary500,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            textStyle: AppTextStyles.labelMd,
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Botón llamar
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: AppColors.scaffoldBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.neutral200),
                        ),
                        child: Icon(Icons.phone_outlined,
                            color: AppColors.neutral700, size: 20),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header de "Resto del día" ─────────────────────────────────────────────

  Widget _buildRestantesHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 8),
      child: Row(
        children: [
          Text('Resto del día', style: AppTextStyles.headingSm),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.neutral100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${_dutyPharmacies.length - 1} más',
              style: AppTextStyles.bodyXs,
            ),
          ),
        ],
      ),
    );
  }

  // ── Disclaimer ────────────────────────────────────────────────────────────

  Widget _buildDisclaimer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.tertiary50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.tertiary200),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline,
                size: 18, color: AppColors.tertiary600),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Información de turnos',
                    style: AppTextStyles.labelMd
                        .copyWith(color: AppColors.tertiary700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Los turnos son informados por el Colegio de Farmacéuticos '
                    'y se actualizan cada 30 minutos. Verificá con la farmacia '
                    'ante cualquier duda.',
                    style: AppTextStyles.bodyXs
                        .copyWith(color: AppColors.tertiary700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helper ────────────────────────────────────────────────────────────────

  Widget _infoRow(IconData icon, String text, {Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color ?? AppColors.neutral500),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodySm.copyWith(color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ── Ítem de farmacia en lista ─────────────────────────────────────────────────

class _PharmacyListItem extends StatelessWidget {
  final ({
    String name,
    String address,
    String phone,
    String distance,
    String hours,
    bool isActive,
    double rating,
  }) pharmacy;
  final BuildContext context;

  const _PharmacyListItem(
      {required this.pharmacy, required this.context});

  @override
  Widget build(BuildContext ctx) {
    final p = pharmacy;
    return GestureDetector(
      onTap: () => context.push(
        AppRoutes.commerceDetailPath(
          p.name.toLowerCase().replaceAll(' ', '-'),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        padding: const EdgeInsets.all(14),
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
            // Ícono
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.secondary50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.local_pharmacy_outlined,
                  color: AppColors.secondary500, size: 20),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name,
                      style: AppTextStyles.labelMd,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(p.address,
                      style: AppTextStyles.bodyXs,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded,
                          size: 12, color: AppColors.neutral500),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(p.hours,
                            style: AppTextStyles.bodyXs,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Distancia + flecha
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(p.distance, style: AppTextStyles.bodyXs),
                const SizedBox(height: 4),
                Icon(Icons.chevron_right,
                    color: AppColors.neutral400, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
