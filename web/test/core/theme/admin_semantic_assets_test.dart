import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tum2_admin/core/theme/admin_semantic_assets.dart';
import 'package:tum2_admin/core/theme/app_colors.dart';

void main() {
  group('AdminBadgeAssetResolver', () {
    test('mapea claim approved a badge activo mundialista', () {
      final token =
          AdminBadgeAssetResolver.resolve(AdminBadgeKey.claimApproved);
      expect(
          token.worldcupAssetPath, 'assets/worldcup/badges/badge_active.png');
      expect(token.foreground, AppColors.successFg);
    });

    test('mapea import hidden a badge hidden mundialista', () {
      final token = AdminBadgeAssetResolver.resolve(AdminBadgeKey.importHidden);
      expect(
          token.worldcupAssetPath, 'assets/worldcup/badges/badge_hidden.png');
      expect(token.background, AppColors.neutral200);
    });
  });

  group('AdminIconAssetResolver', () {
    test('brand usa asset 16/20/24 segun size', () {
      expect(
        AdminIconAssetResolver.worldcupAssetPath(AdminIconKey.brand, 16),
        'assets/worldcup/icons/16/icon_transparent_16.png',
      );
      expect(
        AdminIconAssetResolver.worldcupAssetPath(AdminIconKey.brand, 20),
        'assets/worldcup/icons/20/icon_transparent_20.png',
      );
      expect(
        AdminIconAssetResolver.worldcupAssetPath(AdminIconKey.brand, 24),
        'assets/worldcup/icons/24/icon_transparent_24.png',
      );
    });

    test('iconos semanticos no-brand siguen fallback material', () {
      expect(
        AdminIconAssetResolver.worldcupAssetPath(AdminIconKey.call, 20),
        isNull,
      );
      expect(AdminIconAssetResolver.fallbackIcon(AdminIconKey.call),
          Icons.call_outlined);
    });
  });
}
