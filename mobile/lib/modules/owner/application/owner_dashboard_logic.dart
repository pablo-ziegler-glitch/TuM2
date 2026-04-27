import '../models/operational_signals.dart';
import '../models/owner_merchant_summary.dart';
import '../../../core/router/app_routes.dart';

enum OwnerDashboardAlertSeverity {
  critical,
  warning,
  info,
}

class OwnerDashboardAlert {
  const OwnerDashboardAlert({
    required this.id,
    required this.title,
    required this.message,
    required this.severity,
    this.ctaLabel,
    this.ctaRoute,
  });

  final String id;
  final String title;
  final String message;
  final OwnerDashboardAlertSeverity severity;
  final String? ctaLabel;
  final String? ctaRoute;
}

class OwnerOperationalSummary {
  const OwnerOperationalSummary({
    required this.title,
    required this.subtitle,
    required this.isUnknown,
    required this.isSpecialCondition,
  });

  final String title;
  final String subtitle;
  final bool isUnknown;
  final bool isSpecialCondition;
}

OwnerOperationalSummary resolveOperationalSummary({
  required OwnerMerchantSummary merchant,
  required OwnerOperationalSignal? signal,
}) {
  if (merchant.status == 'archived') {
    return const OwnerOperationalSummary(
      title: 'Comercio archivado',
      subtitle: 'No está disponible para los vecinos.',
      isUnknown: false,
      isSpecialCondition: true,
    );
  }

  if (merchant.status == 'inactive') {
    return const OwnerOperationalSummary(
      title: 'Comercio inactivo',
      subtitle: 'Activá tu comercio para volver a mostrarlo.',
      isUnknown: false,
      isSpecialCondition: true,
    );
  }

  final activeSignal = signal?.hasActiveSignal == true ? signal! : null;
  if (activeSignal != null) {
    if (activeSignal.forceClosed) {
      final detail = (activeSignal.message ?? '').trim();
      return OwnerOperationalSummary(
        title: 'Aviso activo: ${activeSignal.signalType.publicLabel}',
        subtitle: detail.isEmpty
            ? 'Fuente: aviso activo. Los vecinos ven este aviso en tu comercio.'
            : 'Fuente: aviso activo. $detail',
        isUnknown: false,
        isSpecialCondition: true,
      );
    }
    if (activeSignal.signalType == OperationalSignalType.delay) {
      final detail = (activeSignal.message ?? '').trim();
      return OwnerOperationalSummary(
        title: 'Aviso activo: Abre más tarde',
        subtitle: detail.isEmpty
            ? 'Fuente: aviso activo. Informaste una demora para hoy.'
            : 'Fuente: aviso activo. $detail',
        isUnknown: false,
        isSpecialCondition: true,
      );
    }
  }

  if (signal?.isOpenNow == true) {
    final detail = (signal?.todayScheduleLabel ?? '').trim();
    return OwnerOperationalSummary(
      title: 'Abierto ahora',
      subtitle: detail.isEmpty
          ? 'Fuente: horario habitual. Los vecinos ven tu comercio como abierto.'
          : 'Fuente: horario habitual. $detail',
      isUnknown: false,
      isSpecialCondition: false,
    );
  }

  if (signal?.isOpenNow == false) {
    final detail = (signal?.todayScheduleLabel ?? '').trim();
    return OwnerOperationalSummary(
      title: 'Cerrado ahora',
      subtitle: detail.isEmpty
          ? 'Fuente: horario habitual. En este momento figura como cerrado.'
          : 'Fuente: horario habitual. $detail',
      isUnknown: false,
      isSpecialCondition: false,
    );
  }

  return const OwnerOperationalSummary(
    title: 'Estado no disponible',
    subtitle:
        'Fuente: horarios no disponibles. No pudimos confirmar si está abierto o cerrado ahora.',
    isUnknown: true,
    isSpecialCondition: false,
  );
}

