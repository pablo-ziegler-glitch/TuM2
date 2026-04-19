import 'package:flutter/material.dart';

import 'merchant_visual_models.dart';

class MerchantIconResolution {
  const MerchantIconResolution({
    required this.icon,
    required this.assetName,
  });

  final IconData icon;
  final String assetName;
}

class MerchantIconResolver {
  const MerchantIconResolver._();

  static MerchantIconResolution forBadge(MerchantBadgeKey badge) {
    switch (badge) {
      case MerchantBadgeKey.onDuty:
        return const MerchantIconResolution(
          icon: Icons.local_hospital,
          assetName: 'icon_de_turno_24.svg',
        );
      case MerchantBadgeKey.guardVerification:
        return const MerchantIconResolution(
          icon: Icons.verified_outlined,
          assetName: 'icon_guardia_en_verificacion_24.svg',
        );
      case MerchantBadgeKey.operationalChange:
        return const MerchantIconResolution(
          icon: Icons.sync_problem,
          assetName: 'icon_cambio_operativo_24.svg',
        );
      case MerchantBadgeKey.openNow:
      case MerchantBadgeKey.openCompact:
        return const MerchantIconResolution(
          icon: Icons.check_circle_outline,
          assetName: 'icon_abierto_24.svg',
        );
      case MerchantBadgeKey.closed:
      case MerchantBadgeKey.temporaryClosure:
      case MerchantBadgeKey.closedForVacation:
        return const MerchantIconResolution(
          icon: Icons.cancel_outlined,
          assetName: 'icon_cerrado_24.svg',
        );
      case MerchantBadgeKey.referentialSchedule:
      case MerchantBadgeKey.noInfo:
        return const MerchantIconResolution(
          icon: Icons.schedule_outlined,
          assetName: 'icon_horario_24.svg',
        );
      case MerchantBadgeKey.opensLater:
        return const MerchantIconResolution(
          icon: Icons.hourglass_top,
          assetName: 'icon_abre_mas_tarde_24.svg',
        );
      case MerchantBadgeKey.alwaysOpen24h:
        return const MerchantIconResolution(
          icon: Icons.brightness_2_outlined,
          assetName: 'icon_24hs_24.svg',
        );
      case MerchantBadgeKey.confidenceVerified:
        return const MerchantIconResolution(
          icon: Icons.verified,
          assetName: 'icon_verificado_24.svg',
        );
      case MerchantBadgeKey.confidenceValidated:
        return const MerchantIconResolution(
          icon: Icons.fact_check_outlined,
          assetName: 'icon_por_confirmar_24.svg',
        );
      case MerchantBadgeKey.confidenceClaimed:
        return const MerchantIconResolution(
          icon: Icons.verified_user_outlined,
          assetName: 'icon_reclamado_24.svg',
        );
      case MerchantBadgeKey.confidenceCommunity:
        return const MerchantIconResolution(
          icon: Icons.groups_outlined,
          assetName: 'icon_reciente_24.svg',
        );
      case MerchantBadgeKey.confidenceReferential:
      case MerchantBadgeKey.confidenceUnverified:
        return const MerchantIconResolution(
          icon: Icons.info_outline,
          assetName: 'icon_por_confirmar_24.svg',
        );
      default:
        return const MerchantIconResolution(
          icon: Icons.label_outline,
          assetName: 'icon_estado_24.svg',
        );
    }
  }
}
