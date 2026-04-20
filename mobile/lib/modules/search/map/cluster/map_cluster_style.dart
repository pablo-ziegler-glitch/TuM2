import 'package:flutter/material.dart';

import '../../../merchant_badges/domain/merchant_cluster_style_resolver.dart';
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
    return MerchantClusterStyleResolver.colorForPriority(priority);
  }
}
