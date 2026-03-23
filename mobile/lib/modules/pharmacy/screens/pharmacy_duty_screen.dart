import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

// ── Helpers de acción nativa ──────────────────────────────────────────────────

Future<void> _openMaps(String address) async {
  final encoded = Uri.encodeComponent(address);
  final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$encoded');
  if (await canLaunchUrl(uri)) await launchUrl(uri,
      mode: LaunchMode.externalApplication);
}

Future<void> _callPhone(String phone) async {
  final cleaned = phone.replaceAll(RegExp(r'[\s\-()]'), '');
  final uri = Uri.parse('tel:$cleaned');
  if (await canLaunchUrl(uri)) await launchUrl(uri);
}

// ── Modelos de demo ───────────────────────────────────────────────────────────
// Reemplazar con carga Firestore en TuM2-0061

enum _TrustLevel { official, verified, community, unverified }

typedef _PharmacyData = ({
  String id,
  String name,
  String address,
  String distanceText,
  int distanceMeters,
  String dutyUntil,
  _TrustLevel trust,
  String phone,
});

const List<_PharmacyData> _demoPharmacies = [
  (
    id: 'farmacia-central-palermo',
    name: 'Farmacia Central Palermo',
    address: 'Av. Independencia 1420, CABA',
    distanceText: 'A 450m de tu ubicación',
    distanceMeters: 450,
    dutyUntil: 'hasta mañana 08:30',
    trust: _TrustLevel.official,
    phone: '+54 11 4321-9876',
  ),
  (
    id: 'farmacia-del-jardin',
    name: 'Farmacia del Jardín',
    address: 'Scalabrini Ortiz 2105, CABA',
    distanceText: 'A 820m de tu ubicación',
    distanceMeters: 820,
    dutyUntil: 'hasta mañana 08:30',
    trust: _TrustLevel.verified,
    phone: '+54 11 4567-8901',
  ),
  (
    id: 'nueva-era-farmacias',
    name: 'Nueva Era Farmacias',
    address: 'Av. Las Heras 3800, CABA',
    distanceText: 'A 1.2km de tu ubicación',
    distanceMeters: 1200,
    dutyUntil: 'hasta mañana 08:30',
    trust: _TrustLevel.unverified,
    phone: '+54 11 4890-1234',
  ),
];

// ── Estado de la vista ────────────────────────────────────────────────────────

enum _ViewState { noLocation, loading, results, empty }

// ── Pantalla principal ────────────────────────────────────────────────────────

/// HOME-03 — Vista Farmacias de turno.
/// Maneja 4 estados: sin ubicación, cargando, resultados y vacío.
/// Reemplazar lógica de permiso con geolocator en TuM2-0061.
class PharmacyDutyScreen extends StatefulWidget {
  const PharmacyDutyScreen({super.key});

  @override
  State<PharmacyDutyScreen> createState() => _PharmacyDutyScreenState();
}

class _PharmacyDutyScreenState extends State<PharmacyDutyScreen> {
  _ViewState _viewState = _ViewState.noLocation;
  String _zona = 'Palermo';
  bool _filterCerca = true;
  bool _filterConfianza = false;

