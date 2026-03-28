import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/firebase/firebase_options.dart';
import 'core/providers/auth_providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_colors.dart';
import 'core/widgets/app_toast.dart';

/// Punto de entrada de la app TuM2.
///
/// Inicializa Firebase y monta la app con Riverpod + go_router.
/// Para dev local con emuladores, Firebase se conecta automáticamente
/// a localhost:9099 (auth) y localhost:8080 (firestore).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    const ProviderScope(
      child: TuM2App(),
    ),
  );
}

// Clave global para mostrar toasts de autenticación desde fuera de un Scaffold.
final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class TuM2App extends ConsumerStatefulWidget {
  const TuM2App({super.key});

  @override
  ConsumerState<TuM2App> createState() => _TuM2AppState();
}

class _TuM2AppState extends ConsumerState<TuM2App> {
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    final appLinks = AppLinks();

    // Link que abrió la app desde estado terminado
    final initialUri = await appLinks.getInitialLink();
    if (initialUri != null) {
      _handleUri(initialUri);
    }

    // Links mientras la app está en foreground o background
    _linkSub = appLinks.uriLinkStream.listen(_handleUri);
  }

  /// Procesa el URI entrante. Solo actúa si el host/path corresponde al
  /// callback de magic link configurado en ActionCodeSettings.
  Future<void> _handleUri(Uri uri) async {
    if (uri.host == 'tum2.app' && uri.path == '/auth/verify') {
      final link = uri.toString();
      final hasPending =
          await ref.read(authNotifierProvider.notifier).hasPendingEmailLink();

      if (hasPending) {
        // Dispositivo correcto: procesar directamente
        ref.read(authNotifierProvider.notifier).handleEmailLink(link);
      } else {
        // Dispositivo diferente: guardar link y navegar a verify-email
        // para que el usuario ingrese el email con el que pidió el link.
        ref.read(pendingMagicLinkProvider.notifier).state = link;
        ref
            .read(appRouterProvider)
            .go('${AppRoutes.emailVerification}?cross_device=true');
      }
    }
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);

    // Mostrar toast post-autenticación cuando el provider lo notifica.
    // Usamos ScaffoldMessengerKey para mostrarlo sin depender de un Scaffold activo.
    ref.listen<String?>(pendingAuthToastProvider, (_, toast) {
      if (toast != null) {
        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(toast),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.successBg,
            showCloseIcon: true,
            closeIconColor: AppColors.successFg,
          ),
        );
        ref.read(pendingAuthToastProvider.notifier).state = null;
      }
    });

    return MaterialApp.router(
      title: 'TuM2',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _scaffoldMessengerKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary500,
          surface: AppColors.surface,
        ),
        scaffoldBackgroundColor: AppColors.scaffoldBg,
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: AppColors.surface,
          indicatorColor: AppColors.primary100,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      routerConfig: router,
    );
  }
}
