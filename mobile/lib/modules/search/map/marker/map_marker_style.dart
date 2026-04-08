import 'package:flutter/material.dart';

import '../../../../core/theme/app_brand.dart';
import 'map_marker_type.dart';
import 'map_marker_visual_type.dart';

abstract class MapMarkerStyle {
  static const double baseSizeDp = 40;
  static const double selectedSizeDp = 48;
  static const double guardiaSizeDp = 52;
  static const double selectedGuardiaSizeDp = 56;
  static const double selectedBorderWidthDp = 2;

  static const Color guardiaColor = AppBrand.badgeGuard;
  static const Color openColor = AppBrand.badgeOpen;
  static const Color open24hColor = AppBrand.badge24h;
  static const Color defaultColor = AppBrand.dark;
  static const Color closedColor = AppBrand.badgeClosed;
  static const Color onMarkerColor = AppBrand.onDark;
  static const Color selectedBorderColor = Colors.white;

  static double sizeForVisualType(MapMarkerVisualType visualType) {
    switch (visualType) {
      case MapMarkerVisualType.guardia:
        return guardiaSizeDp;
      case MapMarkerVisualType.selectedGuardia:
        return selectedGuardiaSizeDp;
      case MapMarkerVisualType.selectedOpen:
      case MapMarkerVisualType.selectedOpen24h:
      case MapMarkerVisualType.selectedDefaultState:
      case MapMarkerVisualType.selectedClosed:
        return selectedSizeDp;
      case MapMarkerVisualType.open:
      case MapMarkerVisualType.open24h:
      case MapMarkerVisualType.defaultState:
      case MapMarkerVisualType.closed:
        return baseSizeDp;
    }
  }

  static Color colorForBaseType(MapMarkerType baseType) {
    switch (baseType) {
      case MapMarkerType.guardia:
        return guardiaColor;
      case MapMarkerType.open:
        return openColor;
      case MapMarkerType.open24h:
        return open24hColor;
      case MapMarkerType.defaultState:
        return defaultColor;
      case MapMarkerType.closed:
        return closedColor;
    }
  }
}
