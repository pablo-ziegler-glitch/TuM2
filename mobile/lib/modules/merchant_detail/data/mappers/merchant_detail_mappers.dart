import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../merchant_badges/domain/merchant_badge_resolver.dart';
import '../../../merchant_badges/domain/merchant_visual_models.dart';
import '../../../merchant_badges/domain/trust_badges.dart';
import '../../../merchant_badges/widgets/merchant_badge_widgets.dart';
import '../../domain/merchant_detail_view_data.dart';
import '../dtos/merchant_detail_dto.dart';

const Map<String, String> _categoryFallbackLabelById = {
  'farmacia': 'Farmacias',
  'kiosco': 'Kioscos',
  'almacen': 'Almacenes',
  'veterinaria': 'Veterinarias',
  'comida_al_paso': 'Comida al paso',
  'casa_de_comidas': 'Rotiserías',
  'gomeria': 'Gomerias',
  'panaderia': 'Panaderías',
  'confiteria': 'Confiterías',
};

const List<String> _orderedScheduleKeys = [
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
  'sunday',
];

const Map<String, String> _scheduleDayLabelByKey = {
  'monday': 'Lunes',
  'tuesday': 'Martes',
  'wednesday': 'Miercoles',
  'thursday': 'Jueves',
  'friday': 'Viernes',
  'saturday': 'Sabado',
  'sunday': 'Domingo',
};

MerchantPublicViewData mapCoreDtoToViewData(MerchantCoreDto dto) {
  final categoryId = _firstNonEmpty(
    _stringValue(dto.data['categoryId']),
    _stringValue(dto.data['category']),
  );

  return MerchantPublicViewData(
    merchantId: dto.id,
    zoneId: _firstNonEmpty(
      _stringValue(dto.data['zoneId']),
      _stringValue(dto.data['zone']),
      'unknown',
    ),
    name: _firstNonEmpty(_stringValue(dto.data['name']), dto.id),
    categoryId: categoryId,
    categoryLabel: _firstNonEmpty(
      _stringValue(dto.data['categoryLabel']),
      _categoryFallbackLabelById[categoryId],
      categoryId,
      'Comercio',
    ),
    coverImageUrl: _firstNonEmpty(
      _stringValue(dto.data['coverImageUrl']),
      _firstImage(dto.data['coverImages']),
    ),
    logoUrl: _stringValue(dto.data['logoUrl']).isEmpty
        ? null
        : _stringValue(dto.data['logoUrl']),
    address: _firstNonEmpty(
      _stringValue(dto.data['address']),
      'Direccion no disponible',
    ),
    phonePrimary: _nonEmptyOrNull(
      _firstNonEmpty(
        _stringValue(dto.data['phonePrimary']),
        _stringValue(dto.data['phone']),
      ),
    ),
    lat: _doubleValue(dto.data['lat']),
    lng: _doubleValue(dto.data['lng']),
    mapsUrl: _nonEmptyOrNull(_stringValue(dto.data['mapsUrl'])),
    isOpenNow: _boolValue(dto.data['isOpenNow']),
    hasPharmacyDutyToday: _boolValue(dto.data['hasPharmacyDutyToday']) ??
        _boolValue(dto.data['isOnDutyToday']) ??
        false,
    openStatusLabel: _firstNonEmpty(
      _stringValue(dto.data['openStatusLabel']),
      _stringValue(dto.data['todayScheduleLabel']),
      'Horario no disponible',
    ),
    lastDataRefreshAt: _dateTimeValue(dto.data['lastDataRefreshAt']),
    featuredProductIds: _stringListValue(
      dto.data['featuredProductIds'] ?? dto.data['featuredProducts'],
    ),
    verificationStatus: _firstNonEmpty(
        _stringValue(dto.data['verificationStatus']), 'unverified'),
    visibilityStatus:
        _firstNonEmpty(_stringValue(dto.data['visibilityStatus']), 'visible'),
    lifecycleStatus: _firstNonEmpty(_stringValue(dto.data['status']), 'active'),
    operationalSignalType:
        _firstNonEmpty(_stringValue(dto.data['operationalSignalType']), 'none'),
    manualOverrideMode:
        _firstNonEmpty(_stringValue(dto.data['manualOverrideMode']), 'none'),
    publicStatusLabel:
        _nonEmptyOrNull(_stringValue(dto.data['publicStatusLabel'])),
    is24h: _boolValue(dto.data['is24h']),
    badges: parseTrustBadges(dto.data['badges']),
    primaryTrustBadge: TrustBadgeId.fromValue(
      _stringValue(dto.data['primaryTrustBadge']),
    ),
    scheduleSummary: dto.data['scheduleSummary'] is Map
        ? MerchantScheduleSummary.fromMap(
            Map<String, dynamic>.from(dto.data['scheduleSummary'] as Map),
          )
        : null,
    nextOpenAt: _dateTimeValue(dto.data['nextOpenAt']),
    nextCloseAt: _dateTimeValue(dto.data['nextCloseAt']),
    nextTransitionAt: _dateTimeValue(dto.data['nextTransitionAt']),
    isOpenNowSnapshot: _boolValue(dto.data['isOpenNowSnapshot']),
    snapshotComputedAt: _dateTimeValue(dto.data['snapshotComputedAt']),
  );
}