  void _requestLocation() async {
    setState(() => _viewState = _ViewState.loading);
    // Simula delay de geolocalización — reemplazar con geolocator en TuM2-0061
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => _viewState = _ViewState.results);
  }

  void _selectZone(String zona) async {
    setState(() {
      _zona = zona;
      _viewState = _ViewState.loading;
    });
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    // Demo: "Almagro" muestra vacío para ilustrar el empty state
    setState(() =>
        _viewState = zona == 'Almagro' ? _ViewState.empty : _ViewState.results);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: switch (_viewState) {
        _ViewState.noLocation => _NoLocationBody(
            onPermitir: _requestLocation,
            onSelectZone: _selectZone,
          ),
        _ViewState.loading => const _LoadingBody(),
        _ViewState.results => _ResultsBody(
            zona: _zona,
            filterCerca: _filterCerca,
            filterConfianza: _filterConfianza,
            onToggleCerca: () =>
                setState(() => _filterCerca = !_filterCerca),
            onToggleConfianza: () =>
                setState(() => _filterConfianza = !_filterConfianza),
            onChangeZone: () => setState(() => _viewState = _ViewState.noLocation),
            pharmacies: _demoPharmacies,
          ),
        _ViewState.empty => _EmptyBody(
            zona: _zona,
            onChangeZone: () => setState(() => _viewState = _ViewState.noLocation),
            onAmpliarRadio: _requestLocation,
          ),
      },
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

class _NoLocationBody extends StatefulWidget {
  const _NoLocationBody({
    required this.onPermitir,
    required this.onSelectZone,
  });
  final VoidCallback onPermitir;
  final ValueChanged<String> onSelectZone;

  @override
  State<_NoLocationBody> createState() => _NoLocationBodyState();
}

class _NoLocationBodyState extends State<_NoLocationBody> {
  final _controller = TextEditingController();

  static const _popularZones = [
    'Palermo',
    'Recoleta',
    'Belgrano',
    'Caballito',
    'San Telmo',
    'Almagro',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ScreenHeader(zona: 'CABA', showLocation: false),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
            child: Column(
              children: [
                // Ícono de ubicación desactivado
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppColors.neutral100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
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
                // Botón principal
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: widget.onPermitir,
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
                // Divider zona manual
                Row(
                  children: [
                    Expanded(
                        child: Divider(color: AppColors.neutral200)),
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
                    Expanded(
                        child: Divider(color: AppColors.neutral200)),
                  ],
                ),
                const SizedBox(height: 16),
                // Campo de búsqueda manual
                TextField(
                  controller: _controller,
                  style: AppTextStyles.bodyMd,
                  decoration: InputDecoration(
                    hintText: 'Escribir un barrio o ciudad...',
                    hintStyle: AppTextStyles.bodyMd
                        .copyWith(color: AppColors.neutral400),
                    prefixIcon: Icon(Icons.search,
                        color: AppColors.neutral400, size: 20),
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: AppColors.neutral200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: AppColors.neutral200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: AppColors.primary500),
                    ),
                  ),
                  onSubmitted: (v) {
                    if (v.trim().isNotEmpty) widget.onSelectZone(v.trim());
                  },
                ),
                const SizedBox(height: 20),
                // Barrios populares
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Barrios populares',
                    style: AppTextStyles.labelMd,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _popularZones
                      .map(
                        (z) => GestureDetector(
                          onTap: () => widget.onSelectZone(z),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: AppColors.neutral200),
                            ),
                            child: Text(z, style: AppTextStyles.bodySm),
                          ),
                        ),
                      )
                      .toList(),
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

// ── Estado: Cargando ──────────────────────────────────────────────────────────

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ScreenHeader(zona: '...', showLocation: true),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            itemCount: 3,
            itemBuilder: (_, __) => _SkeletonCard(),
          ),
        ),
      ],
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Shimmer(width: 70, height: 22, radius: 20),
              const SizedBox(width: 8),
              _Shimmer(width: 90, height: 22, radius: 20),
            ],
          ),
          const SizedBox(height: 10),
          _Shimmer(width: double.infinity, height: 16, radius: 6),
          const SizedBox(height: 6),
          _Shimmer(width: 180, height: 13, radius: 6),
          const SizedBox(height: 6),
          _Shimmer(width: 120, height: 13, radius: 6),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _Shimmer(width: double.infinity, height: 40, radius: 10)),
              const SizedBox(width: 10),
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

// ── Estado: Resultados ────────────────────────────────────────────────────────

class _ResultsBody extends StatelessWidget {
  const _ResultsBody({
    required this.zona,
    required this.filterCerca,
    required this.filterConfianza,
    required this.onToggleCerca,
    required this.onToggleConfianza,
    required this.onChangeZone,
    required this.pharmacies,
  });

  final String zona;
  final bool filterCerca;
  final bool filterConfianza;
  final VoidCallback onToggleCerca;
  final VoidCallback onToggleConfianza;
  final VoidCallback onChangeZone;
  final List<_PharmacyData> pharmacies;

