import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

// ── Demo data (reemplazar con carga Firestore en TuM2-0061) ──────────────────

typedef _PharmacyDetail = ({
  String name,
  String address,
  String distanceText,
  String phone,
  String dutyUntil,
  String source,
  String verifiedAgo,
  String hours,
});

const Map<String, _PharmacyDetail> _demoDetails = {
  'farmacia-central-palermo': (
    name: 'Farmacia Central Palermo',
    address: 'Av. Independencia 1420, Ciudad Autónoma de Buenos Aires',
    distanceText: 'A 450m de tu ubicación actual',
    phone: '+54 11 4321-9876',
    dutyUntil: 'DE TURNO HASTA MAÑANA 08:30',
    source: 'MINISTERIO DE SALUD',
    verifiedAgo: '12 MIN',
    hours: 'Abierto 24hs (Turno asignado)',
  ),
  'farmacia-del-jardin': (
    name: 'Farmacia del Jardín',
    address: 'Scalabrini Ortiz 2105, Ciudad Autónoma de Buenos Aires',
    distanceText: 'A 820m de tu ubicación actual',
    phone: '+54 11 4567-8901',
    dutyUntil: 'DE TURNO HASTA MAÑANA 08:30',
    source: 'COLEGIO DE FARMACÉUTICOS',
    verifiedAgo: '45 MIN',
    hours: 'Abierto 24hs (Turno asignado)',
  ),
  'nueva-era-farmacias': (
    name: 'Nueva Era Farmacias',
    address: 'Av. Las Heras 3800, Ciudad Autónoma de Buenos Aires',
    distanceText: 'A 1.2km de tu ubicación actual',
    phone: '+54 11 4890-1234',
    dutyUntil: 'DE TURNO HASTA MAÑANA 08:30',
    source: 'DATOS DE LA COMUNIDAD',
    verifiedAgo: '2 HS',
    hours: 'Abierto 24hs (Turno asignado)',
  ),
};

_PharmacyDetail _resolveDetail(String id) =>
    _demoDetails[id] ??
    (
      name: id,
      address: 'Buenos Aires',
      distanceText: '',
      phone: 'Sin teléfono registrado',
      dutyUntil: 'DE TURNO',
      source: 'FUENTE NO DISPONIBLE',
      verifiedAgo: '',
      hours: 'Consultar en la farmacia',
    );

// ── Pantalla ──────────────────────────────────────────────────────────────────

/// Detalle de farmacia de turno.
/// Recibe [pharmacyId] para futura carga desde Firestore en TuM2-0061.
class PharmacyDutyDetailScreen extends StatelessWidget {
  final String pharmacyId;

  const PharmacyDutyDetailScreen({super.key, required this.pharmacyId});

  @override
  Widget build(BuildContext context) {
    final data = _resolveDetail(pharmacyId);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context, data),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Verificación
                  if (data.verifiedAgo.isNotEmpty)
                    _VerificationRow(
                        source: data.source, verifiedAgo: data.verifiedAgo),
                  const SizedBox(height: 12),
                  // Nombre
                  Text(data.name, style: AppTextStyles.headingLg),
                  const SizedBox(height: 10),
                  // Badge turno
                  _DutyBadge(label: data.dutyUntil),
                  const SizedBox(height: 8),
                  // Link info
                  GestureDetector(
                    onTap: () {},
                    child: Row(
                      children: [
                        Text(
                          'Para qué sirve el turno',
                          style: AppTextStyles.bodySm.copyWith(
                            color: AppColors.primary500,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_ios,
                            size: 11, color: AppColors.primary500),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Mapa placeholder
                  _MapWidget(
                    address: data.address,
                    distanceText: data.distanceText,
                  ),
                  const SizedBox(height: 20),
                  // CTA principal — Cómo llegar
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary500,
                        foregroundColor: AppColors.surface,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.directions_outlined, size: 20),
                      label: Text(
                        'Cómo llegar',
                        style: AppTextStyles.labelMd
                            .copyWith(color: AppColors.surface),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // CTA secundario — Llamar
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.neutral900,
                        side: BorderSide(color: AppColors.neutral300),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: Icon(Icons.phone_outlined,
                          size: 20, color: AppColors.neutral700),
                      label: Text('Llamar ahora',
                          style: AppTextStyles.labelMd),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(color: AppColors.neutral200),
                  const SizedBox(height: 16),
                  // Datos de contacto y horario
                  _InfoDetailRow(
                    icon: Icons.phone_outlined,
                    text: data.phone,
                  ),
                  const SizedBox(height: 10),
                  _InfoDetailRow(
                    icon: Icons.access_time_outlined,
                    text: data.hours,
                  ),
                  const SizedBox(height: 24),
                  const Divider(color: AppColors.neutral200),
                  const SizedBox(height: 16),
                  // Foto placeholder
                  _PhotoPlaceholder(),
                  const SizedBox(height: 24),
                  // Acciones secundarias
                  _SecondaryActions(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context, _PharmacyDetail data) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: AppColors.surface,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        color: AppColors.neutral700,
        onPressed: () => context.pop(),
      ),
      title: GestureDetector(
        onTap: () => context.pop(),
        child: Text(
          'Farmacias',
          style: AppTextStyles.bodySm.copyWith(color: AppColors.primary500),
        ),
      ),
      titleSpacing: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.share_outlined),
          color: AppColors.neutral600,
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.bookmark_border_outlined),
          color: AppColors.neutral600,
          onPressed: () {},
        ),
      ],
    );
  }
}

