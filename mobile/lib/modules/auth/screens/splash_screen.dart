import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// AUTH-01 — Splash / Loading
///
/// Pantalla de entrada. Muestra el logo mientras el estado de auth se resuelve.
/// La navegación la maneja el redirect de go_router en app_router.dart:
///   sesión activa     → /home
///   primer uso        → /onboarding
///   sesión expirada   → /login
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Navegación manejada completamente por el redirect de app_router.dart.
    // Cuando auth resuelve: con sesión → home, sin sesión → onboarding o login.
    return Scaffold(
      backgroundColor: AppColors.primary500,
      body: Stack(
        children: [
          // Círculos decorativos semi-transparentes
          Positioned(
            top: -60,
            right: -80,
            child: _DecorativeCircle(size: 280, opacity: 0.08),
          ),
          Positioned(
            bottom: 80,
            left: -60,
            child: _DecorativeCircle(size: 200, opacity: 0.05),
          ),

          // Contenido centrado
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Ícono pin
                const Icon(
                  Icons.location_on_rounded,
                  size: 32,
                  color: Colors.white70,
                ),
                const SizedBox(height: 8),

                // Logo TuM2
                // TODO(assets): reemplazar con asset SVG/PNG del logo en blanco
                Text(
                  'TuM2',
                  style: AppTextStyles.headingLg.copyWith(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 8),

                // Claim
                Text(
                  'TU BARRIO, SIEMPRE CONECTADO',
                  style: AppTextStyles.bodyXs.copyWith(
                    color: Colors.white.withOpacity(0.7),
                    letterSpacing: 1.5,
                  ),
                ),

                const SizedBox(height: 48),

                // Barra de progreso
                SizedBox(
                  width: 120,
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.white.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation(
                      Colors.white.withOpacity(0.54),
                    ),
                    minHeight: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Cargando...',
                  style: AppTextStyles.bodyXs.copyWith(
                    color: Colors.white.withOpacity(0.54),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DecorativeCircle extends StatelessWidget {
  const _DecorativeCircle({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(opacity),
      ),
    );
  }
}
