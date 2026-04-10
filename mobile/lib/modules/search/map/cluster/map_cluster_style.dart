import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
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
        return AppColors.tertiary500;
      case MapClusterPriority.open:
        return AppColors.secondary500;
      case MapClusterPriority.defaultState:
        return AppColors.primary500;
      case MapClusterPriority.closed:
        return AppColors.neutral700;
    }
  }
}
