enum OperationalSignalType {
  none,
  vacation,
  temporaryClosure,
  delay,
}

extension OperationalSignalTypeX on OperationalSignalType {
  String get firestoreValue {
    switch (this) {
      case OperationalSignalType.none:
        return 'none';
      case OperationalSignalType.vacation:
        return 'vacation';
      case OperationalSignalType.temporaryClosure:
        return 'temporary_closure';
      case OperationalSignalType.delay:
        return 'delay';
    }
  }

  String get publicLabel {
    switch (this) {
      case OperationalSignalType.none:
        return 'Sin señal activa';
      case OperationalSignalType.vacation:
        return 'De vacaciones';
      case OperationalSignalType.temporaryClosure:
        return 'Cerrado temporalmente';
      case OperationalSignalType.delay:
        return 'Abre más tarde';
    }
  }

  bool get forcesClosed =>
      this == OperationalSignalType.vacation ||
      this == OperationalSignalType.temporaryClosure;

  static OperationalSignalType fromFirestoreValue(String? value) {
    switch (value) {
      case 'vacation':
        return OperationalSignalType.vacation;
      case 'temporary_closure':
        return OperationalSignalType.temporaryClosure;
      case 'delay':
        return OperationalSignalType.delay;
      default:
        return OperationalSignalType.none;
    }
  }
}

const int operationalSignalSchemaVersion = 1;
const int operationalSignalMaxMessageLength = 80;

class OwnerOperationalSignal {
  const OwnerOperationalSignal({
    required this.merchantId,
    required this.ownerUserId,
    required this.signalType,
    required this.isActive,
    required this.message,
    required this.forceClosed,
    required this.schemaVersion,
    this.updatedAt,
    this.updatedByUid,
    this.createdAt,
    this.isOpenNow,
    this.todayScheduleLabel,
    this.hasScheduleConfigured,
  });

  final String merchantId;
  final String ownerUserId;
  final OperationalSignalType signalType;
  final bool isActive;
  final String? message;
  final bool forceClosed;
  final int schemaVersion;
  final DateTime? updatedAt;
  final String? updatedByUid;
  final DateTime? createdAt;
  final bool? isOpenNow;
  final String? todayScheduleLabel;
  final bool? hasScheduleConfigured;

  bool get hasActiveSignal =>
      isActive && signalType != OperationalSignalType.none;
  bool get isInformational => hasActiveSignal && !forceClosed;

  static OwnerOperationalSignal empty({
    required String merchantId,
    required String ownerUserId,
  }) {
    return OwnerOperationalSignal(
      merchantId: merchantId,
      ownerUserId: ownerUserId,
      signalType: OperationalSignalType.none,
      isActive: false,
      message: null,
      forceClosed: false,
      schemaVersion: operationalSignalSchemaVersion,
    );
  }

  OwnerOperationalSignal copyWith({
    String? merchantId,
    String? ownerUserId,
    OperationalSignalType? signalType,
    bool? isActive,
    String? message,
    bool clearMessage = false,
    bool? forceClosed,
    int? schemaVersion,
    DateTime? updatedAt,
    String? updatedByUid,
    DateTime? createdAt,
    bool? isOpenNow,
    bool clearIsOpenNow = false,
    String? todayScheduleLabel,
    bool clearTodayScheduleLabel = false,
    bool? hasScheduleConfigured,
    bool clearHasScheduleConfigured = false,
  }) {
    return OwnerOperationalSignal(
      merchantId: merchantId ?? this.merchantId,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      signalType: signalType ?? this.signalType,
      isActive: isActive ?? this.isActive,
      message: clearMessage ? null : (message ?? this.message),
      forceClosed: forceClosed ?? this.forceClosed,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedByUid: updatedByUid ?? this.updatedByUid,
      createdAt: createdAt ?? this.createdAt,
      isOpenNow: clearIsOpenNow ? null : (isOpenNow ?? this.isOpenNow),
      todayScheduleLabel: clearTodayScheduleLabel
          ? null
          : (todayScheduleLabel ?? this.todayScheduleLabel),
      hasScheduleConfigured: clearHasScheduleConfigured
          ? null
          : (hasScheduleConfigured ?? this.hasScheduleConfigured),
    );
  }
}
