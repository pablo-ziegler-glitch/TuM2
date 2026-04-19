import 'package:flutter/material.dart';

import 'admin_theme_mode.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

enum AdminBadgeKey {
  claimDraft,
  claimSubmitted,
  claimUnderReview,
  claimNeedsMoreInfo,
  claimApproved,
  claimRejected,
  claimDuplicate,
  claimConflict,
  importDraft,
  importRunning,
  importValidated,
  importCompleted,
  importFailed,
  importPartial,
  importArchived,
  importRolledBack,
  importHidden,
}

class AdminBadgeVisualToken {
  const AdminBadgeVisualToken({
    required this.foreground,
    required this.background,
    this.worldcupAssetPath,
  });

  final Color foreground;
  final Color background;
  final String? worldcupAssetPath;
}

class AdminBadgeAssetResolver {
  const AdminBadgeAssetResolver._();

  static AdminBadgeVisualToken resolve(AdminBadgeKey key) {
    return switch (key) {
      AdminBadgeKey.claimDraft => const AdminBadgeVisualToken(
          foreground: AppColors.neutral700,
          background: AppColors.neutral100,
          worldcupAssetPath: 'assets/worldcup/badges/badge_draft.png',
        ),
      AdminBadgeKey.claimSubmitted => const AdminBadgeVisualToken(
          foreground: AppColors.primary700,
          background: AppColors.primary50,
          worldcupAssetPath: 'assets/worldcup/badges/badge_under_review.png',
        ),
      AdminBadgeKey.claimUnderReview => const AdminBadgeVisualToken(
          foreground: AppColors.primary600,
          background: AppColors.infoBg,
          worldcupAssetPath: 'assets/worldcup/badges/badge_under_review.png',
        ),
      AdminBadgeKey.claimNeedsMoreInfo => const AdminBadgeVisualToken(
          foreground: AppColors.warningFg,
          background: AppColors.warningBg,
          worldcupAssetPath: 'assets/worldcup/badges/badge_missing_info.png',
        ),
      AdminBadgeKey.claimApproved => const AdminBadgeVisualToken(
          foreground: AppColors.successFg,
          background: AppColors.successBg,
          worldcupAssetPath: 'assets/worldcup/badges/badge_active.png',
        ),
      AdminBadgeKey.claimRejected => const AdminBadgeVisualToken(
          foreground: AppColors.errorFg,
          background: AppColors.errorBg,
          worldcupAssetPath: 'assets/worldcup/badges/badge_suppressed.png',
        ),
      AdminBadgeKey.claimDuplicate => const AdminBadgeVisualToken(
          foreground: AppColors.warningFg,
          background: AppColors.warningBg,
          worldcupAssetPath: 'assets/worldcup/badges/badge_priority_sheet.png',
        ),
      AdminBadgeKey.claimConflict => const AdminBadgeVisualToken(
          foreground: AppColors.errorFg,
          background: AppColors.errorBg,
          worldcupAssetPath:
              'assets/worldcup/badges/badge_operational_change.png',
        ),
      AdminBadgeKey.importDraft => const AdminBadgeVisualToken(
          foreground: AppColors.neutral500,
          background: AppColors.neutral100,
          worldcupAssetPath: 'assets/worldcup/badges/badge_draft.png',
        ),
      AdminBadgeKey.importRunning => const AdminBadgeVisualToken(
          foreground: AppColors.primary500,
          background: AppColors.primary50,
          worldcupAssetPath: 'assets/worldcup/badges/badge_under_review.png',
        ),
      AdminBadgeKey.importValidated => const AdminBadgeVisualToken(
          foreground: AppColors.secondary500,
          background: AppColors.neutral100,
          worldcupAssetPath: 'assets/worldcup/badges/badge_visible.png',
        ),
      AdminBadgeKey.importCompleted => const AdminBadgeVisualToken(
          foreground: AppColors.successFg,
          background: AppColors.successBg,
          worldcupAssetPath: 'assets/worldcup/badges/badge_active.png',
        ),
      AdminBadgeKey.importFailed => const AdminBadgeVisualToken(
          foreground: AppColors.errorFg,
          background: AppColors.errorBg,
          worldcupAssetPath:
              'assets/worldcup/badges/badge_temporary_closed.png',
        ),
      AdminBadgeKey.importPartial => const AdminBadgeVisualToken(
          foreground: AppColors.warningFg,
          background: AppColors.warningBg,
          worldcupAssetPath: 'assets/worldcup/badges/badge_priority_sheet.png',
        ),
      AdminBadgeKey.importArchived => const AdminBadgeVisualToken(
          foreground: AppColors.neutral400,
          background: AppColors.neutral100,
          worldcupAssetPath: 'assets/worldcup/badges/badge_archived.png',
        ),
      AdminBadgeKey.importRolledBack => const AdminBadgeVisualToken(
          foreground: AppColors.warningFg,
          background: AppColors.warningBg,
          worldcupAssetPath:
              'assets/worldcup/badges/badge_operational_change.png',
        ),
      AdminBadgeKey.importHidden => const AdminBadgeVisualToken(
          foreground: AppColors.neutral500,
          background: AppColors.neutral200,
          worldcupAssetPath: 'assets/worldcup/badges/badge_hidden.png',
        ),
    };
  }
}