MerchantStatusBadgeViewData mapStatusBadge(MerchantPublicViewData merchant) {
  final visualState = MerchantVisualState(
    visibility: _visibility(merchant.visibilityStatus),
    lifecycle: _lifecycle(merchant.lifecycleStatus),
    confidence: _confidence(merchant.verificationStatus),
    opening: _opening(merchant.isOpenNow),
    guardState: _detailGuardState(merchant),
    operationalSignal: _operational(merchant.operationalSignalType),
    show24hBadge: merchant.is24h == true,
    twentyFourHourCooldownActive: false,
    categoryLabel: merchant.categoryLabel,
    claimState: null,
    hasSufficientScheduleInfo: merchant.openStatusLabel.trim().isNotEmpty,
    manualOverrideMode: merchant.manualOverrideMode,
    informational: merchant.manualOverrideMode == 'informational',
  );
  final resolution = MerchantBadgeResolver.resolve(
    state: visualState,
    surface: MerchantSurface.detail,
  );
  final primary = resolution.primary ?? MerchantBadgeKey.noInfo;
  final style = MerchantBadgeStyleResolver.resolve(
    badge: primary,
    darkMode: false,
    disabled: false,
  );
  final type = switch (primary) {
    MerchantBadgeKey.onDuty => MerchantStatusBadgeType.duty,
    MerchantBadgeKey.openNow ||
    MerchantBadgeKey.openCompact =>
      MerchantStatusBadgeType.open,
    MerchantBadgeKey.closed ||
    MerchantBadgeKey.closedForVacation ||
    MerchantBadgeKey.temporaryClosure ||
    MerchantBadgeKey.opensLater =>
      MerchantStatusBadgeType.closed,
    _ => MerchantStatusBadgeType.referential,
  };

  return MerchantStatusBadgeViewData(
    type: type,
    label: MerchantBadgeLabelResolver.label(
      badge: primary,
      compact: false,
    ),
    backgroundColor: style.background,
    foregroundColor: style.foreground,
    primaryKey: primary,
    secondary: resolution.secondary,
    confidence: resolution.confidence,
  );
}

MerchantFeaturedProductViewData mapProductDtoToViewData(
    MerchantProductDto dto) {
  final referencePrice = _doubleValue(dto.data['referencePrice']);
  final priceLabel = _firstNonEmpty(
    _stringValue(dto.data['priceLabel']),
    referencePrice == null ? '' : _formatCurrency(referencePrice),
  );

  return MerchantFeaturedProductViewData(
    productId: dto.id,
    name: _firstNonEmpty(
      _stringValue(dto.data['name']),
      _stringValue(dto.data['title']),
      'Producto destacado',
    ),
    priceLabel: priceLabel,
    imageUrl: _firstImage(dto.data['images']) ??
        _nonEmptyOrNull(_stringValue(dto.data['imageUrl'])),
  );
}

MerchantScheduleViewData? mapScheduleDtoToViewData(MerchantScheduleDto dto) {
  final weeklySchedule = _mapValue(dto.data['weeklySchedule']);
  final legacySchedule = _mapValue(dto.data['schedule']);
  final rawSchedule =
      weeklySchedule.isNotEmpty ? weeklySchedule : legacySchedule;
  if (rawSchedule.isEmpty) return null;

  final todayKey = _todayScheduleKey();
  final days = <MerchantScheduleDayViewData>[];

  for (final dayKey in _orderedScheduleKeys) {
    final rawEntry = rawSchedule[dayKey];
    if (rawEntry == null) continue;

    final slotsLabel = _slotsLabel(rawEntry);
    if (slotsLabel.isEmpty) continue;

    days.add(
      MerchantScheduleDayViewData(
        dayKey: dayKey,
        dayLabel: _scheduleDayLabelByKey[dayKey] ?? dayKey,
        slotsLabel: slotsLabel,
        isToday: dayKey == todayKey,
      ),
    );
  }

  if (days.isEmpty) return null;
  return MerchantScheduleViewData(days: days);
}

