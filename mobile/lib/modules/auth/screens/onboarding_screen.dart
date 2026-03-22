import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/auth_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/primary_button.dart';

/// AUTH-02 — Onboarding CUSTOMER (carrusel 3 slides)
///
/// Pantalla de bienvenida para primer uso.
/// Muestra 3 slides con la propuesta de valor de TuM2.
///
/// TODO(figma): implementar layout real con ilustraciones cuando lleguen los mockups.
/// Por ahora es un placeholder funcional con PageView y navegación correcta.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _currentPage = 0;

  static const _slides = [
    _OnboardingSlide(
      title: 'Encontrá comercios abiertos ahora en tu cuadra',
      subtitle:
          'Kioscos, almacenes, panaderías y más — sabés al instante si están abiertos.',
      // TODO(figma): agregar ilustración
    ),
    _OnboardingSlide(
      title: 'Farmacias de turno al instante',
      subtitle:
          'Sin llamar a nadie. Sabés cuál está de guardia esta noche.',
      // TODO(figma): agregar ilustración
    ),
    _OnboardingSlide(
      title: 'Seguí tus comercios favoritos',
      subtitle:
          'Recibí alertas cuando abren, cambian sus horarios o publican novedades.',
      // TODO(figma): agregar ilustración
    ),
  ];

  void _next() {
    if (_currentPage < _slides.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _goToLogin();
    }
  }

  Future<void> _goToLogin() async {
    await markOnboardingSeen();
    if (mounted) context.go(AppRoutes.login);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentPage == _slides.length - 1;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Botón "Saltar" (top right)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _goToLogin,
                child: Text(
                  'Saltar',
                  style: AppTextStyles.labelSm.copyWith(
                    color: AppColors.neutral600,
                  ),
                ),
              ),
            ),

            // Slides
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, index) {
                  return _slides[index];
                },
              ),
            ),

            // Dots de paginación
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _slides.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == i ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == i
                        ? AppColors.primary500
                        : AppColors.neutral300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Botón de acción
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: PrimaryButton(
                label: isLastPage ? 'Empezar' : 'Siguiente',
                onPressed: _next,
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _OnboardingSlide extends StatelessWidget {
  const _OnboardingSlide({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // TODO(figma): placeholder de ilustración
          Container(
            height: 200,
            width: 200,
            decoration: BoxDecoration(
              color: AppColors.primary50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
              child: Icon(
                Icons.storefront_outlined,
                size: 80,
                color: AppColors.primary300,
              ),
            ),
          ),

          const SizedBox(height: 40),

          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.headingMd,
          ),

          const SizedBox(height: 12),

          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMd.copyWith(
              color: AppColors.neutral700,
            ),
          ),
        ],
      ),
    );
  }
}
