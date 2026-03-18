import 'package:cloud_firestore/cloud_firestore.dart';

class DaySchedule {
  final String open;  // "HH:mm"
  final String close; // "HH:mm"
  final bool closed;

  const DaySchedule({
    required this.open,
    required this.close,
    required this.closed,
  });

  factory DaySchedule.fromMap(Map<String, dynamic> data) => DaySchedule(
        open: data['open'] as String? ?? '09:00',
        close: data['close'] as String? ?? '18:00',
        closed: data['closed'] as bool? ?? false,
      );

  Map<String, dynamic> toMap() => {
        'open': open,
        'close': close,
        'closed': closed,
      };

  DaySchedule copyWith({String? open, String? close, bool? closed}) =>
      DaySchedule(
        open: open ?? this.open,
        close: close ?? this.close,
        closed: closed ?? this.closed,
      );

  static const DaySchedule defaultOpen = DaySchedule(
    open: '09:00',
    close: '18:00',
    closed: false,
  );

  static const DaySchedule defaultClosed = DaySchedule(
    open: '09:00',
    close: '18:00',
    closed: true,
  );
}

class WeeklyScheduleModel {
  final String storeId;
  final String timezone;
  final DaySchedule monday;
  final DaySchedule tuesday;
  final DaySchedule wednesday;
  final DaySchedule thursday;
  final DaySchedule friday;
  final DaySchedule saturday;
  final DaySchedule sunday;
  final DateTime updatedAt;

  const WeeklyScheduleModel({
    required this.storeId,
    required this.timezone,
    required this.monday,
    required this.tuesday,
    required this.wednesday,
    required this.thursday,
    required this.friday,
    required this.saturday,
    required this.sunday,
    required this.updatedAt,
  });

  factory WeeklyScheduleModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final weekly = data['weeklySchedule'] as Map<String, dynamic>? ?? {};

    DaySchedule parseDay(String key) {
      final dayData = weekly[key] as Map<String, dynamic>?;
      return dayData != null ? DaySchedule.fromMap(dayData) : DaySchedule.defaultOpen;
    }

    return WeeklyScheduleModel(
      storeId: data['storeId'] as String? ?? '',
      timezone: data['timezone'] as String? ?? 'America/Argentina/Buenos_Aires',
      monday: parseDay('monday'),
      tuesday: parseDay('tuesday'),
      wednesday: parseDay('wednesday'),
      thursday: parseDay('thursday'),
      friday: parseDay('friday'),
      saturday: parseDay('saturday'),
      sunday: parseDay('sunday'),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'storeId': storeId,
        'timezone': timezone,
        'weeklySchedule': {
          'monday': monday.toMap(),
          'tuesday': tuesday.toMap(),
          'wednesday': wednesday.toMap(),
          'thursday': thursday.toMap(),
          'friday': friday.toMap(),
          'saturday': saturday.toMap(),
          'sunday': sunday.toMap(),
        },
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  /// Returns the DaySchedule for a given day index (0=Mon...6=Sun)
  DaySchedule dayByIndex(int index) {
    switch (index) {
      case 0: return monday;
      case 1: return tuesday;
      case 2: return wednesday;
      case 3: return thursday;
      case 4: return friday;
      case 5: return saturday;
      case 6: return sunday;
      default: return DaySchedule.defaultClosed;
    }
  }

  static const List<String> dayNames = [
    'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'
  ];

  static const List<String> dayKeys = [
    'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'
  ];

  WeeklyScheduleModel copyWithDay(int dayIndex, DaySchedule day) {
    return WeeklyScheduleModel(
      storeId: storeId,
      timezone: timezone,
      monday: dayIndex == 0 ? day : monday,
      tuesday: dayIndex == 1 ? day : tuesday,
      wednesday: dayIndex == 2 ? day : wednesday,
      thursday: dayIndex == 3 ? day : thursday,
      friday: dayIndex == 4 ? day : friday,
      saturday: dayIndex == 5 ? day : saturday,
      sunday: dayIndex == 6 ? day : sunday,
      updatedAt: updatedAt,
    );
  }
}