List<MerchantOperationalSignalViewData> mapSignalsDtoToViewData(
  MerchantOperationalSignalsDto dto,
) {
  final nestedSignals = _mapValue(dto.data['signals']);
  final derivedSignals = _mapValue(dto.data['derivedSignals']);
  final merged = <String, dynamic>{
    ...nestedSignals,
    ...derivedSignals,
    ...dto.data,
  };
  return mapOperationalSignalsMapToViewData(merged);
}

List<MerchantOperationalSignalViewData> mapOperationalSignalsMapToViewData(
  Map<String, dynamic> source,
) {
  if (source.isEmpty) return const [];

  final signals = <MerchantOperationalSignalViewData>[];
  final signalType = _stringValue(source['signalType']);
  final isActive = _boolValue(source['isActive']) == true ||
      _boolValue(source['hasOperationalSignal']) == true;
  final message = _stringValue(source['message']);

  if (isActive) {
    if (signalType == 'vacation') {
      signals.add(
        MerchantOperationalSignalViewData(
          id: 'operationalSignalType',
          label: message.isNotEmpty ? message : 'De vacaciones',
          isAlert: true,
        ),
      );
    } else if (signalType == 'temporary_closure') {
      signals.add(
        MerchantOperationalSignalViewData(
          id: 'operationalSignalType',
          label: message.isNotEmpty ? message : 'Cerrado temporalmente',
          isAlert: true,
        ),
      );
    } else if (signalType == 'delay') {
      signals.add(
        MerchantOperationalSignalViewData(
          id: 'operationalSignalType',
          label: message.isNotEmpty ? message : 'Abre más tarde',
          isAlert: false,
        ),
      );
    }
  }

  void addSignal(
    String key,
    String label, {
    bool isAlert = false,
  }) {
    if (_boolValue(source[key]) != true) return;
    signals.add(
      MerchantOperationalSignalViewData(
        id: key,
        label: label,
        isAlert: isAlert,
      ),
    );
  }

  addSignal(
    'temporaryClosed',
    'Cerrado temporalmente',
    isAlert: true,
  );
  addSignal('hasDelivery', 'Hace envios');
  addSignal('acceptsWhatsappOrders', 'Pedidos por WhatsApp');
  addSignal('supportsOrders', 'Toma pedidos');
  addSignal('is24h', 'Atencion 24 horas');
  addSignal('hasPharmacyDutyToday', 'Farmacia de turno');

  if (_boolValue(source['openNowManualOverride']) == true) {
    signals.add(
      const MerchantOperationalSignalViewData(
        id: 'openNowManualOverride',
        label: 'Estado manual activo',
        isAlert: false,
      ),
    );
  }

  final deduped = <String, MerchantOperationalSignalViewData>{};
  for (final signal in signals) {
    deduped[signal.id] = signal;
  }
  return deduped.values.toList(growable: false);
}

PharmacyDutyViewData mapDutyDtoToViewData(PharmacyDutyDto dto) {
  return PharmacyDutyViewData(
    endsAt: _dateTimeValue(dto.data['endsAt']),
  );
}

MerchantVisibilityState _visibility(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'visible':
      return MerchantVisibilityState.visible;
    case 'review_pending':
      return MerchantVisibilityState.reviewPending;
    case 'suppressed':
      return MerchantVisibilityState.suppressed;
    default:
      return MerchantVisibilityState.hidden;
  }
}

MerchantLifecycleState _lifecycle(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'draft':
      return MerchantLifecycleState.draft;
    case 'inactive':
      return MerchantLifecycleState.inactive;
    case 'archived':
      return MerchantLifecycleState.archived;
    default:
      return MerchantLifecycleState.active;
  }
}

MerchantConfidenceState _confidence(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'verified':
      return MerchantConfidenceState.verified;
    case 'validated':
      return MerchantConfidenceState.validated;
    case 'claimed':
      return MerchantConfidenceState.claimed;
    case 'community_submitted':
      return MerchantConfidenceState.communitySubmitted;
    case 'referential':
      return MerchantConfidenceState.referential;
    default:
      return MerchantConfidenceState.unverified;
  }
}

MerchantOpeningState _opening(bool? value) {
  if (value == true) return MerchantOpeningState.openNow;
  if (value == false) return MerchantOpeningState.closed;
  return MerchantOpeningState.noInfo;
}

MerchantOperationalSignalState _operational(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'vacation':
      return MerchantOperationalSignalState.vacation;
    case 'temporary_closure':
      return MerchantOperationalSignalState.temporaryClosure;
    case 'delay':
      return MerchantOperationalSignalState.opensLater;
    default:
      return MerchantOperationalSignalState.none;
  }
}

