import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/pharmacy_duty_item.dart';
import '../models/pharmacy_zone.dart';
import '../providers/pharmacy_duty_notifier.dart';
import '../services/distance_calculator.dart';
import '../services/geo_location_service.dart';

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

// ── Analytics helper ──────────────────────────────────────────────────────────

void _logEvent(String name, Map<String, Object> params) {
  FirebaseAnalytics.instance.logEvent(name: name, parameters: params);
}

// ── Pantalla principal ────────────────────────────────────────────────────────

/// HOME-03 — Vista Farmacias de turno.
/// Conectada con Firestore vía [PharmacyDutyNotifier] y [activeZonesProvider].
class PharmacyDutyScreen extends ConsumerStatefulWidget {
  const PharmacyDutyScreen({super.key});

  @override
  ConsumerState<PharmacyDutyScreen> createState() =>
      _PharmacyDutyScreenState();
}

class _PharmacyDutyScreenState extends ConsumerState<PharmacyDutyScreen> {
  bool _gpsLoading = true;
  String _currentZoneId = '';
  String _currentZoneName = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryAutoLocate());
  }

  Future<void> _tryAutoLocate() async {
    setState(() => _gpsLoading = true);
    final result = await GeoLocationService().getPosition();
    if (!mounted) return;

    if (result is GeoPositionOk) {
      final lat = result.lat;
      final lng = result.lng;
      try {
        final zones = await ref.read(activeZonesProvider.future);
        final nearest = _findNearestZone(zones, lat, lng);
        if (nearest != null && mounted) {
          setState(() {
            _currentZoneId = nearest.zoneId;
            _currentZoneName = nearest.name;
            _gpsLoading = false;
          });
          ref.read(pharmacyDutyProvider.notifier).setUserPosition(lat, lng);
          ref.read(pharmacyDutyProvider.notifier).loadForZone(nearest.zoneId);
          _logEvent('farmacia_screen_view', {
            'zone_id': nearest.zoneId,
            'has_location': true,
            'results_count': 0,
            'view_state': 'loading',
          });
          return;
        }
      } catch (_) {
        // caer a noLocation
      }
    }

    if (mounted) {
      setState(() => _gpsLoading = false);
      _logEvent('farmacia_screen_view', {
        'zone_id': '',
        'has_location': false,
        'results_count': 0,
        'view_state': 'noLocation',
      });
    }
  }

  PharmacyZone? _findNearestZone(
      List<PharmacyZone> zones, double lat, double lng) {
    PharmacyZone? nearest;
    double minDistance = double.maxFinite;

    for (final zone in zones) {
      final cLat = zone.centroidLat;
      final cLng = zone.centroidLng;
      if (cLat == null || cLng == null) continue;
      final dist = DistanceCalculator.haversine(
        lat1: lat,
        lng1: lng,
        lat2: cLat,
        lng2: cLng,
      );
      if (dist < minDistance) {
        minDistance = dist;
        nearest = zone;
      }
    }
    return nearest;
  }

  Future<void> _selectZone(PharmacyZone zone) async {
    final previousZone = _currentZoneId;
    setState(() {
      _currentZoneId = zone.zoneId;
      _currentZoneName = zone.name;
    });
    ref.read(pharmacyDutyProvider.notifier).loadForZone(zone.zoneId);
    _logEvent('farmacia_zone_changed', {
      'from_zone': previousZone,
      'to_zone': zone.zoneId,
      'method': 'manual',
    });
  }

  void _showZoneSelector() {
    setState(() {
      _currentZoneId = '';
      _currentZoneName = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_gpsLoading) {
      return const Scaffold(
        backgroundColor: AppColors.scaffoldBg,
        body: _LoadingBody(),
      );
    }

    if (_currentZoneId.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.scaffoldBg,
        body: _NoLocationBody(
          onRequestGps: _tryAutoLocate,
          onZoneSelected: _selectZone,
        ),
      );
    }

    final pharmState = ref.watch(pharmacyDutyProvider);
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: pharmState.duties.when(
        loading: () => const _LoadingBody(),
        error: (e, _) => _ErrorBody(
          errorType: e.runtimeType.toString(),
          onRetry: () {
            _logEvent('farmacia_retry_tap',
                {'error_type': e.runtimeType.toString()});
            ref
                .read(pharmacyDutyProvider.notifier)
                .loadForZone(_currentZoneId);
          },
        ),
        data: (items) => items.isEmpty
            ? _EmptyBody(
                zona: _currentZoneName,
                zoneId: _currentZoneId,
                onChangeZone: _showZoneSelector,
              )
            : RefreshIndicator(
                onRefresh: () =>
                    ref.read(pharmacyDutyProvider.notifier).refresh(),
                child: _ResultsBody(
                  zona: _currentZoneName,
                  zoneId: _currentZoneId,
                  pharmacies: items,
                  sortOrder: pharmState.sortOrder,
                  onSortByDistance: () =>
                      ref.read(pharmacyDutyProvider.notifier).sortByDistance(),
                  onSortByTrust: () =>
                      ref.read(pharmacyDutyProvider.notifier).sortByTrust(),
                  onChangeZone: _showZoneSelector,
                ),
              ),
      ),
    );
  }
}

