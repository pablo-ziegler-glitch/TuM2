/// Claves permitidas para `merchant_operational_signals/{merchantId}.signals`.
///
/// Se definen como enum para evitar mass assignment y escrituras arbitrarias.
enum OperationalSignalKey {
  temporaryClosed,
  hasDelivery,
  acceptsWhatsappOrders,
  openNowManualOverride,
}

extension OperationalSignalKeyX on OperationalSignalKey {
  String get fieldName {
    switch (this) {
      case OperationalSignalKey.temporaryClosed:
        return 'temporaryClosed';
      case OperationalSignalKey.hasDelivery:
        return 'hasDelivery';
      case OperationalSignalKey.acceptsWhatsappOrders:
        return 'acceptsWhatsappOrders';
      case OperationalSignalKey.openNowManualOverride:
        return 'openNowManualOverride';
    }
  }
}

const String ownerOperationalSignalsSourceType = 'owner_created';

class OperationalSignalsSnapshot {
  const OperationalSignalsSnapshot({
    required this.signals,
    this.updatedAt,
    this.updatedBy,
  });

  final OperationalSignals signals;
  final DateTime? updatedAt;
  final String? updatedBy;

  static const defaults = OperationalSignalsSnapshot(
    signals: OperationalSignals.defaults,
  );
}

class OperationalSignals {
  const OperationalSignals({
    required this.temporaryClosed,
    required this.hasDelivery,
    required this.acceptsWhatsappOrders,
    required this.openNowManualOverride,
  });

  final bool temporaryClosed;
  final bool hasDelivery;
  final bool acceptsWhatsappOrders;
  final bool openNowManualOverride;

  static const defaults = OperationalSignals(
    temporaryClosed: false,
    hasDelivery: false,
    acceptsWhatsappOrders: false,
    openNowManualOverride: false,
  );

  bool valueFor(OperationalSignalKey key) {
    switch (key) {
      case OperationalSignalKey.temporaryClosed:
        return temporaryClosed;
      case OperationalSignalKey.hasDelivery:
        return hasDelivery;
      case OperationalSignalKey.acceptsWhatsappOrders:
        return acceptsWhatsappOrders;
      case OperationalSignalKey.openNowManualOverride:
        return openNowManualOverride;
    }
  }

  OperationalSignals copyWith({
    bool? temporaryClosed,
    bool? hasDelivery,
    bool? acceptsWhatsappOrders,
    bool? openNowManualOverride,
  }) {
    return OperationalSignals(
      temporaryClosed: temporaryClosed ?? this.temporaryClosed,
      hasDelivery: hasDelivery ?? this.hasDelivery,
      acceptsWhatsappOrders:
          acceptsWhatsappOrders ?? this.acceptsWhatsappOrders,
      openNowManualOverride:
          openNowManualOverride ?? this.openNowManualOverride,
    );
  }

  OperationalSignals withValue(OperationalSignalKey key, bool value) {
    switch (key) {
      case OperationalSignalKey.temporaryClosed:
        return copyWith(temporaryClosed: value);
      case OperationalSignalKey.hasDelivery:
        return copyWith(hasDelivery: value);
      case OperationalSignalKey.acceptsWhatsappOrders:
        return copyWith(acceptsWhatsappOrders: value);
      case OperationalSignalKey.openNowManualOverride:
        return copyWith(openNowManualOverride: value);
    }
  }

  Map<String, bool> toMap() {
    return {
      OperationalSignalKey.temporaryClosed.fieldName: temporaryClosed,
      OperationalSignalKey.hasDelivery.fieldName: hasDelivery,
      OperationalSignalKey.acceptsWhatsappOrders.fieldName:
          acceptsWhatsappOrders,
      OperationalSignalKey.openNowManualOverride.fieldName:
          openNowManualOverride,
    };
  }

  factory OperationalSignals.fromMap(Map<String, dynamic>? map) {
    final raw = map ?? const <String, dynamic>{};
    return OperationalSignals(
      temporaryClosed:
          raw[OperationalSignalKey.temporaryClosed.fieldName] == true,
      hasDelivery: raw[OperationalSignalKey.hasDelivery.fieldName] == true,
      acceptsWhatsappOrders:
          raw[OperationalSignalKey.acceptsWhatsappOrders.fieldName] == true,
      openNowManualOverride:
          raw[OperationalSignalKey.openNowManualOverride.fieldName] == true,
    );
  }
}
