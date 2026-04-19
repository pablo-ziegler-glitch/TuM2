import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/merchant_icon_resolver.dart';
import '../domain/merchant_visual_models.dart';

class MerchantStatusBadge extends StatelessWidget {
  const MerchantStatusBadge({
    super.key,
    required this.badge,
    this.compact = false,
    this.disabled = false,
  });

  final MerchantBadgeKey badge;
  final bool compact;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final style = MerchantBadgeStyleResolver.resolve(
      badge: badge,
      darkMode: Theme.of(context).brightness == Brightness.dark,
      disabled: disabled,
    );
    final icon = MerchantIconResolver.forBadge(badge);
    final label = MerchantBadgeLabelResolver.label(
      badge: badge,
      compact: compact,
    );

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon.icon, size: compact ? 12 : 14, color: style.foreground),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: style.foreground,
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class MerchantConfidenceBadge extends StatelessWidget {
  const MerchantConfidenceBadge({
    super.key,
    required this.badge,
  });

  final MerchantBadgeKey badge;

  @override
  Widget build(BuildContext context) {
    final style = MerchantBadgeStyleResolver.resolve(
      badge: badge,
      darkMode: Theme.of(context).brightness == Brightness.dark,
      disabled: false,
    );
    final icon = MerchantIconResolver.forBadge(badge);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon.icon, size: 12, color: style.foreground),
          const SizedBox(width: 4),
          Text(
            MerchantBadgeLabelResolver.label(badge: badge, compact: true),
            style: TextStyle(
              color: style.foreground,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class MerchantRubricLabel extends StatelessWidget {
  const MerchantRubricLabel({
    super.key,
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: AppColors.neutral700,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class MerchantClaimStatusBadge extends StatelessWidget {
  const MerchantClaimStatusBadge({
    super.key,
    required this.badge,
  });

  final MerchantBadgeKey badge;

  @override
  Widget build(BuildContext context) {
    return MerchantStatusBadge(
      badge: badge,
      compact: false,
      disabled: false,
    );
  }
}

class MerchantBadgeStyle {
  const MerchantBadgeStyle({
    required this.background,
    required this.foreground,
  });

  final Color background;
  final Color foreground;
}

class MerchantBadgeStyleResolver {
  const MerchantBadgeStyleResolver._();

  static MerchantBadgeStyle resolve({
    required MerchantBadgeKey badge,
    required bool darkMode,
    required bool disabled,
  }) {
    if (disabled) {
      return const MerchantBadgeStyle(
        background: Color(0xFFE5E7EB),
        foreground: Color(0xFF6B7280),
      );
    }

    if (badge == MerchantBadgeKey.onDuty ||
        badge == MerchantBadgeKey.guardVerification ||
        badge == MerchantBadgeKey.operationalChange) {
      return const MerchantBadgeStyle(
        background: Color(0xFFE53935),
        foreground: Color(0xFFFFFFFF),
      );
    }
    if (badge == MerchantBadgeKey.alwaysOpen24h) {
      return const MerchantBadgeStyle(
        background: Color(0xFF0E5BD8),
        foreground: Color(0xFFFFFFFF),
      );
    }
    if (badge == MerchantBadgeKey.openNow ||
        badge == MerchantBadgeKey.openCompact) {
      return const MerchantBadgeStyle(
        background: Color(0xFF0F766E),
        foreground: Color(0xFFFFFFFF),
      );
    }

    if (badge == MerchantBadgeKey.closedForVacation ||
        badge == MerchantBadgeKey.temporaryClosure ||
        badge == MerchantBadgeKey.closed ||
        badge == MerchantBadgeKey.opensLater ||
        badge == MerchantBadgeKey.noInfo ||
        badge == MerchantBadgeKey.referentialSchedule) {
      return MerchantBadgeStyle(
        background:
            darkMode ? const Color(0xFF1F2937) : const Color(0xFFF5F5F5),
        foreground:
            darkMode ? const Color(0xFFE5E7EB) : const Color(0xFF111827),
      );
    }

    return MerchantBadgeStyle(
      background: darkMode ? const Color(0xFF1E3A8A) : const Color(0xFFE5EEF9),
      foreground: darkMode ? const Color(0xFFDBEAFE) : const Color(0xFF1E3A8A),
    );
  }
}

class MerchantBadgeLabelResolver {
  const MerchantBadgeLabelResolver._();

  static String label({
    required MerchantBadgeKey badge,
    required bool compact,
  }) {
    switch (badge) {
      case MerchantBadgeKey.closedForVacation:
        return 'Cerrado por vacaciones';
      case MerchantBadgeKey.temporaryClosure:
        return 'Cerrado temporalmente';
      case MerchantBadgeKey.onDuty:
        return compact ? 'De turno' : 'Farmacia de turno';
      case MerchantBadgeKey.guardVerification:
        return 'Guardia en verificación';
      case MerchantBadgeKey.operationalChange:
        return 'Cambio operativo';
      case MerchantBadgeKey.opensLater:
        return 'Abre más tarde';
      case MerchantBadgeKey.openNow:
        return compact ? 'Abierto' : 'Abierto ahora';
      case MerchantBadgeKey.openCompact:
        return 'Abierto';
      case MerchantBadgeKey.closed:
        return 'Cerrado';
      case MerchantBadgeKey.alwaysOpen24h:
        return '24 hs';
      case MerchantBadgeKey.referentialSchedule:
        return 'Horario referencial';
      case MerchantBadgeKey.noInfo:
        return 'Sin información';
      case MerchantBadgeKey.confidenceVerified:
        return 'Verificado';
      case MerchantBadgeKey.confidenceValidated:
        return 'Validado';
      case MerchantBadgeKey.confidenceClaimed:
        return 'Reclamado';
      case MerchantBadgeKey.confidenceCommunity:
        return 'Comunidad';
      case MerchantBadgeKey.confidenceReferential:
        return 'Referencial';
      case MerchantBadgeKey.confidenceUnverified:
        return 'Sin verificar';
      case MerchantBadgeKey.ownerVisible:
        return 'Visible';
      case MerchantBadgeKey.ownerReviewPending:
        return 'En revisión';
      case MerchantBadgeKey.ownerSuppressed:
        return 'Suprimido';
      case MerchantBadgeKey.ownerHidden:
        return 'Oculto';
      case MerchantBadgeKey.ownerActive:
        return 'Activo';
      case MerchantBadgeKey.ownerDraft:
        return 'Borrador';
      case MerchantBadgeKey.ownerInactive:
        return 'Inactivo';
      case MerchantBadgeKey.ownerArchived:
        return 'Archivado';
      case MerchantBadgeKey.claimDraft:
        return 'Borrador';
      case MerchantBadgeKey.claimSubmitted:
        return 'Enviado';
      case MerchantBadgeKey.claimUnderReview:
        return 'En revisión';
      case MerchantBadgeKey.claimNeedsMoreInfo:
        return 'Falta información';
      case MerchantBadgeKey.claimApproved:
        return 'Aprobado';
      case MerchantBadgeKey.claimRejected:
        return 'Rechazado';
      case MerchantBadgeKey.claimDuplicate:
        return 'Duplicado';
      case MerchantBadgeKey.claimConflict:
        return 'Conflicto';
    }
  }
}