MerchantPharmacyGuardState _detailGuardState(MerchantPublicViewData merchant) {
  if (merchant.publicStatusLabel == 'guardia_en_verificacion') {
    return MerchantPharmacyGuardState.guardVerification;
  }
  if (merchant.publicStatusLabel == 'cambio_operativo_en_curso') {
    return MerchantPharmacyGuardState.guardOperationalChange;
  }
  if (merchant.hasPharmacyDutyToday) return MerchantPharmacyGuardState.onDuty;
  return MerchantPharmacyGuardState.none;
}

String _todayScheduleKey() {
  final weekday = DateTime.now().weekday;
  switch (weekday) {
    case DateTime.monday:
      return 'monday';
    case DateTime.tuesday:
      return 'tuesday';
    case DateTime.wednesday:
      return 'wednesday';
    case DateTime.thursday:
      return 'thursday';
    case DateTime.friday:
      return 'friday';
    case DateTime.saturday:
      return 'saturday';
    default:
      return 'sunday';
  }
}

String _slotsLabel(dynamic rawEntry) {
  final entryMap = _mapValue(rawEntry);
  if (entryMap.isNotEmpty) {
    if (_boolValue(entryMap['closed']) == true ||
        _boolValue(entryMap['isClosed']) == true) {
      return 'Cerrado';
    }

    final mapSlots = _mapSlots(entryMap);
    if (mapSlots.isNotEmpty) return mapSlots.join(' · ');

    final singleSlot = _singleSlotLabel(entryMap);
    if (singleSlot.isNotEmpty) return singleSlot;

    return 'Sin horario cargado';
  }

  if (rawEntry is List<dynamic>) {
    final labels = rawEntry
        .map((slot) => _singleSlotLabel(_mapValue(slot)))
        .where((label) => label.isNotEmpty)
        .toList(growable: false);
    if (labels.isEmpty) return 'Sin horario cargado';
    return labels.join(' · ');
  }

  return '';
}

List<String> _mapSlots(Map<String, dynamic> rawEntry) {
  final dynamic rawSlots = rawEntry['slots'];
  if (rawSlots is! List<dynamic>) return const [];

  return rawSlots
      .map((slot) => _singleSlotLabel(_mapValue(slot)))
      .where((label) => label.isNotEmpty)
      .toList(growable: false);
}

String _singleSlotLabel(Map<String, dynamic> rawSlot) {
  final open = _stringValue(rawSlot['open']);
  final close = _stringValue(rawSlot['close']);
  if (open.isEmpty || close.isEmpty) return '';
  return '$open - $close';
}

String _formatCurrency(double value) {
  if (value % 1 == 0) {
    return '\$${value.toStringAsFixed(0)}';
  }
  return '\$${value.toStringAsFixed(2)}';
}

String? _firstImage(dynamic rawImages) {
  if (rawImages is! List<dynamic>) return null;
  for (final image in rawImages) {
    final value = image?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return null;
}

Map<String, dynamic> _mapValue(dynamic raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) {
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }
  return const {};
}

List<String> _stringListValue(dynamic raw) {
  if (raw is! List<dynamic>) return const [];
  return raw
      .map((value) => value.toString().trim())
      .where((value) => value.isNotEmpty)
      .toList(growable: false);
}

String _stringValue(dynamic raw) {
  if (raw == null) return '';
  return raw.toString().trim();
}

double? _doubleValue(dynamic raw) {
  if (raw == null) return null;
  if (raw is num) return raw.toDouble();
  return double.tryParse(raw.toString());
}

bool? _boolValue(dynamic raw) {
  if (raw == null) return null;
  if (raw is bool) return raw;
  if (raw is num) return raw != 0;
  final normalized = raw.toString().trim().toLowerCase();
  if (normalized == 'true' || normalized == '1') return true;
  if (normalized == 'false' || normalized == '0') return false;
  return null;
}

DateTime? _dateTimeValue(dynamic raw) {
  if (raw == null) return null;
  if (raw is Timestamp) return raw.toDate().toLocal();
  if (raw is DateTime) return raw.toLocal();
  if (raw is String) {
    return DateTime.tryParse(raw)?.toLocal();
  }
  return null;
}

String? _nonEmptyOrNull(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) return null;
  return normalized;
}

String _firstNonEmpty(
  String? first,
  String? second, [
  String? third,
  String? fourth,
]) {
  final candidates = [first, second, third, fourth];
  for (final candidate in candidates) {
    final value = candidate?.trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return '';
}
