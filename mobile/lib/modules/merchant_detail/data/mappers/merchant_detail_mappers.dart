import '../../../../core/theme/app_colors.dart';
import '../../domain/merchant_detail_view_data.dart';
import '../dtos/merchant_detail_dto.dart';

const Map<String, String> _categoryFallbackLabelById = {
  'pharmacy': 'Farmacias',
  'farmacia': 'Farmacias',
  'kiosk': 'Kioscos',
  'kiosco': 'Kioscos',
  'convenience_store': 'Kioscos',
  'grocery': 'Almacenes',
  'almacen': 'Almacenes',
  'supermarket': 'Almacenes',
  'veterinary': 'Veterinarias',
  'veterinaria': 'Veterinarias',
  'fast_food': 'Tiendas de comida al paso',
  'prepared_food': 'Casas de comida/Rotiserias',
  'rotiseria': 'Casas de comida/Rotiserias',
  'tire_shop': 'Gomerias',
  'gomeria': 'Gomerias',
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

MerchantCoreViewData mapCoreDtoToViewData(MerchantCoreDto dto) {
  final categoryId = _firstNonEmpty(
    _stringValue(dto.data['categoryId']),
    _stringValue(dto.data['category']),
  );

  final categoryLabel = _firstNonEmpty(
    _stringValue(dto.data['categoryLabel']),
    _categoryFallbackLabelById[categoryId],
    categoryId,
    'Comercio',
  );

  final verificationStatus =
      _stringValue(dto.data['verificationStatus']).toLowerCase();
  final openStatusLabel = _firstNonEmpty(
    _stringValue(dto.data['openStatusLabel']),
    _stringValue(dto.data['todayScheduleLabel']),
    'Horario referencial',
  );

  final publicSignalsMap = _mapValue(dto.data['operationalSignals']);
  final publicSignals = mapOperationalSignalsMapToViewData(publicSignalsMap);

  final isOnDutyToday = _boolValue(dto.data['isOnDutyToday']) ??
      _boolValue(dto.data['hasPharmacyDutyToday']) ??
      _boolValue(publicSignalsMap['hasPharmacyDutyToday']) ??
      false;
  final isOpenNow = _boolValue(dto.data['isOpenNow']);

  final trustBadge = mapTrustBadgeFromVerificationStatus(verificationStatus);

  return MerchantCoreViewData(
    merchantId: dto.id,
    name: _firstNonEmpty(
      _stringValue(dto.data['name']),
      dto.id,
    ),
    categoryLabel: categoryLabel,
    zoneId: _firstNonEmpty(
      _stringValue(dto.data['zoneId']),
      _stringValue(dto.data['zone']),
    ),
    address: _firstNonEmpty(
      _stringValue(dto.data['address']),
      'Direccion no disponible',
    ),
    lat: _doubleValue(dto.data['lat']),
    lng: _doubleValue(dto.data['lng']),
    isOpenNow: isOpenNow,
    isOnDutyToday: isOnDutyToday,
    openStatusLabel: openStatusLabel,
    verificationStatus: verificationStatus,
    operationalBadge: mapOperationalBadge(
      isOnDutyToday: isOnDutyToday,
      isOpenNow: isOpenNow,
    ),
    trustBadges: trustBadge == null ? const [] : [trustBadge],
    operationalSignals: publicSignals,
  );
}

MerchantOperationalBadgeViewData mapOperationalBadge({
  required bool isOnDutyToday,
  required bool? isOpenNow,
}) {
  if (isOnDutyToday) {
    return const MerchantOperationalBadgeViewData(
      type: MerchantOperationalBadgeType.onDuty,
      label: 'Farmacia de turno',
      backgroundColor: AppColors.secondary50,
      foregroundColor: AppColors.secondary700,
    );
  }

  if (isOpenNow == true) {
    return const MerchantOperationalBadgeViewData(
      type: MerchantOperationalBadgeType.openNow,
      label: 'Abierto ahora',
      backgroundColor: AppColors.successBg,
      foregroundColor: AppColors.successFg,
    );
  }

  if (isOpenNow == false) {
    return const MerchantOperationalBadgeViewData(
      type: MerchantOperationalBadgeType.closed,
      label: 'Cerrado',
      backgroundColor: AppColors.errorBg,
      foregroundColor: AppColors.errorFg,
    );
  }

  return const MerchantOperationalBadgeViewData(
    type: MerchantOperationalBadgeType.referential,
    label: 'Horario referencial',
    backgroundColor: AppColors.infoBg,
    foregroundColor: AppColors.primary600,
  );
}

MerchantTrustBadgeViewData? mapTrustBadgeFromVerificationStatus(
  String rawStatus,
) {
  final status = rawStatus.toLowerCase().trim();

  switch (status) {
    case 'verified':
      return const MerchantTrustBadgeViewData(
        type: MerchantTrustBadgeType.verified,
        label: 'Verificado',
        backgroundColor: AppColors.successBg,
        foregroundColor: AppColors.successFg,
      );
    case 'validated':
    case 'claimed':
      return const MerchantTrustBadgeViewData(
        type: MerchantTrustBadgeType.claimed,
        label: 'Reclamado',
        backgroundColor: AppColors.primary50,
        foregroundColor: AppColors.primary600,
      );
    case 'referential':
      return const MerchantTrustBadgeViewData(
        type: MerchantTrustBadgeType.referential,
        label: 'Dato referencial',
        backgroundColor: AppColors.tertiary50,
        foregroundColor: AppColors.tertiary700,
      );
    case 'community_submitted':
      return const MerchantTrustBadgeViewData(
        type: MerchantTrustBadgeType.community,
        label: 'Información de la comunidad',
        backgroundColor: AppColors.warningBg,
        foregroundColor: AppColors.warningFg,
      );
    default:
      return null;
  }
}

MerchantProductViewData mapProductDtoToViewData(MerchantProductDto dto) {
  final referencePrice = _doubleValue(dto.data['referencePrice']);
  final priceLabel = _firstNonEmpty(
    _stringValue(dto.data['priceLabel']),
    referencePrice == null ? '' : _formatCurrency(referencePrice),
  );

  return MerchantProductViewData(
    productId: dto.id,
    merchantId: _firstNonEmpty(
      _stringValue(dto.data['merchantId']),
      '',
    ),
    name: _firstNonEmpty(
      _stringValue(dto.data['name']),
      _stringValue(dto.data['title']),
      'Producto',
    ),
    priceLabel: priceLabel,
    imageUrl: _firstImage(dto.data['images']),
  );
}

MerchantScheduleViewData? mapScheduleDtoToViewData(
  MerchantScheduleDto dto,
) {
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

  return MerchantScheduleViewData(
    timezone: _stringValue(dto.data['timezone']),
    days: days,
  );
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
