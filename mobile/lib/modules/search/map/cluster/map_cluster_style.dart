import 'package:flutter/material.dart';

import '../../../../core/theme/app_brand.dart';
import 'map_cluster_model.dart';

abstract class MapClusterStyle {
  static const double smallSizeDp = 40;
  static const double mediumSizeDp = 48;
  static const double largeSizeDp = 56;

  static double resolveSizeDp(int count) {
    if (count >= 50) return largeSizeDp;
    if (count >= 10) return mediumSizeDp;
    return smallSizeDp;
  }

  static Color resolveColor(MapClusterPriority priority) {
    switch (priority) {
      case MapClusterPriority.guardia:
        return AppBrand.badgeGuard;
      case MapClusterPriority.open:
        return AppBrand.badgeOpen;
      case MapClusterPriority.defaultState:
        return AppBrand.badge24h;
      case MapClusterPriority.closed:
        return AppBrand.badgeClosed;
    }
  }
}
