import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../merchant_badges/domain/merchant_badge_resolver.dart';
import '../../merchant_badges/domain/merchant_visual_models.dart';
import '../../merchant_badges/domain/merchant_visual_state_mappers.dart';
import '../../merchant_badges/widgets/merchant_badge_widgets.dart';
import '../models/pharmacy_duty_item.dart';
import '../models/pharmacy_zone.dart';
import '../providers/pharmacy_duty_notifier.dart';
import '../services/business_date.dart';
import '../services/distance_calculator.dart';

class PharmacyDutyScreen extends ConsumerStatefulWidget {
  const PharmacyDutyScreen({super.key});

  @override
  ConsumerState<PharmacyDutyScreen> createState() => _PharmacyDutyScreenState();
}

class _PharmacyDutyScreenState extends ConsumerState<PharmacyDutyScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(pharmacyDutyProvider.notifier).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pharmacyDutyProvider);
    final notifier = ref.read(pharmacyDutyProvider.notifier);
    final selectedZone = _findZoneById(state.zones, state.selectedZoneId);
    final openCount =
        state.items.where((item) => item.isOpenNow || item.is24Hours).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            _TopHeader(
              selectedDate: state.selectedDate,
              dates: _buildDateStrip(state.selectedDate),
              onDateTap: notifier.setDate,
              onCalendarTap: () =>
                  _pickDate(context, notifier, state.selectedDate),
              onMenuTap: () => _showZoneSheet(
                  context, state.zones, notifier, state.selectedZoneId),
            ),
            if (state.isRefreshing)
              const LinearProgressIndicator(
                minHeight: 2,
                color: AppColors.primary500,
              ),
            Expanded(
              child: Builder(
                builder: (context) {
                  if (state.isLoadingInitial) {
                    return const _LoadingState();
                  }
                  if (state.errorType == PharmacyDutyErrorType.technical &&
                      state.items.isEmpty) {
                    return _TechnicalErrorState(
                      onRetry: notifier.retry,
                    );
                  }
                  if (state.items.isEmpty) {
                    return _EmptyState(
                      onExploreDates: () =>
                          _pickDate(context, notifier, state.selectedDate),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: notifier.refresh,
                    child: _ResultsList(
                      selectedZoneName:
                          selectedZone?.name ?? 'Zona sin definir',
                      selectedDate: state.selectedDate,
                      openCount: openCount,
                      items: state.items,
                      selectedDateKey: state.selectedDateKey,
                      selectedZoneId: state.selectedZoneId,
                      isUsingCache: state.isUsingCachedData,
                      onChangeZone: () => _showZoneSheet(
                        context,
                        state.zones,
                        notifier,
                        state.selectedZoneId,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate(
    BuildContext context,
    PharmacyDutyNotifier notifier,
    DateTime selectedDate,
  ) async {
    final now = businessTodayUtcMinus3();
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(now.year - 1, now.month, now.day),
      lastDate: DateTime(now.year + 1, now.month, now.day),
      locale: const Locale('es'),
    );
    if (picked == null) return;
    await notifier.setDate(picked);
  }
}

class _TopHeader extends StatelessWidget {
  const _TopHeader({
    required this.selectedDate,
    required this.dates,
    required this.onDateTap,
    required this.onCalendarTap,
    required this.onMenuTap,
  });

  final DateTime selectedDate;
  final List<DateTime> dates;
  final ValueChanged<DateTime> onDateTap;
  final VoidCallback onCalendarTap;
  final VoidCallback onMenuTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        border: Border(
            bottom: BorderSide(color: Colors.blueGrey.withValues(alpha: 0.08))),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.primary500,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'M²',
                    style: AppTextStyles.labelSm.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'TuM2',
                  style: AppTextStyles.headingSm.copyWith(
                    color: AppColors.primary500,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: onCalendarTap,
                  icon: const Icon(Icons.calendar_month_outlined),
                  color: AppColors.neutral700,
                ),
                IconButton(
                  onPressed: onMenuTap,
                  icon: const Icon(Icons.menu),
                  color: AppColors.neutral700,
                ),
              ],
            ),
          ),
          SizedBox(
            height: 82,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) {
                final date = dates[index];
                return _DatePill(
                  date: date,
                  selected: _isSameDate(date, selectedDate),
                  onTap: () => onDateTap(date),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemCount: dates.length,
            ),
          ),
        ],
      ),
    );
  }
}