  // Farmacias con filtros aplicados.
  // filterCerca: ordena por distancia ascendente.
  // filterConfianza: muestra solo official y verified.
  List<_PharmacyData> get _filtered {
    var list = [...pharmacies];
    if (filterConfianza) {
      list = list
          .where((p) =>
              p.trust == _TrustLevel.official ||
              p.trust == _TrustLevel.verified)
          .toList();
    }
    if (filterCerca) {
      list.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dayLabel = _dayLabel(now);
    final filtered = _filtered;

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
                // Título contextual
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
                      decoration: BoxDecoration(
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
                // Barra de búsqueda
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
                // Filtros
                Row(
                  children: [
                    _FilterChip(
                      label: 'Cerca de mí',
                      selected: filterCerca,
                      onTap: onToggleCerca,
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Confianza alta',
                      selected: filterConfianza,
                      onTap: onToggleConfianza,
                    ),
                  ],
                ),
                // Contexto temporal
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
                          '$dayLabel — turno vigente ahora',
                          style: AppTextStyles.bodyXs.copyWith(
                            color: AppColors.primary600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        // Lista de farmacias (con filtros aplicados)
        if (filtered.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Center(
                child: Text(
                  'Ningún resultado coincide con los filtros activos.',
                  style: AppTextStyles.bodyMd
                      .copyWith(color: AppColors.neutral500),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: _PharmacyCard(data: filtered[i]),
              ),
              childCount: filtered.length,
            ),
          ),
        // Sección: Información importante
        SliverToBoxAdapter(
          child: _InfoImportanteSection(),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  String _dayLabel(DateTime now) {
    const dias = [
      'Lunes', 'Martes', 'Miércoles', 'Jueves',
      'Viernes', 'Sábado', 'Domingo',
    ];
    const meses = [
      '', 'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ];
    final dia = dias[now.weekday - 1];
    return '$dia ${now.day} de ${meses[now.month]}';
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
  const _PharmacyCard({required this.data});
  final _PharmacyData data;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(AppRoutes.pharmacyDutyDetailPath(data.id)),
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
              // Badges
              Row(
                children: [
                  _DutyBadge(),
                  const SizedBox(width: 8),
                  _TrustBadge(level: data.trust),
                ],
              ),
              const SizedBox(height: 10),
              // Nombre
              Text(data.name, style: AppTextStyles.headingSm),
              const SizedBox(height: 6),
              // Dirección
              Row(
                children: [
                  Icon(Icons.location_on_outlined,
                      size: 14, color: AppColors.neutral500),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      data.address,
                      style: AppTextStyles.bodySm,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Distancia
              Row(
                children: [
                  Icon(Icons.directions_walk,
                      size: 14, color: AppColors.neutral500),
                  const SizedBox(width: 4),
                  Text(
                    data.distanceText,
                    style: AppTextStyles.bodySm.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // CTAs
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _openMaps(data.address),
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
                  const SizedBox(width: 10),
                  _PhoneButton(phone: data.phone),
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
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.successBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'DE TURNO',
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
  final _TrustLevel level;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (level) {
      _TrustLevel.official => (
          'Dato Oficial',
          AppColors.primary50,
          AppColors.primary600,
        ),
      _TrustLevel.verified => (
          'Fuente Oficial',
          AppColors.primary50,
          AppColors.primary600,
        ),
      _TrustLevel.community => (
          'Com. reciente',
          AppColors.warningBg,
          AppColors.warningFg,
        ),
      _TrustLevel.unverified => (
          'Sin verif. reciente',
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
  const _PhoneButton({required this.phone});
  final String phone;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _callPhone(phone),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.neutral100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.phone_outlined,
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
                style:
                    AppTextStyles.bodyXs.copyWith(color: AppColors.neutral600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Estado: Vacío ─────────────────────────────────────────────────────────────

class _EmptyBody extends StatelessWidget {
  const _EmptyBody({
    required this.zona,
    required this.onChangeZone,
    required this.onAmpliarRadio,
  });
  final String zona;
  final VoidCallback onChangeZone;
  final VoidCallback onAmpliarRadio;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ScreenHeader(
          zona: zona,
          showLocation: true,
          onChangeZone: onChangeZone,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
            child: Column(
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppColors.neutral100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
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
                    onPressed: onChangeZone,
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
                    onPressed: onAmpliarRadio,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.neutral900,
                      side: BorderSide(color: AppColors.neutral300),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.radar_outlined, size: 18),
                    label: Text(
                      'Ampliar radio',
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
