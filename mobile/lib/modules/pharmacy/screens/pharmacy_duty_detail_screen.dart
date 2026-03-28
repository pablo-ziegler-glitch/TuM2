import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/pharmacy_duty_item.dart';

// ── Helpers de acción nativa ──────────────────────────────────────────────────

Future<void> _openMaps(String address) async {
  final encoded = Uri.encodeComponent(address);
  final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$encoded');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

Future<void> _callPhone(String phone) async {
  final cleaned = phone.replaceAll(RegExp(r'[\s\-()]'), '');
  final uri = Uri.parse('tel:$cleaned');
  if (await canLaunchUrl(uri)) await launchUrl(uri);
}

void _logEvent(String name, Map<String, Object> params) {
  FirebaseAnalytics.instance.logEvent(name: name, parameters: params);
}

// ── Pantalla ──────────────────────────────────────────────────────────────────

/// Detalle de farmacia de turno.
/// Si [item] se proporciona, se usan sus datos directamente (navegación desde lista).
/// Si [item] es null (deep link), se hace fetch de merchant_public/{pharmacyId}.
class PharmacyDutyDetailScreen extends StatelessWidget {
  final String pharmacyId;
  final PharmacyDutyItem? item;

  const PharmacyDutyDetailScreen({
    super.key,
    required this.pharmacyId,
    this.item,
  });

  @override
  Widget build(BuildContext context) {
    if (item != null) {
      return _DetailView(pharmacyId: pharmacyId, item: item!);
    }
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .doc('merchant_public/$pharmacyId')
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.scaffoldBg,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError ||
            !snapshot.hasData ||
            !snapshot.data!.exists) {
          return Scaffold(
            backgroundColor: AppColors.scaffoldBg,
            body: Column(
              children: [
                _buildAppBarSimple(context),
                const Expanded(
                  child: Center(
                    child: Text('No se pudo cargar la farmacia.'),
                  ),
                ),
              ],
            ),
          );
        }
        final data =
            snapshot.data!.data() as Map<String, dynamic>;
        final fallbackItem = PharmacyDutyItem(
          dutyId: '',
          merchantId: pharmacyId,
          name: data['name'] as String? ?? '',
          address: data['address'] as String? ?? '',
          phone: data['phone'] as String?,
          lat: (data['lat'] as num?)?.toDouble(),
          lng: (data['lng'] as num?)?.toDouble(),
          startsAt: DateTime.now(),
          endsAt: DateTime.now().add(const Duration(hours: 8)),
          date: '',
          zoneId: '',
          verificationStatus:
              data['verificationStatus'] as String? ?? 'unverified',
          dutyVerificationStatus: 'referential',
          confidenceScore:
              (data['confidenceScore'] as num?)?.toDouble(),
        );
        return _DetailView(
            pharmacyId: pharmacyId, item: fallbackItem);
      },
    );
  }

  Widget _buildAppBarSimple(BuildContext context) {
    return SafeArea(
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            color: AppColors.neutral700,
            onPressed: () => context.pop(),
          ),
        ],
      ),
    );
  }
}

// ── Vista interna con datos ───────────────────────────────────────────────────

class _DetailView extends StatelessWidget {
  const _DetailView({
    required this.pharmacyId,
    required this.item,
  });
  final String pharmacyId;
  final PharmacyDutyItem item;

  String? get _verificationSource {
    switch (item.dutyVerificationStatus) {
      case 'validated':
      case 'claimed':
        return 'MINISTERIO DE SALUD';
      case 'referential':
        return 'DATOS DE LA COMUNIDAD';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasCoords = item.lat != null && item.lng != null;
    final source = _verificationSource;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Verificación (solo si hay source conocido)
                  if (source != null)
                    _VerificationRow(source: source),
                  if (source != null) const SizedBox(height: 12),
                  // Nombre
                  Text(item.name, style: AppTextStyles.headingLg),
                  const SizedBox(height: 10),
                  // Badge turno (solo si hay datos de turno)
                  if (item.dutyId.isNotEmpty)
                    _DutyBadge(label: item.dutyBadgeLabel),
                  if (item.dutyId.isNotEmpty) const SizedBox(height: 8),
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
                  // Mapa (solo si hay coordenadas)
                  if (hasCoords) ...[
                    _MapWidget(address: item.address),
                    const SizedBox(height: 20),
                  ],
                  // CTA principal — Cómo llegar (solo si hay coordenadas)
                  if (hasCoords) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _logEvent('farmacia_maps_tap', {
                            'merchant_id': pharmacyId,
                            'zone_id': item.zoneId,
                            'trust_level': item.trustLevel.name,
                          });
                          _openMaps(item.address);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary500,
                          foregroundColor: AppColors.surface,
                          padding:
                              const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.directions_outlined,
                            size: 20),
                        label: Text(
                          'Cómo llegar',
                          style: AppTextStyles.labelMd
                              .copyWith(color: AppColors.surface),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  // CTA secundario — Llamar (solo si hay teléfono)
                  if (item.phone != null) ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _logEvent('farmacia_call_tap', {
                            'merchant_id': pharmacyId,
                            'zone_id': item.zoneId,
                            'trust_level': item.trustLevel.name,
                          });
                          _callPhone(item.phone!);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.neutral900,
                          side:
                              BorderSide(color: AppColors.neutral300),
                          padding:
                              const EdgeInsets.symmetric(vertical: 15),
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
                  ] else
                    const SizedBox(height: 24),
                  const Divider(color: AppColors.neutral200),
                  const SizedBox(height: 16),
                  // Teléfono (solo si existe)
                  if (item.phone != null) ...[
                    _InfoDetailRow(
                      icon: Icons.phone_outlined,
                      text: item.phone!,
                    ),
                    const SizedBox(height: 10),
                  ],
                  _InfoDetailRow(
                    icon: Icons.access_time_outlined,
                    text: item.dutyId.isNotEmpty
                        ? 'Abierto 24hs (Turno asignado)'
                        : 'Consultar en la farmacia',
                  ),
                  const SizedBox(height: 24),
                  const Divider(color: AppColors.neutral200),
                  const SizedBox(height: 16),
                  _PhotoPlaceholder(),
                  const SizedBox(height: 24),
                  _SecondaryActions(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context) {
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
  const _VerificationRow({required this.source});
  final String source;

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
              'FUENTE: $source',
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
  const _MapWidget({required this.address});
  final String address;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
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
                Positioned(
                  bottom: 60,
                  child: Icon(Icons.location_on,
                      size: 36, color: AppColors.primary500),
                ),
              ],
            ),
          ),
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.all(12),
            child: Row(
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