List<OwnerDashboardAlert> buildOwnerDashboardAlerts({
  required OwnerMerchantSummary merchant,
  required bool ownerPending,
  required OwnerOperationalSignal? signal,
}) {
  final alerts = <({int priority, OwnerDashboardAlert alert})>[];

  if (ownerPending) {
    alerts.add((
      priority: 0,
      alert: const OwnerDashboardAlert(
        id: 'owner_pending',
        title: 'Tu validación como dueño sigue pendiente',
        message: 'Todavía no podés operar cambios sobre el comercio.',
        severity: OwnerDashboardAlertSeverity.critical,
      )
    ));
  }

  switch (merchant.visibilityStatus) {
    case 'suppressed':
      alerts.add((
        priority: 1,
        alert: const OwnerDashboardAlert(
          id: 'visibility_suppressed',
          title: 'Tu comercio está suprimido',
          message: 'Ahora no aparece públicamente en Tu zona.',
          severity: OwnerDashboardAlertSeverity.critical,
        )
      ));
      break;
    case 'hidden':
      alerts.add((
        priority: 2,
        alert: const OwnerDashboardAlert(
          id: 'visibility_hidden',
          title: 'Tu comercio está oculto',
          message: 'Completá datos para volver a aparecer ante vecinos.',
          severity: OwnerDashboardAlertSeverity.warning,
          ctaLabel: 'Revisar perfil',
          ctaRoute: AppRoutes.ownerEdit,
        )
      ));
      break;
    case 'review_pending':
      alerts.add((
        priority: 3,
        alert: const OwnerDashboardAlert(
          id: 'visibility_review_pending',
          title: 'Tu comercio está en revisión',
          message: 'Estamos validando la información antes de publicarla.',
          severity: OwnerDashboardAlertSeverity.info,
        )
      ));
      break;
  }

  if (merchant.status == 'inactive' || merchant.status == 'archived') {
    alerts.add((
      priority: 4,
      alert: OwnerDashboardAlert(
        id: 'status_${merchant.status}',
        title: merchant.status == 'archived'
            ? 'Tu comercio está archivado'
            : 'Tu comercio está inactivo',
        message: 'No se muestra con normalidad hasta actualizar su estado.',
        severity: OwnerDashboardAlertSeverity.warning,
      )
    ));
  }

  if (!merchant.hasSchedules && merchant.status == 'active') {
    alerts.add((
      priority: 5,
      alert: const OwnerDashboardAlert(
        id: 'missing_schedules',
        title: 'Configurá tus horarios',
        message: 'Sin horarios no podemos informar apertura en tiempo real.',
        severity: OwnerDashboardAlertSeverity.warning,
        ctaLabel: 'Editar horarios',
        ctaRoute: AppRoutes.ownerSchedules,
      )
    ));
  }

  if (!merchant.hasProducts) {
    alerts.add((
      priority: 6,
      alert: const OwnerDashboardAlert(
        id: 'missing_products',
        title: 'Tu catálogo está vacío',
        message: 'Sumá productos para que los vecinos te encuentren mejor.',
        severity: OwnerDashboardAlertSeverity.info,
        ctaLabel: 'Gestionar productos',
        ctaRoute: AppRoutes.ownerProducts,
      )
    ));
  }

  if (!merchant.isDataComplete ||
      merchant.name.trim().isEmpty ||
      merchant.zoneId.trim().isEmpty) {
    alerts.add((
      priority: 7,
      alert: const OwnerDashboardAlert(
        id: 'incomplete_profile',
        title: 'Completá los datos del comercio',
        message: 'Un perfil completo mejora visibilidad y confianza.',
        severity: OwnerDashboardAlertSeverity.warning,
        ctaLabel: 'Revisar perfil',
        ctaRoute: AppRoutes.ownerEdit,
      )
    ));
  }

  if (signal == null || signal.isOpenNow == null) {
    alerts.add((
      priority: 8,
      alert: const OwnerDashboardAlert(
        id: 'open_state_unknown',
        title: 'No pudimos determinar el estado actual',
        message: 'Revisá Avisos de hoy y horarios para mantenerlo actualizado.',
        severity: OwnerDashboardAlertSeverity.info,
      )
    ));
  }

  alerts.sort((a, b) => a.priority.compareTo(b.priority));
  return alerts.map((entry) => entry.alert).toList(growable: false);
}
