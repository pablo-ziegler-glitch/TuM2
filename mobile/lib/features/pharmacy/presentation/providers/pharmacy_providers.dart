import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/duty_schedule_repository.dart';
import '../../domain/duty_schedule_model.dart';

final dutyScheduleRepositoryProvider = Provider<DutyScheduleRepository>((ref) {
  return DutyScheduleRepository();
});

final todayDutySchedulesProvider =
    StreamProvider<List<DutyScheduleModel>>((ref) {
  return ref.watch(dutyScheduleRepositoryProvider).watchTodayDutySchedules();
});
