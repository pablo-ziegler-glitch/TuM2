import 'package:flutter/material.dart';
import 'app_colors.dart';

abstract class AppTextStyles {
  // ── Headings ────────────────────────────────────────────────────
  static const headingLg = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.neutral900,
    height: 1.25,
  );

  static const headingMd = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.neutral900,
    height: 1.3,
  );

  static const headingSm = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.neutral900,
    height: 1.35,
  );

  // ── Body ────────────────────────────────────────────────────────
  static const bodyMd = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.neutral900,
    height: 1.5,
  );

  static const bodySm = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.neutral700,
    height: 1.5,
  );

  static const bodyXs = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.neutral600,
    height: 1.4,
  );

  // ── Labels ──────────────────────────────────────────────────────
  static const labelMd = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.neutral900,
    height: 1.4,
  );

  static const labelSm = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.neutral700,
    height: 1.4,
  );
}
