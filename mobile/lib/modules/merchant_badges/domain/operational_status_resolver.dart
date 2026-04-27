import 'trust_badges.dart';

enum ResolvedOperationalStatusType {
  openNow,
  closedNow,
  closingSoon,
  openingSoon,
  temporaryClosed,
  vacation,
  delayed,
  unknown,
}

class ResolvedOperationalStatus {
  const ResolvedOperationalStatus({
    required this.type,
    required this.label,
    this.details,
  });

  final ResolvedOperationalStatusType type;
  final String label;
  final String? details;
}

class MerchantOperationalProjection {
  const MerchantOperationalProjection({
    required this.scheduleSummary,
    required this.nextOpenAt,
    required this.nextCloseAt,
    required this.nextTransitionAt,
    required this.hasOperationalSignal,
    required this.operationalSignalType,
    required this.operationalStatusLabel,
  });

  final MerchantScheduleSummary? scheduleSummary;
  final DateTime? nextOpenAt;
  final DateTime? nextCloseAt;
  final DateTime? nextTransitionAt;
  final bool hasOperationalSignal;
  final String operationalSignalType;
  final String? operationalStatusLabel;
}

ResolvedOperationalStatus resolveOperationalStatus({
  required DateTime now,
  required MerchantOperationalProjection merchant,
}) {
  final signalType = merchant.operationalSignalType.trim().toLowerCase();
  if (merchant.hasOperationalSignal && signalType == 'vacation') {
    return ResolvedOperationalStatus(
      type: ResolvedOperationalStatusType.vacation,
      label: merchant.operationalStatusLabel?.trim().isNotEmpty == true
          ? merchant.operationalStatusLabel!.trim()
          : 'De vacaciones',
    );
  }
  if (merchant.hasOperationalSignal && signalType == 'temporary_closure') {
    return ResolvedOperationalStatus(
      type: ResolvedOperationalStatusType.temporaryClosed,
      label: merchant.operationalStatusLabel?.trim().isNotEmpty == true
          ? merchant.operationalStatusLabel!.trim()
          : 'Cerrado temporalmente',
    );
  }
  if (merchant.hasOperationalSignal && signalType == 'delay') {
    return ResolvedOperationalStatus(
      type: ResolvedOperationalStatusType.delayed,
      label: merchant.operationalStatusLabel?.trim().isNotEmpty == true
          ? merchant.operationalStatusLabel!.trim()
          : 'Abre mas tarde',
    );
  }

  final summary = merchant.scheduleSummary;
  if (summary == null || !summary.hasSchedule) {
    return const ResolvedOperationalStatus(
      type: ResolvedOperationalStatusType.unknown,
      label: 'Sin datos de horario',
    );
  }

  final localNow = now.toLocal();
  final nowMinutes = localNow.hour * 60 + localNow.minute;
  final isOpen = summary.todayWindows.any((window) {
    final opens = window.opensAtLocalMinutes;
    final closes = window.closesAtLocalMinutes;
    if (closes > opens) {
      return nowMinutes >= opens && nowMinutes < closes;
    }
    return nowMinutes >= opens || nowMinutes < closes;
  });

  if (isOpen) {
    final closeDiff = _minutesUntil(localNow, merchant.nextCloseAt);
    if (closeDiff != null && closeDiff >= 0 && closeDiff <= 60) {
      return const ResolvedOperationalStatus(
        type: ResolvedOperationalStatusType.closingSoon,
        label: 'Cierra pronto',
      );
    }
    return const ResolvedOperationalStatus(
      type: ResolvedOperationalStatusType.openNow,
      label: 'Abierto ahora',
    );
  }

  final openDiff = _minutesUntil(localNow, merchant.nextOpenAt);
  if (openDiff != null && openDiff >= 0 && openDiff <= 60) {
    return const ResolvedOperationalStatus(
      type: ResolvedOperationalStatusType.openingSoon,
      label: 'Abre pronto',
    );
  }

  if (merchant.nextTransitionAt == null &&
      merchant.nextOpenAt == null &&
      merchant.nextCloseAt == null) {
    return const ResolvedOperationalStatus(
      type: ResolvedOperationalStatusType.unknown,
      label: 'Sin datos de horario',
    );
  }

  return const ResolvedOperationalStatus(
    type: ResolvedOperationalStatusType.closedNow,
    label: 'Cerrado',
  );
}

int? _minutesUntil(DateTime now, DateTime? value) {
  if (value == null) return null;
  return value.toLocal().difference(now).inMinutes;
}