class _DatePill extends StatelessWidget {
  const _DatePill({
    required this.date,
    required this.selected,
    required this.onTap,
  });

  final DateTime date;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final today = businessTodayUtcMinus3();
    final isToday = _isSameDate(date, today);
    final smallLabel = isToday ? 'HOY' : _weekdayShort(date);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 56,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary500 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: selected ? null : Border.all(color: AppColors.neutral100),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primary500.withValues(alpha: 0.18),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              smallLabel,
              style: AppTextStyles.bodyXs.copyWith(
                color: selected
                    ? Colors.white.withValues(alpha: 0.8)
                    : AppColors.neutral500,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${date.day}',
              style: AppTextStyles.headingSm.copyWith(
                color: selected ? Colors.white : AppColors.neutral800,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultsList extends ConsumerWidget {
  const _ResultsList({
    required this.selectedZoneName,
    required this.selectedDate,
    required this.openCount,
    required this.items,
    required this.selectedDateKey,
    required this.selectedZoneId,
    required this.isUsingCache,
    required this.onChangeZone,
  });

  final String selectedZoneName;
  final DateTime selectedDate;
  final int openCount;
  final List<PharmacyDutyItem> items;
  final String selectedDateKey;
  final String selectedZoneId;
  final bool isUsingCache;
  final VoidCallback onChangeZone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = businessTodayUtcMinus3();
    final titleDate = _isSameDate(selectedDate, today)
        ? 'Hoy'
        : DateFormat('dd/MM', 'es').format(selectedDate);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: onChangeZone,
                    child: Row(
                      children: [
                        Text(
                          selectedZoneName.toUpperCase(),
                          style: AppTextStyles.bodyXs.copyWith(
                            color: AppColors.neutral500,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.keyboard_arrow_down,
                          size: 16,
                          color: AppColors.neutral500,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  RichText(
                    text: TextSpan(
                      style: AppTextStyles.headingMd.copyWith(
                        color: AppColors.neutral900,
                        height: 1.2,
                      ),
                      children: [
                        const TextSpan(text: 'Farmacias de\n'),
                        TextSpan(
                          text: 'Turno $titleDate',
                          style: AppTextStyles.headingMd.copyWith(
                            color: AppColors.primary500,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 74,
              height: 70,
              decoration: BoxDecoration(
                color: AppColors.primary50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary100),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$openCount',
                    style: AppTextStyles.headingMd.copyWith(
                      color: AppColors.primary500,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'ABIERTAS',
                    style: AppTextStyles.bodyXs.copyWith(
                      color: AppColors.primary500,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.9,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const _FilterRow(),
        if (isUsingCache) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.warningBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Mostrando última información guardada. Verificá antes de ir.',
              style: AppTextStyles.bodyXs.copyWith(color: AppColors.warningFg),
            ),
          ),
        ],
        const SizedBox(height: 14),
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _PharmacyCard(
              item: items[i],
              positionIndex: i,
              zoneId: selectedZoneId,
              dateKey: selectedDateKey,
            ),
          ),
        const SizedBox(height: 8),
        const _MapCtaCard(),
      ],
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: const [
          _FilterPill(icon: Icons.tune, label: 'Filtros'),
          SizedBox(width: 8),
          _FilterPill(
              icon: Icons.medical_services_outlined, label: 'Servicios'),
          SizedBox(width: 8),
          _FilterPill(icon: Icons.star_border, label: 'Calificación'),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.neutral500),
          const SizedBox(width: 6),
          Text(label,
              style:
                  AppTextStyles.bodyXs.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _PharmacyCard extends ConsumerWidget {
  const _PharmacyCard({
    required this.item,
    required this.positionIndex,
    required this.zoneId,
    required this.dateKey,
  });

  final PharmacyDutyItem item;
  final int positionIndex;
  final String zoneId;
  final String dateKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analytics = ref.read(pharmacyDutyAnalyticsProvider);
    final badgeResolution = MerchantBadgeResolver.resolve(
      state: MerchantVisualStateMappers.fromPharmacyDutyItem(item),
      surface: MerchantSurface.pharmacyPublic,
    );
    final primaryBadge = badgeResolution.primary;
    final confidenceBadge =
        _confidenceBadgeForVerification(item.verificationStatus);
    final actions = <Widget>[];

    if (item.canCall) {
      actions.add(
        _CircleActionButton(
          icon: Icons.call,
          onTap: () async {
            await analytics.logCallTap(
              merchantId: item.merchantId,
              zoneId: zoneId,
              date: dateKey,
              positionIndex: positionIndex,
            );
            await _launchPhone(item.phone!);
          },
        ),
      );
    }
    if (item.canNavigate) {
      actions.add(
        _CircleActionButton(
          icon: Icons.directions,
          onTap: () async {
            await analytics.logDirectionsTap(
              merchantId: item.merchantId,
              zoneId: zoneId,
              date: dateKey,
              positionIndex: positionIndex,
            );
            await _launchMaps(item);
          },
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.neutral100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      child: primaryBadge == null
                          ? const SizedBox.shrink()
                          : MerchantStatusBadge(
                              badge: primaryBadge,
                              compact: true,
                            ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.merchantName,
                      style: AppTextStyles.headingSm.copyWith(
                        color: AppColors.secondary500,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.addressLine,
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.neutral600,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _DistanceBlock(distanceMeters: item.distanceMeters),
            ],
          ),
          const SizedBox(height: 10),
          Container(height: 1, color: AppColors.neutral100),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _InfoLine(
                  icon: Icons.schedule,
                  label: 'Horario',
                  value: _scheduleLabel(item),
                ),
              ),
              Expanded(
                child: _InfoLine(
                  icon: Icons.medical_services_outlined,
                  label: 'Servicios',
                  value: item.is24Hours ? '24hs' : 'Turno vigente',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ...actions.expand((button) => [button, const SizedBox(width: 8)]),
              if (actions.isNotEmpty) const Spacer(),
              if (confidenceBadge != null)
                MerchantConfidenceBadge(
                  badge: confidenceBadge,
                ),
            ],
          ),
        ],
      ),
    );
  }

  MerchantBadgeKey? _confidenceBadgeForVerification(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'verified':
        return MerchantBadgeKey.confidenceVerified;
      case 'validated':
        return MerchantBadgeKey.confidenceValidated;
      case 'claimed':
        return MerchantBadgeKey.confidenceClaimed;
      case 'community_submitted':
        return MerchantBadgeKey.confidenceCommunity;
      case 'referential':
        return MerchantBadgeKey.confidenceReferential;
      default:
        return null;
    }
  }
}

class _DistanceBlock extends StatelessWidget {
  const _DistanceBlock({
    required this.distanceMeters,
  });

  final int? distanceMeters;

  @override
  Widget build(BuildContext context) {
    if (distanceMeters == null) {
      return Text(
        'Sin distancia',
        style: AppTextStyles.bodyXs.copyWith(
          color: AppColors.neutral500,
          fontWeight: FontWeight.w700,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'a ${DistanceCalculator.formatDistance(distanceMeters!)}',
          style: AppTextStyles.headingSm.copyWith(
            color: AppColors.primary500,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.neutral400),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: AppTextStyles.bodyXs.copyWith(
                  color: AppColors.neutral500,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                value,
                style: AppTextStyles.bodyXs.copyWith(
                  color: AppColors.neutral700,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CircleActionButton extends StatelessWidget {
  const _CircleActionButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.primary500,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary500.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _MapCtaCard extends StatelessWidget {
  const _MapCtaCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF66A8BF), Color(0xFF2A8FA8)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: -20,
            top: 10,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: -30,
            bottom: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.map, size: 18, color: AppColors.primary500),
                  const SizedBox(width: 8),
                  Text(
                    'Ver Mapa Interactivo',
                    style: AppTextStyles.labelMd.copyWith(
                      color: AppColors.primary500,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.onExploreDates,
  });

  final VoidCallback onExploreDates;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF7F7F7), Color(0xFFE7E7E7)],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Row(
              children: [
                Expanded(
                  child: Container(color: Colors.black.withValues(alpha: 0.03)),
                ),
                Expanded(
                  child: Container(color: Colors.white.withValues(alpha: 0.32)),
                ),
              ],
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.location_off,
                      color: AppColors.primary500,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Silencio en el barrio',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 42 / 1.4,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1C1B),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'No hay turnos registrados para esta fecha. Intentá con otra.',
                    style: AppTextStyles.bodyMd.copyWith(
                      color: const Color(0xFF1A1C1B),
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: onExploreDates,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(210, 46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      backgroundColor: const Color(0xFF00398D),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Explorar otras fechas'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TechnicalErrorState extends StatelessWidget {
  const _TechnicalErrorState({
    required this.onRetry,
  });

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 38, color: AppColors.neutral500),
            const SizedBox(height: 12),
            const Text(
              'No pudimos cargar las farmacias de turno.',
              style: AppTextStyles.headingSm,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary500,
                foregroundColor: Colors.white,
              ),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      itemBuilder: (_, __) {
        return Container(
          height: 168,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.neutral100),
          ),
        );
      },
      itemCount: 3,
    );
  }
}

List<DateTime> _buildDateStrip(DateTime selectedDate) {
  final normalized = normalizeBusinessDate(selectedDate);
  final today = businessTodayUtcMinus3();
  final start = _isSameDate(normalized, today)
      ? normalized
      : normalized.subtract(const Duration(days: 2));
  return List.generate(
    5,
    (index) => start.add(Duration(days: index)),
    growable: false,
  );
}

String _weekdayShort(DateTime date) {
  final value = DateFormat('EEE', 'es').format(date).replaceAll('.', '');
  return value.toUpperCase();
}

PharmacyZone? _findZoneById(List<PharmacyZone> zones, String zoneId) {
  for (final zone in zones) {
    if (zone.zoneId == zoneId) return zone;
  }
  return null;
}

Future<void> _showZoneSheet(
  BuildContext context,
  List<PharmacyZone> zones,
  PharmacyDutyNotifier notifier,
  String selectedZoneId,
) async {
  if (zones.isEmpty) return;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return ListView(
        shrinkWrap: true,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 8, 18, 12),
            child: Text('Seleccioná una zona', style: AppTextStyles.headingSm),
          ),
          for (final zone in zones)
            ListTile(
              leading: Icon(
                zone.zoneId == selectedZoneId
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: AppColors.primary500,
              ),
              title: Text(zone.name),
              onTap: () async {
                Navigator.of(context).pop();
                await notifier.setZone(zone.zoneId);
              },
            ),
        ],
      );
    },
  );
}

bool _isSameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String _scheduleLabel(PharmacyDutyItem item) {
  if (item.is24Hours) return 'Abierto 24hs';
  if (item.isOpenNow) return 'Abierta ahora';
  return 'Turno vigente';
}

Future<void> _launchPhone(String phone) async {
  final cleaned = phone.replaceAll(RegExp(r'[^0-9+]'), '');
  final uri = Uri.parse('tel:$cleaned');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

Future<void> _launchMaps(PharmacyDutyItem item) async {
  Uri uri;
  if (item.latitude != null && item.longitude != null) {
    uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${item.latitude},${item.longitude}',
    );
  } else {
    final encodedAddress = Uri.encodeComponent(item.addressLine);
    uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$encodedAddress');
  }
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
