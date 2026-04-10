import 'package:flutter_test/flutter_test.dart';
import 'package:tum2/modules/owner/schedules/owner_schedule_models.dart';
import 'package:tum2/modules/owner/schedules/owner_schedule_utils.dart';

void main() {
  group('validateDaySchedule', () {
    test('acepta horario corrido válido', () {
      final day = const DayScheduleDraft(
        dayKey: 'monday',
        dayLabel: 'Lunes',
        mode: DayScheduleMode.continuous,
        firstOpen: '08:00',
        firstClose: '20:00',
      );

      expect(validateDaySchedule(day), isNull);
    });

    test('rechaza horario corrido invertido', () {
      final day = const DayScheduleDraft(
        dayKey: 'monday',
        dayLabel: 'Lunes',
        mode: DayScheduleMode.continuous,
        firstOpen: '20:00',
        firstClose: '08:00',
      );

      expect(validateDaySchedule(day), isNotNull);
    });

    test('rechaza split con solapamiento', () {
      final day = DayScheduleDraft(
        dayKey: 'monday',
        dayLabel: 'Lunes',
        mode: DayScheduleMode.split,
        firstOpen: '08:00',
        firstClose: '12:00',
        secondOpen: '11:30',
        secondClose: '20:00',
      );

      expect(validateDaySchedule(day), contains('superponen'));
    });
  });

  group('validateTemporaryClosure', () {
    test('rechaza rango invertido', () {
      final closure = TemporaryClosureDraft(
        id: 'range',
        startDate: DateTime(2026, 7, 15),
        endDate: DateTime(2026, 7, 10),
      );

      expect(validateTemporaryClosure(closure), isNotNull);
    });
  });
}
