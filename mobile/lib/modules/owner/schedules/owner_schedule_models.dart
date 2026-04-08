import 'package:cloud_firestore/cloud_firestore.dart';

enum DayScheduleMode { closed, continuous, split }

enum ScheduleExceptionType { closed, specialHours }

class TimeBlock {
  const TimeBlock({
    required this.open,
    required this.close,
  });

  final String open;
  final String close;

  Map<String, dynamic> toMap() => {
        'open': open,
        'close': close,
      };

  static TimeBlock fromMap(Map<String, dynamic> map) {
    return TimeBlock(
      open: (map['open'] as String?) ?? '',
      close: (map['close'] as String?) ?? '',
    );
  }
}

class DayScheduleDraft {
  const DayScheduleDraft({
    required this.dayKey,
    required this.dayLabel,
    required this.mode,
    this.firstOpen,
    this.firstClose,
    this.secondOpen,
    this.secondClose,
  });

  final String dayKey;
  final String dayLabel;
  final DayScheduleMode mode;
  final String? firstOpen;
  final String? firstClose;
  final String? secondOpen;
  final String? secondClose;

  DayScheduleDraft copyWith({
    DayScheduleMode? mode,
    String? firstOpen,
    bool clearFirstOpen = false,
    String? firstClose,
    bool clearFirstClose = false,
    String? secondOpen,
    bool clearSecondOpen = false,
    String? secondClose,
    bool clearSecondClose = false,
  }) {
    return DayScheduleDraft(
      dayKey: dayKey,
      dayLabel: dayLabel,
      mode: mode ?? this.mode,
      firstOpen: clearFirstOpen ? null : (firstOpen ?? this.firstOpen),
      firstClose: clearFirstClose ? null : (firstClose ?? this.firstClose),
      secondOpen: clearSecondOpen ? null : (secondOpen ?? this.secondOpen),
      secondClose: clearSecondClose ? null : (secondClose ?? this.secondClose),
    );
  }
}

class ScheduleExceptionDraft {
  const ScheduleExceptionDraft({
    required this.id,
    required this.date,
    required this.type,
    required this.mode,
    this.reason,
    this.firstOpen,
    this.firstClose,
    this.secondOpen,
    this.secondClose,
  });

  final String id;
  final DateTime date;
  final ScheduleExceptionType type;
  final DayScheduleMode mode;
  final String? reason;
  final String? firstOpen;
  final String? firstClose;
  final String? secondOpen;
  final String? secondClose;

  ScheduleExceptionDraft copyWith({
    DateTime? date,
    ScheduleExceptionType? type,
    DayScheduleMode? mode,
    String? reason,
    bool clearReason = false,
    String? firstOpen,
    bool clearFirstOpen = false,
    String? firstClose,
    bool clearFirstClose = false,
    String? secondOpen,
    bool clearSecondOpen = false,
    String? secondClose,
    bool clearSecondClose = false,
  }) {
    return ScheduleExceptionDraft(
      id: id,
      date: date ?? this.date,
      type: type ?? this.type,
      mode: mode ?? this.mode,
      reason: clearReason ? null : (reason ?? this.reason),
      firstOpen: clearFirstOpen ? null : (firstOpen ?? this.firstOpen),
      firstClose: clearFirstClose ? null : (firstClose ?? this.firstClose),
      secondOpen: clearSecondOpen ? null : (secondOpen ?? this.secondOpen),
      secondClose: clearSecondClose ? null : (secondClose ?? this.secondClose),
    );
  }
}

class TemporaryClosureDraft {
  const TemporaryClosureDraft({
    required this.id,
    required this.startDate,
    required this.endDate,
    this.reason,
  });

  final String id;
  final DateTime startDate;
  final DateTime endDate;
  final String? reason;

  TemporaryClosureDraft copyWith({
    DateTime? startDate,
    DateTime? endDate,
    String? reason,
    bool clearReason = false,
  }) {
    return TemporaryClosureDraft(
      id: id,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      reason: clearReason ? null : (reason ?? this.reason),
    );
  }
}

class OwnerScheduleBundle {
  const OwnerScheduleBundle({
    required this.weekly,
    required this.exceptions,
    required this.temporaryClosures,
    required this.version,
    this.timezone = 'America/Argentina/Buenos_Aires',
  });

  final List<DayScheduleDraft> weekly;
  final List<ScheduleExceptionDraft> exceptions;
  final List<TemporaryClosureDraft> temporaryClosures;
  final int version;
  final String timezone;
}

class OwnerScheduleSavePayload {
  const OwnerScheduleSavePayload({
    required this.weekly,
    required this.exceptions,
    required this.temporaryClosures,
    required this.deletedExceptionIds,
    required this.deletedClosureIds,
    required this.currentVersion,
    required this.timezone,
  });

  final List<DayScheduleDraft> weekly;
  final List<ScheduleExceptionDraft> exceptions;
  final List<TemporaryClosureDraft> temporaryClosures;
  final Set<String> deletedExceptionIds;
  final Set<String> deletedClosureIds;
  final int currentVersion;
  final String timezone;
}

const orderedDayKeys = <({String key, String label})>[
  (key: 'monday', label: 'Lunes'),
  (key: 'tuesday', label: 'Martes'),
  (key: 'wednesday', label: 'Miércoles'),
  (key: 'thursday', label: 'Jueves'),
  (key: 'friday', label: 'Viernes'),
  (key: 'saturday', label: 'Sábado'),
  (key: 'sunday', label: 'Domingo'),
];

DayScheduleMode dayModeFromString(String raw) {
  switch (raw) {
    case 'continuous':
      return DayScheduleMode.continuous;
    case 'split':
      return DayScheduleMode.split;
    default:
      return DayScheduleMode.closed;
  }
}

String dayModeToString(DayScheduleMode mode) {
  switch (mode) {
    case DayScheduleMode.closed:
      return 'closed';
    case DayScheduleMode.continuous:
      return 'continuous';
    case DayScheduleMode.split:
      return 'split';
  }
}

ScheduleExceptionType exceptionTypeFromString(String raw) {
  return raw == 'special_hours'
      ? ScheduleExceptionType.specialHours
      : ScheduleExceptionType.closed;
}

String exceptionTypeToString(ScheduleExceptionType type) {
  switch (type) {
    case ScheduleExceptionType.closed:
      return 'closed';
    case ScheduleExceptionType.specialHours:
      return 'special_hours';
  }
}

DateTime? dateFromFirestore(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
