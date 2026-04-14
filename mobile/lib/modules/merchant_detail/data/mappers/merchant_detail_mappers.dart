import 'package:cloud_firestore/cloud_firestore.dart';

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

MerchantPublicViewData mapCoreDtoToViewData(MerchantCoreDto dto) {
  final categoryId = _firstNonEmpty(
    _stringValue(dto.data['categoryId']),
    _stringValue(dto.data['category']),
  );

  return MerchantPublicViewData(
    merchantId: dto.id,
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
  );
}

MerchantStatusBadgeViewData mapStatusBadge(MerchantPublicViewData merchant) {
  if (merchant.hasPharmacyDutyToday) {
    return const MerchantStatusBadgeViewData(
      type: MerchantStatusBadgeType.duty,
      label: 'Farmacia de turno',
      backgroundColor: AppColors.merchantSecondaryFixedDim,
      foregroundColor: AppColors.merchantOnSecondaryFixed,
    );
  }

  if (merchant.isOpenNow == true) {
    return const MerchantStatusBadgeViewData(
      type: MerchantStatusBadgeType.open,
      label: 'Abierto ahora',
      backgroundColor: AppColors.successBg,
      foregroundColor: AppColors.successFg,
    );
  }

  if (merchant.isOpenNow == false) {
    return const MerchantStatusBadgeViewData(
      type: MerchantStatusBadgeType.closed,
      label: 'Cerrado',
      backgroundColor: AppColors.errorBg,
      foregroundColor: AppColors.errorFg,
    );
  }

  return const MerchantStatusBadgeViewData(
    type: MerchantStatusBadgeType.referential,
    label: 'Horario referencial',
    backgroundColor: AppColors.merchantSurfaceHighest,
    foregroundColor: AppColors.merchantOnSurface,
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
