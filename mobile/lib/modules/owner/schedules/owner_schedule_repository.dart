import 'package:cloud_firestore/cloud_firestore.dart';

import 'owner_schedule_models.dart';
import 'owner_schedule_utils.dart';

class OwnerScheduleRepository {
  OwnerScheduleRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<OwnerScheduleBundle> fetchSchedule(String merchantId) async {
    final weeklyRef = _firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('schedule_config')
        .doc('weekly');
    final exceptionsRef = _firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('schedule_exceptions')
        .orderBy('date')
        .limit(120);
    final closuresRef = _firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('schedule_exceptions_ranges')
        .orderBy('startDate')
        .limit(120);

    final results = await Future.wait([
      weeklyRef.get(),
      exceptionsRef.get(),
      closuresRef.get(),
    ]);

    final weeklySnap = results[0] as DocumentSnapshot<Map<String, dynamic>>;
    final exceptionsSnap = results[1] as QuerySnapshot<Map<String, dynamic>>;
    final closuresSnap = results[2] as QuerySnapshot<Map<String, dynamic>>;

    final weeklyData = weeklySnap.data();
    final weeklyMap =
        (weeklyData?['weeklySchedule'] as Map<String, dynamic>?) ?? {};

    final weekly = orderedDayKeys.map((day) {
      final dayMap = weeklyMap[day.key] as Map<String, dynamic>?;
      final mode = dayModeFromString((dayMap?['mode'] as String?) ?? 'closed');
      final blocksRaw = (dayMap?['blocks'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);

      final firstBlock =
          blocksRaw.isNotEmpty ? TimeBlock.fromMap(blocksRaw[0]) : null;
      final secondBlock =
          blocksRaw.length > 1 ? TimeBlock.fromMap(blocksRaw[1]) : null;

      return DayScheduleDraft(
        dayKey: day.key,
        dayLabel: day.label,
        mode: mode,
        firstOpen: firstBlock?.open,
        firstClose: firstBlock?.close,
        secondOpen: secondBlock?.open,
        secondClose: secondBlock?.close,
      );
    }).toList(growable: false);

    final exceptions = exceptionsSnap.docs.map((doc) {
      final data = doc.data();
      final type =
          exceptionTypeFromString((data['type'] as String?) ?? 'closed');
      final blocksRaw = (data['blocks'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
      final firstBlock =
          blocksRaw.isNotEmpty ? TimeBlock.fromMap(blocksRaw[0]) : null;
      final secondBlock =
          blocksRaw.length > 1 ? TimeBlock.fromMap(blocksRaw[1]) : null;
      final mode = blocksRaw.length > 1
          ? DayScheduleMode.split
          : (blocksRaw.isEmpty
              ? DayScheduleMode.closed
              : DayScheduleMode.continuous);
      return ScheduleExceptionDraft(
        id: doc.id,
        date: dateFromFirestore(data['date']) ?? DateTime.now(),
        type: type,
        mode: type == ScheduleExceptionType.closed
            ? DayScheduleMode.closed
            : mode,
        reason: data['reason'] as String?,
        firstOpen: firstBlock?.open,
        firstClose: firstBlock?.close,
        secondOpen: secondBlock?.open,
        secondClose: secondBlock?.close,
      );
    }).toList(growable: false)
      ..sort((a, b) => a.date.compareTo(b.date));

    final closures = closuresSnap.docs.map((doc) {
      final data = doc.data();
      final startDate = dateFromFirestore(data['startDate']) ?? DateTime.now();
      final endDate = dateFromFirestore(data['endDate']) ?? startDate;
      return TemporaryClosureDraft(
        id: doc.id,
        startDate: startDate,
        endDate: endDate,
        reason: data['reason'] as String?,
      );
    }).toList(growable: false)
      ..sort((a, b) => a.startDate.compareTo(b.startDate));

    return OwnerScheduleBundle(
      weekly: weekly,
      exceptions: exceptions,
      temporaryClosures: closures,
      version: (weeklyData?['version'] as int?) ?? 0,
      timezone: (weeklyData?['timezone'] as String?) ??
          'America/Argentina/Buenos_Aires',
    );
  }

  Future<void> saveSchedule({
    required String merchantId,
    required String uid,
    required OwnerScheduleSavePayload payload,
  }) async {
    final merchantRef = _firestore.collection('merchants').doc(merchantId);
    final batch = _firestore.batch();
    final weeklyRef = merchantRef.collection('schedule_config').doc('weekly');

    final weeklySchedule = <String, dynamic>{};
    for (final day in payload.weekly) {
      final blocks = validateDaySchedule(day) == null
          ? dayBlocks(day)
          : const <TimeBlock>[];
      weeklySchedule[day.dayKey] = {
        'mode': dayModeToString(day.mode),
        'blocks': blocks.map((item) => item.toMap()).toList(growable: false),
      };
    }

    batch.set(
        weeklyRef,
        {
          'merchantId': merchantId,
          'timezone': payload.timezone,
          'weeklySchedule': weeklySchedule,
          'version': payload.currentVersion + 1,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': uid,
          'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true));

    final exceptionsRef = merchantRef.collection('schedule_exceptions');
    for (final exception in payload.exceptions) {
      final blocks = validateException(exception) == null
          ? exceptionBlocks(exception)
          : const <TimeBlock>[];
      batch.set(
          exceptionsRef.doc(exception.id),
          {
            'date':
                '${exception.date.year.toString().padLeft(4, '0')}-${exception.date.month.toString().padLeft(2, '0')}-${exception.date.day.toString().padLeft(2, '0')}',
            'type': exceptionTypeToString(exception.type),
            'reason': exception.reason,
            'blocks':
                blocks.map((item) => item.toMap()).toList(growable: false),
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedBy': uid,
          },
          SetOptions(merge: true));
    }

    for (final id in payload.deletedExceptionIds) {
      batch.delete(exceptionsRef.doc(id));
    }

    final closuresRef = merchantRef.collection('schedule_exceptions_ranges');
    for (final closure in payload.temporaryClosures) {
      batch.set(
          closuresRef.doc(closure.id),
          {
            'startDate':
                '${closure.startDate.year.toString().padLeft(4, '0')}-${closure.startDate.month.toString().padLeft(2, '0')}-${closure.startDate.day.toString().padLeft(2, '0')}',
            'endDate':
                '${closure.endDate.year.toString().padLeft(4, '0')}-${closure.endDate.month.toString().padLeft(2, '0')}-${closure.endDate.day.toString().padLeft(2, '0')}',
            'type': 'temporary_closure',
            'reason': closure.reason,
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedBy': uid,
          },
          SetOptions(merge: true));
    }
    for (final id in payload.deletedClosureIds) {
      batch.delete(closuresRef.doc(id));
    }

    await batch.commit();
  }
}
