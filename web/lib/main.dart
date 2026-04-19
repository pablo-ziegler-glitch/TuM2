import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/firebase/firebase_bootstrap.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/admin_theme_mode.dart';
import 'core/theme/app_text_styles.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es', null);
  final themeController = AdminThemeController.fromUri(Uri.base);
  try {
    await FirebaseBootstrap.initialize();
    runApp(TuM2AdminApp(themeController: themeController));
  } catch (error) {
    runApp(FirebaseConfigErrorApp(message: error.toString()));
  }
}

class TuM2AdminApp extends StatelessWidget {
  const TuM2AdminApp({
    super.key,
    required this.themeController,
  });

  final AdminThemeController themeController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        final isWorldcup = themeController.isWorldcup;
        return MaterialApp.router(
          title: 'TuM2 Administracion',
          debugShowCheckedModeBanner: false,
          routerConfig: appRouter,
          builder: (context, child) {
            return AdminThemeScope(
              controller: themeController,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: isWorldcup
                      ? const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFFF7FBFF),
                            Color(0xFFEDF5FF),
                          ],
                        )
                      : null,
                ),
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor:
                  isWorldcup ? const Color(0xFF1D4ED8) : AppColors.primary500,
            ),
            scaffoldBackgroundColor:
                isWorldcup ? const Color(0xFFF5F9FF) : AppColors.scaffoldBg,
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
      },
    );
  }
}

class FirebaseConfigErrorApp extends StatelessWidget {
  const FirebaseConfigErrorApp({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFF5F6F8),
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 760),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE4E6EB)),
            ),
            child: SelectableText(
              'Firebase no pudo inicializarse.\n\n$message\n\n'
              'Iniciá la web con:\n'
              'flutter run -d chrome '
              '--dart-define=FIREBASE_API_KEY=... '
              '--dart-define=FIREBASE_APP_ID=... '
              '--dart-define=FIREBASE_MESSAGING_SENDER_ID=... '
              '--dart-define=FIREBASE_PROJECT_ID=...\n'
              '(opcional) --dart-define=USE_FIREBASE_EMULATORS=true',
              style: const TextStyle(fontSize: 14, color: Color(0xFF2B2E36)),
            ),
          ),
        ),
      ),
    );
  }
}
