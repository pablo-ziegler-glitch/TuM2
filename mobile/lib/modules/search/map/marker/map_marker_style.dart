import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'map_marker_type.dart';
import 'map_marker_visual_type.dart';

abstract class MapMarkerStyle {
  static const double baseSizeDp = 40;
  static const double selectedSizeDp = 48;
  static const double guardiaSizeDp = 52;
  static const double selectedGuardiaSizeDp = 56;
  static const double selectedBorderWidthDp = 2;

  static const Color guardiaColor = AppColors.tertiary500;
  static const Color openColor = AppColors.secondary500;
  static const Color open24hColor = AppColors.primary500;
  static const Color defaultColor = AppColors.neutral900;
  static const Color closedColor = AppColors.neutral700;
  static const Color onMarkerColor = AppColors.surface;
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
