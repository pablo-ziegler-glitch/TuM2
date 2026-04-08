import 'package:flutter/material.dart';

/// Colores canónicos y de soporte para la identidad visual de TuM2.
final class AppColors {
  AppColors._();

  // Core brand palette.
  static const Color primary = Color(0xFF0E5BD8);
  static const Color secondary = Color(0xFF0F766E);
  static const Color error = Color(0xFFDC2626);
  static const Color offWhite = Color(0xFFF9F8F6);
  static const Color warmBackground = Color(0xFFFDFAE9);
  static const Color darkNavy = Color(0xFF0D1624);

  // Superficies y soportes.
  static const Color surface = Color(0xFFFFFFFF);
  static const Color background = warmBackground;
  static const Color border = Color(0xFFD9D6C4);
  static const Color borderSoft = Color(0xFFE8E5D5);
  static const Color textPrimary = Color(0xFF1C1C17);
  static const Color textSecondary = Color(0xFF5A5A4D);
  static const Color textMuted = Color(0xFF7A7A6E);
  static const Color disabled = Color(0xFF9F9F91);
  static const Color successSoft = Color(0xFFE6F4EA);
  static const Color primarySoft = Color(0xFFEBF1FD);
  static const Color neutralSoft = Color(0xFFF1EEE0);
  static const Color closedGray = Color(0xFF5A5A4D);
}

/// Tipografía base del sistema.
final class AppTypography {
  AppTypography._();

  // Queda preparado para integrar fuentes por assets cuando corresponda.
  static const String headlineFamily = 'Manrope';
  static const String bodyFamily = 'Inter';
}

/// Escala base de espaciado en múltiplos de 4.
final class AppSpacing {
  AppSpacing._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 40;
  static const double xxxl = 48;
}

/// Radios canónicos para componentes base.
final class AppRadii {
  AppRadii._();

  static const double button = 999;
  static const double card = 24;
  static const double input = 999;
  static const double sheet = 24;
}

/// Estilo semántico individual de badge.
@immutable
final class BadgeStyle {
  const BadgeStyle({
    required this.foreground,
    required this.background,
    this.border,
  });

  final Color foreground;
  final Color background;
  final Color? border;

  BadgeStyle copyWith({
    Color? foreground,
    Color? background,
    Color? border,
  }) {
    return BadgeStyle(
      foreground: foreground ?? this.foreground,
      background: background ?? this.background,
      border: border ?? this.border,
    );
  }

  static BadgeStyle lerp(BadgeStyle a, BadgeStyle b, double t) {
    return BadgeStyle(
      foreground: Color.lerp(a.foreground, b.foreground, t) ?? a.foreground,
      background: Color.lerp(a.background, b.background, t) ?? a.background,
      border: Color.lerp(a.border, b.border, t),
    );
  }
}

/// Colores semánticos de badges operativos para TuM2.
@immutable
final class StatusBadgeTheme extends ThemeExtension<StatusBadgeTheme> {
  const StatusBadgeTheme({
    required this.openNow,
    required this.twentyFourHours,
    required this.closed,
    required this.guard,
  });

  final BadgeStyle openNow;
  final BadgeStyle twentyFourHours;
  final BadgeStyle closed;
  final BadgeStyle guard;

  static const StatusBadgeTheme base = StatusBadgeTheme(
    openNow: BadgeStyle(
      foreground: Color(0xFF065F46),
      background: AppColors.successSoft,
      border: Color(0xFFBFE3CC),
    ),
    twentyFourHours: BadgeStyle(
      foreground: Colors.white,
      background: AppColors.primary,
      border: Color(0xFF0B4DB8),
    ),
    closed: BadgeStyle(
      foreground: AppColors.closedGray,
      background: AppColors.borderSoft,
      border: AppColors.border,
    ),
    guard: BadgeStyle(
      foreground: Colors.white,
      background: AppColors.error,
      border: Color(0xFFB91C1C),
    ),
  );

  @override
  StatusBadgeTheme copyWith({
    BadgeStyle? openNow,
    BadgeStyle? twentyFourHours,
    BadgeStyle? closed,
    BadgeStyle? guard,
  }) {
    return StatusBadgeTheme(
      openNow: openNow ?? this.openNow,
      twentyFourHours: twentyFourHours ?? this.twentyFourHours,
      closed: closed ?? this.closed,
      guard: guard ?? this.guard,
    );
  }