// ── Verificación ──────────────────────────────────────────────────────────────

class _VerificationRow extends StatelessWidget {
  const _VerificationRow({
    required this.source,
    required this.verifiedAgo,
  });
  final String source;
  final String verifiedAgo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.successBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_outlined,
              size: 14, color: AppColors.successFg),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'VERIFICADO HACE $verifiedAgo POR $source',
              style: AppTextStyles.bodyXs.copyWith(
                color: AppColors.successFg,
                letterSpacing: 0.3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Badge turno ───────────────────────────────────────────────────────────────

class _DutyBadge extends StatelessWidget {
  const _DutyBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.successBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSm.copyWith(
          color: AppColors.successFg,
          letterSpacing: 0.4,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── Mapa ──────────────────────────────────────────────────────────────────────

class _MapWidget extends StatelessWidget {
  const _MapWidget({required this.address, required this.distanceText});
  final String address;
  final String distanceText;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          // Mapa placeholder
          Container(
            height: 160,
            color: AppColors.neutral200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.map_outlined,
                        size: 40, color: AppColors.neutral400),
                    const SizedBox(height: 4),
                    Text('Buenos Aires', style: AppTextStyles.bodyXs),
                  ],
                ),
                // Pin central
                Positioned(
                  bottom: 60,
                  child: Icon(Icons.location_on,
                      size: 36, color: AppColors.primary500),
                ),
              ],
            ),
          ),
          // Dirección debajo del mapa
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.location_on_outlined,
                        size: 14, color: AppColors.neutral500),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        address,
                        style: AppTextStyles.bodySm,
                      ),
                    ),
                  ],
                ),
                if (distanceText.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.directions_walk,
                          size: 14, color: AppColors.primary500),
                      const SizedBox(width: 6),
                      Text(
                        distanceText,
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.primary600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Info row ──────────────────────────────────────────────────────────────────

class _InfoDetailRow extends StatelessWidget {
  const _InfoDetailRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.neutral500),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: AppTextStyles.bodyMd)),
      ],
    );
  }
}

// ── Foto placeholder ──────────────────────────────────────────────────────────

class _PhotoPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 180,
        color: AppColors.neutral200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.local_pharmacy_outlined,
                  size: 48, color: AppColors.neutral400),
              const SizedBox(height: 6),
              Text('Foto de la farmacia',
                  style: AppTextStyles.bodyXs
                      .copyWith(color: AppColors.neutral400)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Acciones secundarias ──────────────────────────────────────────────────────

class _SecondaryActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _SecondaryAction(
          icon: Icons.flag_outlined,
          label: 'Reportar problema',
          onTap: () {},
        ),
        _SecondaryAction(
          icon: Icons.share_outlined,
          label: 'Compartir',
          onTap: () {},
        ),
      ],
    );
  }
}

class _SecondaryAction extends StatelessWidget {
  const _SecondaryAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.neutral500),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.bodySm.copyWith(
              color: AppColors.neutral600,
            ),
          ),
        ],
      ),
    );
  }
}