enum AdminIconKey {
  brand,
  call,
  directions,
  share,
  save,
  report,
  claimMerchant,
  verified,
  recent,
  pending,
  pharmacy,
  kiosk,
  grocery,
  veterinary,
  fastFood,
  rotisserie,
  tireShop,
}

class AdminIconAssetResolver {
  const AdminIconAssetResolver._();

  static IconData fallbackIcon(AdminIconKey key) {
    return switch (key) {
      AdminIconKey.brand => Icons.palette_outlined,
      AdminIconKey.call => Icons.call_outlined,
      AdminIconKey.directions => Icons.directions_outlined,
      AdminIconKey.share => Icons.share_outlined,
      AdminIconKey.save => Icons.bookmark_outline,
      AdminIconKey.report => Icons.flag_outlined,
      AdminIconKey.claimMerchant => Icons.fact_check_outlined,
      AdminIconKey.verified => Icons.verified_outlined,
      AdminIconKey.recent => Icons.history,
      AdminIconKey.pending => Icons.hourglass_empty,
      AdminIconKey.pharmacy => Icons.local_pharmacy_outlined,
      AdminIconKey.kiosk => Icons.storefront_outlined,
      AdminIconKey.grocery => Icons.shopping_basket_outlined,
      AdminIconKey.veterinary => Icons.pets_outlined,
      AdminIconKey.fastFood => Icons.lunch_dining_outlined,
      AdminIconKey.rotisserie => Icons.restaurant_outlined,
      AdminIconKey.tireShop => Icons.tire_repair_outlined,
    };
  }

  static String? worldcupAssetPath(AdminIconKey key, int size) {
    if (key != AdminIconKey.brand) return null;
    final normalizedSize = switch (size) {
      <= 16 => 16,
      <= 20 => 20,
      _ => 24,
    };
    return 'assets/worldcup/icons/$normalizedSize/icon_transparent_${normalizedSize}.png';
  }
}

class AdminSemanticBadge extends StatelessWidget {
  const AdminSemanticBadge({
    super.key,
    required this.badgeKey,
    required this.label,
    this.compact = false,
  });

  final AdminBadgeKey badgeKey;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = AdminThemeScope.maybeOf(context);
    final token = AdminBadgeAssetResolver.resolve(badgeKey);
    final worldcupAssetPath = token.worldcupAssetPath;
    if ((theme?.isWorldcup ?? false) && worldcupAssetPath != null) {
      return Image.asset(
        worldcupAssetPath,
        height: compact ? 20 : 24,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      );
    }
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: token.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTextStyles.bodyXs.copyWith(
          color: token.foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class AdminSemanticIcon extends StatelessWidget {
  const AdminSemanticIcon({
    super.key,
    required this.iconKey,
    this.size = 20,
    this.color,
    this.fallbackOverride,
  });

  final AdminIconKey iconKey;
  final double size;
  final Color? color;
  final IconData? fallbackOverride;

  @override
  Widget build(BuildContext context) {
    final theme = AdminThemeScope.maybeOf(context);
    final worldcupAssetPath = AdminIconAssetResolver.worldcupAssetPath(
      iconKey,
      size.round(),
    );
    if ((theme?.isWorldcup ?? false) && worldcupAssetPath != null) {
      return Image.asset(
        worldcupAssetPath,
        width: size,
        height: size,
        fit: BoxFit.contain,
      );
    }
    return Icon(
      fallbackOverride ?? AdminIconAssetResolver.fallbackIcon(iconKey),
      size: size,
      color: color,
    );
  }
}
