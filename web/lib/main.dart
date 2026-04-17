import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/firebase/firebase_bootstrap.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_text_styles.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es', null);
  try {
    await FirebaseBootstrap.initialize();
    runApp(const TuM2AdminApp());
  } catch (error) {
    runApp(FirebaseConfigErrorApp(message: error.toString()));
  }
}

class TuM2AdminApp extends StatelessWidget {
  const TuM2AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'TuM2 Administracion',
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