  @override
  StatusBadgeTheme lerp(
      covariant ThemeExtension<StatusBadgeTheme>? other, double t) {
    if (other is! StatusBadgeTheme) return this;
    return StatusBadgeTheme(
      openNow: BadgeStyle.lerp(openNow, other.openNow, t),
      twentyFourHours:
          BadgeStyle.lerp(twentyFourHours, other.twentyFourHours, t),
      closed: BadgeStyle.lerp(closed, other.closed, t),
      guard: BadgeStyle.lerp(guard, other.guard, t),
    );
  }
}

/// Tema principal de TuM2 para MaterialApp.
final class AppTheme {
  AppTheme._();

  static ThemeData get light => lightTheme;

  static ThemeData get lightTheme {
    const colorScheme = _lightColorScheme;
    final textTheme = _textTheme(colorScheme);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: AppTypography.bodyFamily,
      textTheme: textTheme,
      scaffoldBackgroundColor: AppColors.background,
      cardTheme: _cardTheme(),
      elevatedButtonTheme: _elevatedButtonTheme(colorScheme, textTheme),
      outlinedButtonTheme: _outlinedButtonTheme(colorScheme, textTheme),
      textButtonTheme: _textButtonTheme(colorScheme, textTheme),
      inputDecorationTheme: _inputDecorationTheme(colorScheme, textTheme),
      chipTheme: _chipTheme(colorScheme, textTheme),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderSoft,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: AppColors.background,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: colorScheme.surface,
        indicatorColor: AppColors.primarySoft,
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelMedium),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final color = states.contains(WidgetState.selected)
              ? colorScheme.primary
              : AppColors.textMuted;
          return IconThemeData(color: color);
        }),
      ),
      extensions: const <ThemeExtension<dynamic>>[
        StatusBadgeTheme.base,
      ],
    );
  }

  /// Helper para obtener los colores semánticos de badges desde el contexto.
  static StatusBadgeTheme statusBadgesOf(BuildContext context) {
    return Theme.of(context).extension<StatusBadgeTheme>() ??
        StatusBadgeTheme.base;
  }

  static const ColorScheme _lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.primary,
    onPrimary: Colors.white,
    primaryContainer: AppColors.primarySoft,
    onPrimaryContainer: Color(0xFF0B2E6A),
    primaryFixed: AppColors.primarySoft,
    primaryFixedDim: Color(0xFF9BBBF5),
    onPrimaryFixed: Color(0xFF06285E),
    onPrimaryFixedVariant: Color(0xFF0B3A87),
    secondary: AppColors.secondary,
    onSecondary: Colors.white,
    secondaryContainer: AppColors.successSoft,
    onSecondaryContainer: Color(0xFF0A4742),
    secondaryFixed: AppColors.successSoft,
    secondaryFixedDim: Color(0xFF80C5C0),
    onSecondaryFixed: Color(0xFF032A26),
    onSecondaryFixedVariant: Color(0xFF0C635C),
    tertiary: AppColors.darkNavy,
    onTertiary: Colors.white,
    tertiaryContainer: AppColors.neutralSoft,
    onTertiaryContainer: AppColors.darkNavy,
    tertiaryFixed: AppColors.neutralSoft,
    tertiaryFixedDim: AppColors.borderSoft,
    onTertiaryFixed: Color(0xFF09101B),
    onTertiaryFixedVariant: Color(0xFF1B2A41),
    error: AppColors.error,
    onError: Colors.white,
    errorContainer: Color(0xFFFDEAEA),
    onErrorContainer: Color(0xFF7A1313),
    surface: AppColors.background,
    onSurface: AppColors.textPrimary,
    surfaceDim: Color(0xFFE3E0CF),
    surfaceBright: Color(0xFFFFFFFF),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFFAF7E6),
    surfaceContainer: AppColors.neutralSoft,
    surfaceContainerHigh: Color(0xFFF5F2E2),
    surfaceContainerHighest: AppColors.borderSoft,
    onSurfaceVariant: AppColors.textSecondary,
    outline: AppColors.border,
    outlineVariant: AppColors.borderSoft,
    shadow: Color(0x1F5A5A4D),
    scrim: Color(0x4D1C1C17),
    inverseSurface: Color(0xFF1E293B),
    onInverseSurface: Color(0xFFF6F8FC),
    inversePrimary: Color(0xFF9BBBF5),
    surfaceTint: AppColors.primary,
  );

  static TextTheme _textTheme(ColorScheme colorScheme) {
    return TextTheme(
      displaySmall: TextStyle(
        fontFamily: AppTypography.headlineFamily,
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: 0,
        color: colorScheme.onSurface,
      ),
      headlineSmall: TextStyle(
        fontFamily: AppTypography.headlineFamily,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.25,
        letterSpacing: 0,
        color: colorScheme.onSurface,
      ),
      titleLarge: TextStyle(
        fontFamily: AppTypography.headlineFamily,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.3,
        letterSpacing: 0,
        color: colorScheme.onSurface,
      ),
      titleMedium: TextStyle(
        fontFamily: AppTypography.headlineFamily,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.35,
        letterSpacing: 0.1,
        color: colorScheme.onSurface,
      ),
      bodyLarge: TextStyle(
        fontFamily: AppTypography.bodyFamily,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.45,
        letterSpacing: 0,
        color: colorScheme.onSurface,
      ),
      bodyMedium: TextStyle(
        fontFamily: AppTypography.bodyFamily,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.45,
        letterSpacing: 0,
        color: colorScheme.onSurfaceVariant,
      ),
      bodySmall: const TextStyle(
        fontFamily: AppTypography.bodyFamily,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.4,
        letterSpacing: 0.1,
        color: AppColors.textMuted,
      ),
      labelLarge: TextStyle(
        fontFamily: AppTypography.bodyFamily,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.25,
        letterSpacing: 0.1,
        color: colorScheme.onPrimary,
      ),
      labelMedium: TextStyle(
        fontFamily: AppTypography.bodyFamily,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: 0.1,
        color: colorScheme.onSurface,
      ),
    );
  }

  static ElevatedButtonThemeData _elevatedButtonTheme(
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return ElevatedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size.fromHeight(48)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
        ),
        elevation: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) return 0.5;
          return 0.2;
        }),
        shadowColor: const WidgetStatePropertyAll(Color(0x165A5A4D)),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
          ),
        ),
        textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return AppColors.disabled;
          if (states.contains(WidgetState.pressed)) {
            return const Color(0xFF0B4DB8);
          }
          return colorScheme.primary;
        }),
        foregroundColor: const WidgetStatePropertyAll(Colors.white),
      ),
    );
  }

  static OutlinedButtonThemeData _outlinedButtonTheme(
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return OutlinedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size.fromHeight(48)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
          ),
        ),
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return const BorderSide(color: AppColors.borderSoft);
          }
          if (states.contains(WidgetState.pressed)) {
            return BorderSide(color: colorScheme.primary, width: 1.4);
          }
          return BorderSide(color: colorScheme.primary, width: 1.4);
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return AppColors.disabled;
          return colorScheme.primary;
        }),
        textStyle: WidgetStatePropertyAll(
          textTheme.labelLarge?.copyWith(color: colorScheme.primary),
        ),
      ),
    );
  }

  static TextButtonThemeData _textButtonTheme(
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return TextButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(
              horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
          ),
        ),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return AppColors.disabled;
          if (states.contains(WidgetState.pressed)) {
            return const Color(0xFF0B4DB8);
          }
          return colorScheme.primary;
        }),
        textStyle: WidgetStatePropertyAll(
          textTheme.labelLarge?.copyWith(color: colorScheme.primary),
        ),
      ),
    );
  }

  static CardThemeData _cardTheme() {
    return CardThemeData(
      color: AppColors.surface,
      margin: EdgeInsets.zero,
      elevation: 0.2,
      shadowColor: const Color(0x145A5A4D),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: const BorderSide(color: AppColors.borderSoft),
      ),
      clipBehavior: Clip.antiAlias,
    );
  }

  static InputDecorationTheme _inputDecorationTheme(
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      hintStyle: textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
      labelStyle:
          textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
      floatingLabelStyle:
          textTheme.bodySmall?.copyWith(color: colorScheme.primary),
      enabledBorder: _inputBorder(AppColors.borderSoft),
      focusedBorder: _inputBorder(colorScheme.primary, width: 1.6),
      disabledBorder: _inputBorder(AppColors.borderSoft),
      errorBorder: _inputBorder(colorScheme.error),
      focusedErrorBorder: _inputBorder(colorScheme.error, width: 1.6),
      errorStyle: textTheme.bodySmall?.copyWith(color: colorScheme.error),
    );
  }

  static ChipThemeData _chipTheme(
      ColorScheme colorScheme, TextTheme textTheme) {
    return ChipThemeData(
      backgroundColor: AppColors.neutralSoft,
      selectedColor: AppColors.primarySoft,
      disabledColor: AppColors.neutralSoft,
      deleteIconColor: AppColors.textMuted,
      labelStyle:
          textTheme.labelMedium?.copyWith(color: AppColors.textSecondary),
      secondaryLabelStyle:
          textTheme.labelMedium?.copyWith(color: colorScheme.primary),
      brightness: Brightness.light,
      shape: const StadiumBorder(
        side: BorderSide(color: AppColors.border),
      ),
      side: const BorderSide(color: AppColors.border),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
      elevation: 0,
      pressElevation: 0,
      showCheckmark: false,
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1.2}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.input),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
