import 'package:flutter/material.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_text_styles.dart';

void main() {
  runApp(const TuM2AdminApp());
}

class TuM2AdminApp extends StatelessWidget {
  const TuM2AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'TuM2 Admin',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary500),
        scaffoldBackgroundColor: AppColors.scaffoldBg,
        fontFamily: 'Inter',
        textTheme: TextTheme(
          headlineLarge: AppTextStyles.headingLg,
          headlineMedium: AppTextStyles.headingMd,
          headlineSmall: AppTextStyles.headingSm,
          bodyLarge: AppTextStyles.bodyMd,
          bodyMedium: AppTextStyles.bodySm,
          bodySmall: AppTextStyles.bodyXs,
          labelLarge: AppTextStyles.labelMd,
          labelSmall: AppTextStyles.labelSm,
        ),
      ),
    );
  }
}
