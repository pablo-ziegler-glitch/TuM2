import 'package:flutter/material.dart';

/// TuM2 brand color palette
/// Filosofía: Cercano, útil, territorial, claro y confiable.
class TuM2Colors {
  TuM2Colors._();

  // Primary — azul territorial
  static const Color primary = Color(0xFF1A6BFF);
  static const Color primaryLight = Color(0xFF5E96FF);
  static const Color primaryDark = Color(0xFF0047CC);

  // Secondary — naranja cálido (comercio, vida barrial)
  static const Color secondary = Color(0xFFFF6B35);
  static const Color secondaryLight = Color(0xFFFF9866);
  static const Color secondaryDark = Color(0xFFCC4A1A);

  // Neutrals
  static const Color surface = Color(0xFFF8F9FA);
  static const Color surfaceVariant = Color(0xFFEFF1F3);
  static const Color background = Color(0xFFFFFFFF);
  static const Color outline = Color(0xFFDDE1E7);

  // Text
  static const Color onBackground = Color(0xFF111827);
  static const Color onSurface = Color(0xFF374151);
  static const Color onSurfaceVariant = Color(0xFF6B7280);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // Semantic
  static const Color success = Color(0xFF16A34A);
  static const Color successLight = Color(0xFFDCFCE7);
  static const Color warning = Color(0xFFD97706);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFDC2626);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF0EA5E9);
  static const Color infoLight = Color(0xFFE0F2FE);

  // Status badges
  static const Color openGreen = Color(0xFF16A34A);
  static const Color closedRed = Color(0xFFDC2626);
  static const Color dutyBlue = Color(0xFF1A6BFF);
  static const Color lateNightPurple = Color(0xFF7C3AED);
}

/// TuM2 text styles
class TuM2TextStyles {
  TuM2TextStyles._();

  static const String _fontFamily = 'Inter';

  static const TextStyle displayLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.25,
  );

  static const TextStyle headlineLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.25,
    height: 1.3,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.35,
  );

  static const TextStyle titleLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  static const TextStyle titleMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.5,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const TextStyle labelLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  );

  static const TextStyle labelSmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
  );
}

/// Light theme for TuM2
final ThemeData tuM2LightTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: TuM2Colors.primary,
    brightness: Brightness.light,
    primary: TuM2Colors.primary,
    onPrimary: TuM2Colors.onPrimary,
    secondary: TuM2Colors.secondary,
    surface: TuM2Colors.surface,
    error: TuM2Colors.error,
  ),
  fontFamily: 'Inter',
  scaffoldBackgroundColor: TuM2Colors.background,
  appBarTheme: const AppBarTheme(
    backgroundColor: TuM2Colors.background,
    foregroundColor: TuM2Colors.onBackground,
    elevation: 0,
    scrolledUnderElevation: 1,
    titleTextStyle: TuM2TextStyles.titleLarge,
    centerTitle: false,
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: TuM2Colors.background,
    selectedItemColor: TuM2Colors.primary,
    unselectedItemColor: TuM2Colors.onSurfaceVariant,
    type: BottomNavigationBarType.fixed,
    elevation: 8,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: TuM2Colors.primary,
      foregroundColor: TuM2Colors.onPrimary,
      minimumSize: const Size(double.infinity, 52),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      textStyle: TuM2TextStyles.labelLarge,
      elevation: 0,
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: TuM2Colors.primary,
      minimumSize: const Size(double.infinity, 52),
      side: const BorderSide(color: TuM2Colors.primary, width: 1.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      textStyle: TuM2TextStyles.labelLarge,
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: TuM2Colors.surfaceVariant,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: TuM2Colors.outline, width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: TuM2Colors.primary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: TuM2Colors.error, width: 1),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  ),
  cardTheme: CardTheme(
    color: TuM2Colors.background,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: TuM2Colors.outline, width: 1),
    ),
    margin: EdgeInsets.zero,
  ),
  chipTheme: ChipThemeData(
    backgroundColor: TuM2Colors.surfaceVariant,
    selectedColor: TuM2Colors.primaryLight.withOpacity(0.15),
    checkmarkColor: TuM2Colors.primary,
    labelStyle: TuM2TextStyles.labelSmall,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(100),
    ),
  ),
  dividerTheme: const DividerThemeData(
    color: TuM2Colors.outline,
    thickness: 1,
    space: 1,
  ),
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
);
