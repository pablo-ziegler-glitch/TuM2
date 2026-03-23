import 'package:flutter/material.dart';

/// TuM2 design tokens — colores del sistema de diseño
/// Fuente: design/tokens.json (TuM2-0010)
abstract class AppColors {
  // ── Primary (azul) ──────────────────────────────────────────────
  static const primary50  = Color(0xFFEBF1FD);
  static const primary100 = Color(0xFFC3D6F9);
  static const primary200 = Color(0xFF9BBBF5);
  static const primary300 = Color(0xFF73A0F1);
  static const primary400 = Color(0xFF4B85ED);
  static const primary500 = Color(0xFF0E5BD8); // CTA principal
  static const primary600 = Color(0xFF0B4DB8);
  static const primary700 = Color(0xFF083E98);
  static const primary800 = Color(0xFF052F78);
  static const primary900 = Color(0xFF031F58);

  // ── Secondary (verde/teal) ───────────────────────────────────────
  static const secondary50  = Color(0xFFE6F5F4);
  static const secondary100 = Color(0xFFB3DDD9);
  static const secondary200 = Color(0xFF80C5C0);
  static const secondary300 = Color(0xFF4DADA7);
  static const secondary400 = Color(0xFF1A958E);
  static const secondary500 = Color(0xFF0F766E); // Completado, éxito
  static const secondary600 = Color(0xFF0C635C);
  static const secondary700 = Color(0xFF09504A);
  static const secondary800 = Color(0xFF063D38);
  static const secondary900 = Color(0xFF032A26);

  // ── Tertiary (naranja) ───────────────────────────────────────────
  static const tertiary50  = Color(0xFFFFF3EB);
  static const tertiary100 = Color(0xFFFFD9BE);
  static const tertiary200 = Color(0xFFFFBF91);
  static const tertiary300 = Color(0xFFFFA564);
  static const tertiary400 = Color(0xFFFF9655);
  static const tertiary500 = Color(0xFFFF8D46); // Warning / badge
  static const tertiary600 = Color(0xFFE07C3C);
  static const tertiary700 = Color(0xFFC06B32);
  static const tertiary800 = Color(0xFFA05A28);
  static const tertiary900 = Color(0xFF80491E);

  // ── Neutral (beige/gris) ─────────────────────────────────────────
  static const neutral50  = Color(0xFFF9F8F6);
  static const neutral100 = Color(0xFFEDECEA);
  static const neutral200 = Color(0xFFE1DFDB);
  static const neutral300 = Color(0xFFD5D3CB);
  static const neutral400 = Color(0xFFC9C7B8);
  static const neutral500 = Color(0xFFB0AE9F); // Texto deshabilitado
  static const neutral600 = Color(0xFF979586);
  static const neutral700 = Color(0xFF7E7C6D);
  static const neutral800 = Color(0xFF656354);
  static const neutral900 = Color(0xFF2D2D26); // Texto principal

  // ── Semánticos ───────────────────────────────────────────────────
  static const errorFg  = Color(0xFFDC2626);
  static const errorBg  = Color(0xFFFEF2F2);
  static const successFg = secondary500;
  static const successBg = secondary50;
  static const warningFg = tertiary500;
  static const warningBg = tertiary50;
  static const infoBg    = primary50;

  // ── Fondo de app ────────────────────────────────────────────────
  static const scaffoldBg = Color(0xFFF2F2EE);
  static const surface    = Color(0xFFFFFFFF);

  // ── Admin sidebar ────────────────────────────────────────────────
  static const sidebarBg       = neutral900;
  static const sidebarText     = Color(0xFFB0AE9F);  // neutral500
  static const sidebarActive   = surface;
  static const sidebarActiveBg = primary500;
}
