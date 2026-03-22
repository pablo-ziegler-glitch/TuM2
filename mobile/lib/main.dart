import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/firebase/firebase_options.dart';
import 'core/providers/auth_providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_colors.dart';

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
  void _handleUri(Uri uri) {
    if (uri.host == 'tum2.app' && uri.path == '/auth/verify') {
      ref.read(authNotifierProvider.notifier).handleEmailLink(uri.toString());
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

    return MaterialApp.router(
      title: 'TuM2',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary500,
          surface: AppColors.surface,
        ),
        scaffoldBackgroundColor: AppColors.scaffoldBg,
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      routerConfig: router,
    );
  }
}
    );
  }
}

// ─── NAV-02: Splash con detección de sesión activa ───────────────────────────

/// Pantalla de splash que detecta el estado de sesión y navega al destino correcto.
class _SplashScreen extends StatefulWidget {
  const _SplashScreen();

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final user = FirebaseAuth.instance.currentUser;
    if (!mounted) return;

    if (user == null) {
      // Sin sesión → home (placeholder; en prod iría a /auth/login)
      context.go('/home');
      return;
    }

    // El guard global se encargará de detectar si hay un onboarding pendiente
    // cuando navegamos a /home. Si role=='owner' y no está completo, redirige.
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: const Center(
        child: CircularProgressIndicator(color: AppColors.primary500),
      ),
    );
  }
}

// ─── Placeholders (hasta implementar las pantallas reales) ───────────────────

class _PlaceholderScreen extends StatelessWidget {
  final String label;
  const _PlaceholderScreen({required this.label});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Center(
        child: Text(
          '→ $label',
          style: const TextStyle(fontSize: 20, color: AppColors.neutral700),
        ),
      ),
    );
  }
}