// ── Header compartido ─────────────────────────────────────────────────────────

class _ScreenHeader extends StatelessWidget {
  const _ScreenHeader({
    required this.zona,
    this.showLocation = false,
    this.onChangeZone,
  });
  final String zona;
  final bool showLocation;
  final VoidCallback? onChangeZone;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      color: AppColors.surface,
      padding: EdgeInsets.fromLTRB(20, top + 12, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TuM2',
                      style: AppTextStyles.headingSm.copyWith(
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'FARMACIAS DE TURNO',
                      style: AppTextStyles.labelSm.copyWith(
                        color: AppColors.primary500,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (showLocation)
                GestureDetector(
                  onTap: onChangeZone,
                  child: Row(
                    children: [
                      Icon(Icons.location_on,
                          size: 14, color: AppColors.primary500),
                      const SizedBox(width: 4),
                      Text(
                        zona.toUpperCase(),
                        style: AppTextStyles.labelSm.copyWith(
                          color: AppColors.primary500,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.keyboard_arrow_down,
                          size: 16, color: AppColors.primary500),
                    ],
                  ),
                ),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.neutral100,
                child: Icon(Icons.person_outline,
                    color: AppColors.neutral600, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Estado: Sin ubicación ─────────────────────────────────────────────────────

class _NoLocationBody extends ConsumerWidget {
  const _NoLocationBody({
    required this.onRequestGps,
    required this.onZoneSelected,
  });
  final VoidCallback onRequestGps;
  final ValueChanged<PharmacyZone> onZoneSelected;

  static const _fallbackNames = [
    'Palermo',
    'Recoleta',
    'Belgrano',
    'Caballito',
    'San Telmo',
    'Almagro',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zonesAsync = ref.watch(activeZonesProvider);

    return Column(
      children: [
        const _ScreenHeader(zona: 'CABA', showLocation: false),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
            child: Column(
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: const BoxDecoration(
                    color: AppColors.neutral100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.location_off_outlined,
                    size: 40,
                    color: AppColors.neutral400,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  '¿Dónde te encontrás?',
                  style: AppTextStyles.headingMd,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Para que TuM2 pueda ayudarte, necesitamos tu ubicación para mostrarte las farmacias más cercanas disponibles ahora.',
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.neutral600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onRequestGps,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary500,
                      foregroundColor: AppColors.surface,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.near_me, size: 18),
                    label: Text(
                      'Permitir acceso',
                      style: AppTextStyles.labelMd
                          .copyWith(color: AppColors.surface),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(child: Divider(color: AppColors.neutral200)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'O BUSCA POR ZONA',
                        style: AppTextStyles.bodyXs.copyWith(
                          letterSpacing: 0.8,
                          color: AppColors.neutral500,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: AppColors.neutral200)),
                  ],
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Barrios populares',
                    style: AppTextStyles.labelMd,
                  ),
                ),
                const SizedBox(height: 10),
                zonesAsync.when(
                  loading: () => Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(
                      6,
                      (_) => const _Shimmer(width: 80, height: 34, radius: 20),
                    ),
                  ),
                  error: (_, __) => Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _fallbackNames
                        .map((name) => _ZoneChip(
                              label: name,
                              onTap: () => onZoneSelected(PharmacyZone(
                                zoneId: name.toLowerCase(),
                                name: name,
                                cityId: 'buenos_aires',
                              )),
                            ))
                        .toList(),
                  ),
                  data: (zones) => Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: zones
                        .map((zone) => _ZoneChip(
                              label: zone.name,
                              onTap: () => onZoneSelected(zone),
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Tu ubicación solo se usa para encontrar servicios cercanos.',
                  style: AppTextStyles.bodyXs.copyWith(
                    color: AppColors.neutral500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ZoneChip extends StatelessWidget {
  const _ZoneChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.neutral200),
        ),
        child: Text(label, style: AppTextStyles.bodySm),
      ),
    );
  }
}

// ── Estado: Cargando ──────────────────────────────────────────────────────────

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _ScreenHeader(zona: '...', showLocation: true),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            itemCount: 3,
            itemBuilder: (_, __) => const _SkeletonCard(),
          ),
        ),
      ],
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Shimmer(width: 70, height: 22, radius: 20),
              SizedBox(width: 8),
              _Shimmer(width: 90, height: 22, radius: 20),
            ],
          ),
          SizedBox(height: 10),
          _Shimmer(width: double.infinity, height: 16, radius: 6),
          SizedBox(height: 6),
          _Shimmer(width: 180, height: 13, radius: 6),
          SizedBox(height: 6),
          _Shimmer(width: 120, height: 13, radius: 6),
          SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                  child: _Shimmer(
                      width: double.infinity, height: 40, radius: 10)),
              SizedBox(width: 10),
              _Shimmer(width: 40, height: 40, radius: 10),
            ],
          ),
        ],
      ),
    );
  }
}

