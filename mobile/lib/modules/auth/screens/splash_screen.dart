import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/auth_analytics.dart';
import '../../../core/auth/auth_notifier.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/copy/brand_copy.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/providers/feature_flags_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// AUTH-01 — Splash con detección de sesión y lógica de decisión.
///
/// Muestra el logo + indicador de carga mientras [AuthNotifier] resuelve
/// el estado inicial. Si Firebase no responde en 5 segundos, fuerza modo
/// invitado para no bloquear discovery público.
///
/// La navegación post-carga la maneja el redirect global del router —
/// esta pantalla no hace context.go().
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  Timer? _timeoutTimer;
  late final AuthNotifier _authNotifier;
  late final DateTime _startedAt;
  bool _hasLoggedResolved = false;
  bool _timedOut = false;

  @override
  void initState() {
    super.initState();
    _authNotifier = ref.read(authNotifierProvider);
    _startedAt = DateTime.now();
    AuthAnalytics.logSplashViewed(latencyMs: 0).ignore();
    _startTimeoutGuard();
    _authNotifier.addListener(_onAuthChanged);
  }

  int get _latencyMs => DateTime.now().difference(_startedAt).inMilliseconds;

  void _onAuthChanged() {
    if (_hasLoggedResolved) return;
    final current = _authNotifier.authState;
    if (current is AuthLoading) return;
    _hasLoggedResolved = true;

    if (current is AuthAuthenticated) {
      AuthAnalytics.logSplashResolved(
        result: 'authenticated',
        latencyMs: _latencyMs,
      ).ignore();
      return;
    }

    final firstLaunchState = ref.read(isFirstLaunchProvider);
    final isFirstLaunch = firstLaunchState.valueOrNull;
    final result =
        isFirstLaunch == true ? 'guest_first_launch' : 'guest_returning';
    AuthAnalytics.logSplashResolved(
      result: result,
      latencyMs: _latencyMs,
    ).ignore();
  }

  /// Si tras 5 segundos el estado sigue siendo [AuthLoading], fuerza
  /// AuthUnauthenticated para destrabar navegación guest-first.
  void _startTimeoutGuard() {
    _timeoutTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      final current = _authNotifier.authState;
      if (current is AuthLoading) {
        setState(() => _timedOut = true);
        AuthAnalytics.logSplashTimeout(latencyMs: _latencyMs).ignore();
        _authNotifier.forceUnauthenticated();
      }
    });
  }

  @override
  void dispose() {
    _authNotifier.removeListener(_onAuthChanged);
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brandVariant = ref.watch(splashBrandVariantProvider).valueOrNull ??
        SplashBrandVariant.original;
    final logoAssetPath = brandVariant == SplashBrandVariant.worldcup
        ? 'assets/auth01/tum2_mundialista_logo_splash_512.png'
        : 'assets/auth01/tum2_original_logo_splash_512.png';

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  logoAssetPath,
                  width: 156,
                  fit: BoxFit.contain,
                  semanticLabel: 'TuM2',
                  errorBuilder: (_, __, ___) => Text(
                    'TuM2',
                    style: AppTextStyles.headingLg.copyWith(
                      color: AppColors.primary500,
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  BrandCopy.primaryClaim,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.neutral800,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: AppColors.primary500,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.tertiary500,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Preparando tu zona...',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.neutral700,
                  ),
                ),
                if (_timedOut) ...[
                  const SizedBox(height: 16),
                  Text(
                    'No pudimos confirmar tu sesión. Podés seguir explorando igual.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.neutral700,
                    ),
                  ),
                  TextButton(
                    onPressed: _authNotifier.forceUnauthenticated,
                    child: const Text('Explorar sin iniciar sesión'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
