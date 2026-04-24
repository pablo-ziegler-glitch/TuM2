import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/analytics_provider.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../merchant_badges/domain/merchant_badge_resolver.dart';
import '../../merchant_badges/domain/merchant_visual_models.dart';
import '../../merchant_badges/domain/merchant_visual_state_mappers.dart';
import '../../merchant_badges/widgets/merchant_badge_widgets.dart';
import '../models/open_now_models.dart';
import '../providers/open_now_notifier.dart';

class AbiertoAhoraScreen extends ConsumerStatefulWidget {
  const AbiertoAhoraScreen({super.key});

  @override
  ConsumerState<AbiertoAhoraScreen> createState() => _AbiertoAhoraScreenState();
}

class _AbiertoAhoraScreenState extends ConsumerState<AbiertoAhoraScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(openNowNotifierProvider.notifier).ensureInitialized();
      ref.read(analyticsServiceProvider).track(
        event: 'surface_viewed',
        parameters: {'surface': 'open_now'},
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(openNowNotifierProvider);
    final notifier = ref.read(openNowNotifierProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      body: Column(
        children: [
          _OpenNowTopBar(
            zoneName: state.activeZoneName,
            zones: state.zones,
            activeZoneId: state.activeZoneId,
            onSelectZone: notifier.setZone,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: notifier.refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
                children: [
                  if (state.isLoading &&
                      !state.hasOpenResults &&
                      !state.hasFallback &&
                      state.error == null)
                    const _OpenNowLoadingState()
                  else if (state.error != null &&
                      !state.hasOpenResults &&
                      !state.hasFallback)
                    _OpenNowErrorState(
                      onRetry: notifier.refresh,
                    )
                  else if (state.hasOpenResults)
                    _OpenNowResultsState(
                      state: state,
                      onCardTap: (merchant, rank, isFallback) {
                        notifier.logCardClicked(
                          merchant: merchant,
                          rank: rank,
                          isFallback: isFallback,
                        );
                        context.push(
                          AppRoutes.commerceDetailPath(
                            merchant.merchantId,
                            source: 'open_now',
                          ),
                        );
                      },
                    )
                  else
                    _OpenNowEmptyState(
                      fallbackMerchants: state.fallbackMerchants,
                      onPrimaryTap: () => context.go(AppRoutes.search),
                      onCardTap: (merchant, rank) {
                        notifier.logCardClicked(
                          merchant: merchant,
                          rank: rank,
                          isFallback: true,
                        );
                        context.push(
                          AppRoutes.commerceDetailPath(
                            merchant.merchantId,
                            source: 'open_now_fallback',
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 72),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OpenNowTopBar extends StatelessWidget {
  const _OpenNowTopBar({
    required this.zoneName,
    required this.zones,
    required this.activeZoneId,
    required this.onSelectZone,
  });

  final String zoneName;
  final List<OpenNowZone> zones;
  final String activeZoneId;
  final Future<void> Function(String zoneId) onSelectZone;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      color: AppColors.neutral50.withValues(alpha: 0.93),
      padding: EdgeInsets.fromLTRB(8, topPadding + 6, 10, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back),
            color: AppColors.primary500,
          ),
          Expanded(
            child: Text(
              'Abierto ahora',
              style: AppTextStyles.headingSm.copyWith(
                color: AppColors.neutral900,
              ),
            ),
          ),
          if (zones.length > 1)
            PopupMenuButton<String>(
              onSelected: onSelectZone,
              itemBuilder: (context) {
                return zones
                    .map(
                      (zone) => PopupMenuItem<String>(
                        value: zone.zoneId,
                        child: Text(zone.name),
                      ),
                    )
                    .toList(growable: false);
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.neutral100,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _activeZoneLabel(zones, activeZoneId, zoneName),
                      style: AppTextStyles.bodyXs.copyWith(
                        color: AppColors.neutral700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      size: 16,
                      color: AppColors.neutral700,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _activeZoneLabel(
    List<OpenNowZone> zones,
    String activeZoneId,
    String fallback,
  ) {
    for (final zone in zones) {
      if (zone.zoneId == activeZoneId) return zone.name;
    }
    return fallback;
  }
}

class _OpenNowResultsState extends StatelessWidget {
  const _OpenNowResultsState({
    required this.state,
    required this.onCardTap,
  });

  final OpenNowState state;
  final void Function(OpenNowMerchant merchant, int rank, bool isFallback)
      onCardTap;

  @override
  Widget build(BuildContext context) {
    final rankById = <String, int>{};
    for (var i = 0; i < state.merchants.length; i++) {
      rankById[state.merchants[i].merchantId] = i + 1;
    }

    OpenNowMerchant? special;
    for (final merchant in state.merchants) {
      if (merchant.isSpecialOnDutyHealth) {
        special = merchant;
        break;
      }
    }

    final regular = state.merchants
        .where((merchant) => merchant.merchantId != special?.merchantId)
        .toList(growable: false);
    final grouped = _groupByCategory(regular);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ZoneTitle(
          zoneName: state.activeZoneName,
          subtitle: 'Locales que podrian resolverte algo en este momento',
        ),
        if (special != null) ...[
          const SizedBox(height: 14),
          _UrgentSpecialCard(
            merchant: special,
            onTap: () => onCardTap(
              special!,
              rankById[special.merchantId] ?? 1,
              false,
            ),
          ),
        ],
        const SizedBox(height: 10),
        for (final group in grouped) ...[
          const SizedBox(height: 8),
          _CategoryChip(label: group.label),
          const SizedBox(height: 8),
          for (final merchant in group.items) ...[
            _OpenNowCompactCard(
              merchant: merchant,
              onTap: () => onCardTap(
                merchant,
                rankById[merchant.merchantId] ?? 1,
                false,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }

  List<_CategoryGroup> _groupByCategory(List<OpenNowMerchant> merchants) {
    final map = <String, List<OpenNowMerchant>>{};
    final labelMap = <String, String>{};

    for (final merchant in merchants) {
      final label = merchant.categoryName.trim().isEmpty
          ? 'Comercio'
          : merchant.categoryName.trim();
      final key = label.toLowerCase();
      map.putIfAbsent(key, () => <OpenNowMerchant>[]).add(merchant);
      labelMap[key] = label;
    }

    final entries = map.entries.toList(growable: false)
      ..sort((a, b) => a.key.compareTo(b.key));

    return entries
        .map(
          (entry) => _CategoryGroup(
            label: labelMap[entry.key] ?? entry.key,
            items: entry.value,
          ),
        )
        .toList(growable: false);
  }
}

class _ZoneTitle extends StatelessWidget {
  const _ZoneTitle({
    required this.zoneName,
    required this.subtitle,
  });

  final String zoneName;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          zoneName,
          style: AppTextStyles.headingLg.copyWith(
            color: AppColors.neutral900,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          subtitle,
          style: AppTextStyles.bodySm.copyWith(
            color: AppColors.neutral700,
          ),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.neutral200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.bodyXs.copyWith(
          color: AppColors.neutral700,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _OpenNowCompactCard extends StatelessWidget {
  const _OpenNowCompactCard({
    required this.merchant,
    required this.onTap,
  });

  final OpenNowMerchant merchant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final resolution = MerchantBadgeResolver.resolve(
      state: MerchantVisualStateMappers.fromOpenNowMerchant(merchant),
      surface: MerchantSurface.compactCard,
    );
    final primaryBadge = resolution.primary;
    final secondaryBadge =
        resolution.secondary.isNotEmpty ? resolution.secondary.first : null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            _AvatarTile(label: merchant.name),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          merchant.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.labelMd.copyWith(
                            color: AppColors.neutral900,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (primaryBadge != null)
                        MerchantStatusBadge(
                          badge: primaryBadge,
                          compact: true,
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  if (secondaryBadge != null) ...[
                    const SizedBox(height: 4),
                    MerchantStatusBadge(
                      badge: secondaryBadge,
                      compact: true,
                    ),
                    const SizedBox(height: 4),
                  ],
                  Wrap(
                    spacing: 10,
                    runSpacing: 3,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _IconText(
                        icon: Icons.near_me,
                        text: _distanceText(merchant.distanceMeters),
                        iconColor: AppColors.primary500,
                      ),
                      _IconText(
                        icon: Icons.schedule,
                        text: _scheduleText(merchant),
                        iconColor: AppColors.primary500,
                      ),
                      _IconText(
                        icon: Icons.update,
                        text: _freshnessText(merchant.lastDataRefreshAt),
                        iconColor: AppColors.secondary500,
                        textColor: AppColors.neutral600,
                        italic: true,
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

  String _distanceText(double? meters) {
    if (meters == null) return 'Sin distancia';
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  String _scheduleText(OpenNowMerchant merchant) {
    final raw = merchant.effectiveScheduleLabel.trim();
    if (raw.isEmpty) return 'Horario no disponible';
    return raw.replaceFirst('hasta las ', '').replaceFirst('Hasta las ', '');
  }

  String _freshnessText(DateTime? refreshAt) {
    if (refreshAt == null) return 'sin dato';
    final diff = DateTime.now().difference(refreshAt);
    if (diff.inMinutes < 1) return 'ahora';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24) return '${diff.inHours} h';
    return DateFormat('dd/MM').format(refreshAt);
  }
}

class _UrgentSpecialCard extends StatelessWidget {
  const _UrgentSpecialCard({
    required this.merchant,
    required this.onTap,
  });

  final OpenNowMerchant merchant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F8),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: AppColors.primary500.withValues(alpha: 0.45),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: AppColors.primary500,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(26),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.emergency,
                        color: AppColors.primary500,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Estado de servicio',
                            style: AppTextStyles.bodyXs.copyWith(
                              color: AppColors.surface.withValues(alpha: 0.88),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'DE TURNO HOY',
                            style: AppTextStyles.labelMd.copyWith(
                              color: AppColors.surface,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'Actualizado ${_freshnessText(merchant.lastDataRefreshAt)}',
                      style: AppTextStyles.bodyXs.copyWith(
                        color: AppColors.surface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.call, size: 18),
                    label: Text(
                      'LLAMAR / VER AHORA',
                      style: AppTextStyles.labelMd.copyWith(
                        color: AppColors.primary500,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.surface,
                      foregroundColor: AppColors.primary500,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        merchant.name,
                        style: AppTextStyles.headingMd.copyWith(
                          color: AppColors.neutral900,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEFEF),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        'DE TURNO',
                        style: AppTextStyles.bodyXs.copyWith(
                          color: AppColors.primary500,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      size: 16,
                      color: AppColors.primary500,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        merchant.addressShort.isEmpty
                            ? 'Direccion no disponible'
                            : merchant.addressShort,
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.neutral700,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onTap,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xFFFBEAEA),
                          side: BorderSide.none,
                          minimumSize: const Size.fromHeight(46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        icon: const Icon(
                          Icons.directions,
                          color: AppColors.neutral700,
                          size: 18,
                        ),
                        label: Text(
                          'Como llegar',
                          style: AppTextStyles.bodySm.copyWith(
                            color: AppColors.neutral700,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 46,
                      height: 46,
                      child: OutlinedButton(
                        onPressed: onTap,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xFFFBEAEA),
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: const Icon(
                          Icons.share,
                          color: AppColors.neutral700,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _freshnessText(DateTime? refreshAt) {
    if (refreshAt == null) return 'hace poco';
    final diff = DateTime.now().difference(refreshAt);
    if (diff.inMinutes < 1) return 'hace instantes';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    return DateFormat('dd/MM HH:mm').format(refreshAt);
  }
}

class _OpenNowEmptyState extends StatelessWidget {
  const _OpenNowEmptyState({
    required this.fallbackMerchants,
    required this.onPrimaryTap,
    required this.onCardTap,
  });

  final List<OpenNowMerchant> fallbackMerchants;
  final VoidCallback onPrimaryTap;
  final void Function(OpenNowMerchant merchant, int rank) onCardTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 24),
        Container(
          width: 168,
          height: 168,
          decoration: const BoxDecoration(
            color: AppColors.neutral100,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.secondary500,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.location_off,
                color: AppColors.surface,
                size: 28,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Ahora no encontramos locales\nabiertos en esta zona',
          textAlign: TextAlign.center,
          style: AppTextStyles.headingMd.copyWith(
            color: AppColors.neutral900,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Proba ampliando el radio o volve a consultar\nen unos minutos.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMd.copyWith(
            color: AppColors.neutral700,
          ),
        ),
        const SizedBox(height: 18),
        ElevatedButton.icon(
          onPressed: onPrimaryTap,
          icon: const Icon(Icons.explore, size: 18),
          label: Text(
            'Ampliar radio de busqueda',
            style: AppTextStyles.labelMd.copyWith(color: AppColors.surface),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary500,
            foregroundColor: AppColors.surface,
            minimumSize: const Size(260, 46),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        if (fallbackMerchants.isNotEmpty) ...[
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Podrian abrir mas tarde hoy',
                  style: AppTextStyles.headingSm.copyWith(
                    color: AppColors.neutral900,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                'PROXIMAMENTE',
                style: AppTextStyles.bodyXs.copyWith(
                  color: AppColors.neutral500,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < fallbackMerchants.length; i++) ...[
            _FallbackCard(
              merchant: fallbackMerchants[i],
              onTap: () => onCardTap(fallbackMerchants[i], i + 1),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }
}

class _FallbackCard extends StatelessWidget {
  const _FallbackCard({
    required this.merchant,
    required this.onTap,
  });

  final OpenNowMerchant merchant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.neutral100,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: AppColors.neutral300.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.storefront,
                color: AppColors.neutral500,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          merchant.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.labelMd.copyWith(
                            color: AppColors.neutral900,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.neutral200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'CERRADO',
                          style: AppTextStyles.bodyXs.copyWith(
                            color: AppColors.neutral600,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Rubro: ${merchant.categoryName}',
                    style: AppTextStyles.bodyXs.copyWith(
                      color: AppColors.neutral700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.history_toggle_off,
                        size: 15,
                        color: AppColors.primary500,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          merchant.effectiveScheduleLabel.isEmpty
                              ? 'Horario de hoy no disponible'
                              : merchant.effectiveScheduleLabel,
                          style: AppTextStyles.bodySm.copyWith(
                            color: AppColors.primary500,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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
}

class _OpenNowErrorState extends StatelessWidget {
  const _OpenNowErrorState({
    required this.onRetry,
  });

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
      child: Column(
        children: [
          Container(
            width: 170,
            height: 170,
            decoration: BoxDecoration(
              color: AppColors.neutral100,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.neutral200,
                width: 2,
              ),
            ),
            child: Center(
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: AppColors.neutral50,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: const Icon(
                  Icons.cloud_off,
                  color: AppColors.neutral500,
                  size: 52,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'No pudimos cargar los\ncomercios abiertos ahora',
            textAlign: TextAlign.center,
            style: AppTextStyles.headingLg.copyWith(
              color: AppColors.neutral900,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Revisa tu conexion o intenta de nuevo.',
            style: AppTextStyles.bodyMd.copyWith(
              color: AppColors.neutral700,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary500,
                foregroundColor: AppColors.surface,
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: const Text('Reintentar'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.neutral200,
                foregroundColor: AppColors.neutral900,
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: const Text('Volver'),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.neutral100,
              borderRadius: BorderRadius.circular(14),
              border: const Border(
                left: BorderSide(
                  color: AppColors.primary300,
                  width: 3,
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info,
                  color: AppColors.primary500,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Dato de interes\nLa mayoria de los comercios cercanos suelen abrir de 09:00 a 20:00.',
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.neutral700,
                    ),
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

class _OpenNowLoadingState extends StatelessWidget {
  const _OpenNowLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SkeletonLine(widthFactor: 0.58, height: 34),
        SizedBox(height: 8),
        _SkeletonLine(widthFactor: 0.42, height: 13),
        SizedBox(height: 16),
        Row(
          children: [
            _SkeletonChip(),
            SizedBox(width: 8),
            _SkeletonChip(width: 88),
            SizedBox(width: 8),
            _SkeletonChip(width: 72),
          ],
        ),
        SizedBox(height: 14),
        _SkeletonCard(height: 170),
        SizedBox(height: 14),
        _SkeletonCard(height: 140),
        SizedBox(height: 14),
        _SkeletonCard(height: 140),
      ],
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({
    required this.widthFactor,
    required this.height,
  });

  final double widthFactor;
  final double height;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: AppColors.neutral200,
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

class _SkeletonChip extends StatelessWidget {
  const _SkeletonChip({
    this.width = 66,
  });

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 24,
      decoration: BoxDecoration(
        color: AppColors.neutral200,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({
    required this.height,
  });

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
      ),
    );
  }
}

class _AvatarTile extends StatelessWidget {
  const _AvatarTile({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary200,
            AppColors.secondary200,
          ],
        ),
      ),
      child: Center(
        child: Text(
          _initials(label),
          style: AppTextStyles.bodySm.copyWith(
            color: AppColors.neutral900,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return 'L';
    final parts = clean.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    final first = parts.first.isEmpty ? '' : parts.first[0];
    final second = parts[1].isEmpty ? '' : parts[1][0];
    return '$first$second'.toUpperCase();
  }
}

class _IconText extends StatelessWidget {
  const _IconText({
    required this.icon,
    required this.text,
    required this.iconColor,
    this.textColor = AppColors.neutral700,
    this.italic = false,
  });

  final IconData icon;
  final String text;
  final Color iconColor;
  final Color textColor;
  final bool italic;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: iconColor),
        const SizedBox(width: 3),
        Text(
          text,
          style: AppTextStyles.bodyXs.copyWith(
            color: textColor,
            fontStyle: italic ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      ],
    );
  }
}

class _CategoryGroup {
  const _CategoryGroup({
    required this.label,
    required this.items,
  });

  final String label;
  final List<OpenNowMerchant> items;
}