class _Shimmer extends StatelessWidget {
  const _Shimmer({
    required this.width,
    required this.height,
    required this.radius,
  });
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.neutral100,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

// ── Estado: Error ─────────────────────────────────────────────────────────────

class _ErrorBody extends StatefulWidget {
  const _ErrorBody({required this.errorType, required this.onRetry});
  final String errorType;
  final VoidCallback onRetry;

  @override
  State<_ErrorBody> createState() => _ErrorBodyState();
}

class _ErrorBodyState extends State<_ErrorBody> {
  @override
  void initState() {
    super.initState();
    _logEvent('farmacia_error_state_view',
        {'error_type': widget.errorType});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _ScreenHeader(zona: '...', showLocation: false),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wifi_off_outlined,
                    size: 56, color: AppColors.neutral400),
                const SizedBox(height: 20),
                Text(
                  'No pudimos cargar los turnos. Revisá tu conexión.',
                  style: AppTextStyles.headingMd,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: widget.onRetry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary500,
                      foregroundColor: AppColors.surface,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Reintentar',
                      style: AppTextStyles.labelMd
                          .copyWith(color: AppColors.surface),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Estado: Resultados ────────────────────────────────────────────────────────

class _ResultsBody extends StatelessWidget {
  const _ResultsBody({
    required this.zona,
    required this.zoneId,
    required this.pharmacies,
    required this.sortOrder,
    required this.onSortByDistance,
    required this.onSortByTrust,
    required this.onChangeZone,
  });

  final String zona;
  final String zoneId;
  final List<PharmacyDutyItem> pharmacies;
  final PharmacyDutySortOrder sortOrder;
  final VoidCallback onSortByDistance;
  final VoidCallback onSortByTrust;
  final VoidCallback onChangeZone;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _ScreenHeader(
            zona: zona,
            showLocation: true,
            onChangeZone: onChangeZone,
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Turno vigente ahora en $zona',
                  style: AppTextStyles.headingLg,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.successFg,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Actualizado hace 2 min',
                      style: AppTextStyles.bodyXs
                          .copyWith(color: AppColors.neutral500),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: onChangeZone,
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
                        Icon(Icons.search,
                            color: AppColors.neutral400, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Buscar farmacia o cambiar zona',
                            style: AppTextStyles.bodyMd
                                .copyWith(color: AppColors.neutral400),
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            zona.toUpperCase(),
                            style: AppTextStyles.bodyXs.copyWith(
                              color: AppColors.primary500,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _FilterChip(
                      label: 'Cerca de mí',
                      selected:
                          sortOrder == PharmacyDutySortOrder.byDistance,
                      onTap: onSortByDistance,
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Confianza alta',
                      selected:
                          sortOrder == PharmacyDutySortOrder.byTrust,
                      onTap: onSortByTrust,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.infoBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 14, color: AppColors.primary500),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${todayArgentinaLabel()} — turno vigente ahora',
                          style: AppTextStyles.bodyXs.copyWith(
                            color: AppColors.primary600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const _DisclaimerBanner(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child:
                  _PharmacyCard(item: pharmacies[i], zoneId: zoneId),
            ),
            childCount: pharmacies.length,
          ),
        ),
        SliverToBoxAdapter(
          child: _InfoImportanteSection(),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }
}

// ── Banner disclaimer ─────────────────────────────────────────────────────────

class _DisclaimerBanner extends StatelessWidget {
  const _DisclaimerBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_outlined,
              size: 14, color: AppColors.warningFg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Información referencial. Verificá con la farmacia antes de ir.',
              style: AppTextStyles.bodyXs.copyWith(
                color: AppColors.warningFg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Filter chip ───────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary500 : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppColors.primary500
                : AppColors.neutral200,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(Icons.check, size: 13, color: AppColors.surface),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: AppTextStyles.labelSm.copyWith(
                color: selected
                    ? AppColors.surface
                    : AppColors.neutral700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tarjeta de farmacia ───────────────────────────────────────────────────────

class _PharmacyCard extends StatelessWidget {
  const _PharmacyCard({required this.item, required this.zoneId});
  final PharmacyDutyItem item;
  final String zoneId;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(
        AppRoutes.pharmacyDutyDetailPath(item.merchantId),
        extra: item,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _DutyBadge(label: item.dutyUntilLabel),
                  const SizedBox(width: 8),
                  _TrustBadge(level: item.trustLevel),
                ],
              ),
              const SizedBox(height: 10),
              Text(item.name, style: AppTextStyles.headingSm),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.location_on_outlined,
                      size: 14, color: AppColors.neutral500),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      item.address,
                      style: AppTextStyles.bodySm,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (item.distanceMeters != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.directions_walk,
                        size: 14, color: AppColors.neutral500),
                    const SizedBox(width: 4),
                    Text(
                      DistanceCalculator.formatDistance(
                          item.distanceMeters!),
                      style: AppTextStyles.bodySm.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _logEvent('farmacia_maps_tap', {
                          'merchant_id': item.merchantId,
                          'zone_id': zoneId,
                          'trust_level': item.trustLevel.name,
                        });
                        _openMaps(item.address);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary500,
                        foregroundColor: AppColors.surface,
                        padding:
                            const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.directions_outlined,
                          size: 16),
                      label: Text(
                        'Cómo llegar',
                        style: AppTextStyles.labelSm
                            .copyWith(color: AppColors.surface),
                      ),
                    ),
                  ),
                  if (item.phone != null) ...[
                    const SizedBox(width: 10),
                    _PhoneButton(
                      phone: item.phone!,
                      onCall: () => _logEvent('farmacia_call_tap', {
                        'merchant_id': item.merchantId,
                        'zone_id': zoneId,
                        'trust_level': item.trustLevel.name,
                      }),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DutyBadge extends StatelessWidget {
  const _DutyBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.successBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSm.copyWith(
          color: AppColors.successFg,
          letterSpacing: 0.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TrustBadge extends StatelessWidget {
  const _TrustBadge({required this.level});
  final PharmacyTrustLevel level;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (level) {
      PharmacyTrustLevel.official => (
          'Dato Oficial',
          AppColors.primary50,
          AppColors.primary600,
        ),
      PharmacyTrustLevel.verified => (
          'Fuente Oficial',
          AppColors.primary50,
          AppColors.primary600,
        ),
      PharmacyTrustLevel.community => (
          'Com. reciente',
          AppColors.warningBg,
          AppColors.warningFg,
        ),
      PharmacyTrustLevel.unverified => (
          'Sin verificar',
          AppColors.neutral100,
          AppColors.neutral600,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSm.copyWith(
          color: fg,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _PhoneButton extends StatelessWidget {
  const _PhoneButton({required this.phone, required this.onCall});
  final String phone;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        onCall();
        _callPhone(phone);
      },
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.neutral100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.phone_outlined,
            color: AppColors.neutral700, size: 18),
      ),
    );
  }
}

// ── Sección información importante ───────────────────────────────────────────

class _InfoImportanteSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.neutral100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Información importante', style: AppTextStyles.headingSm),
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.medication_outlined,
            iconColor: AppColors.primary500,
            title: 'Recetas Digitales',
            subtitle:
                'Todas las farmacias de turno aceptan recetas de obras sociales vigentes.',
          ),
          const Divider(height: 20, color: AppColors.neutral200),
          _InfoRow(
            icon: Icons.support_agent_outlined,
            iconColor: AppColors.secondary500,
            title: '¿Necesitás ayuda?',
            subtitle:
                'Contactá a nuestro asistente de TuM2 para consultas de salud.',
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.labelMd),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTextStyles.bodyXs
                    .copyWith(color: AppColors.neutral600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Estado: Vacío ─────────────────────────────────────────────────────────────

class _EmptyBody extends StatefulWidget {
  const _EmptyBody({
    required this.zona,
    required this.zoneId,
    required this.onChangeZone,
  });
  final String zona;
  final String zoneId;
  final VoidCallback onChangeZone;

  @override
  State<_EmptyBody> createState() => _EmptyBodyState();
}

class _EmptyBodyState extends State<_EmptyBody> {
  @override
  void initState() {
    super.initState();
    _logEvent('farmacia_empty_state_view', {
      'zone_id': widget.zoneId,
      'date': todayArgentina(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ScreenHeader(
          zona: widget.zona,
          showLocation: true,
          onChangeZone: widget.onChangeZone,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
            child: Column(
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: const BoxDecoration(
                    color: AppColors.neutral100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.search_off_outlined,
                    size: 40,
                    color: AppColors.neutral400,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'No encontramos farmacias de turno en esta zona',
                  style: AppTextStyles.headingMd,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Podés buscar en barrios cercanos como Belgrano · Recoleta',
                  style: AppTextStyles.bodyMd
                      .copyWith(color: AppColors.neutral600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: widget.onChangeZone,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.neutral900,
                      side: BorderSide(color: AppColors.neutral300),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.swap_horiz_outlined, size: 18),
                    label: Text(
                      'Cambiar zona',
                      style: AppTextStyles.labelMd,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.neutral900,
                      side: BorderSide(color: AppColors.neutral300),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.flag_outlined, size: 18),
                    label: Text(
                      '¿Falta info? Reportalo',
                      style: AppTextStyles.labelMd,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.infoBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline,
                          size: 16, color: AppColors.primary500),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '¿Necesitás ayuda?',
                              style: AppTextStyles.labelMd.copyWith(
                                color: AppColors.primary700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Nuestra guardia telefónica está disponible 24/7 para emergencias.',
                              style: AppTextStyles.bodyXs.copyWith(
                                color: AppColors.primary600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
