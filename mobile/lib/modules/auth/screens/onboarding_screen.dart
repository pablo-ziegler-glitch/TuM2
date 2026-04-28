import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/copy/brand_copy.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/primary_button.dart';

/// AUTH-02 — Onboarding CUSTOMER (carrusel 3 slides)
///
/// Pantalla de bienvenida para primer uso.
/// Cada slide tiene su propio color de acento: primary, secondary, tertiary.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _currentPage = 0;

  static const _slides = [
    _SlideData(
      title: BrandCopy.primaryClaim,
      subtitle: BrandCopy.onboardingInitialSubtitle,
      icon: Icons.location_on_rounded,
      accentColor: AppColors.primary500,
      bgColor: AppColors.primary50,
    ),
    _SlideData(
      title: 'Farmacias de turno al instante',
      subtitle: 'Sin llamar a nadie. Sabés cuál está de guardia esta noche.',
      icon: Icons.local_pharmacy_outlined,
      accentColor: AppColors.secondary500,
      bgColor: AppColors.secondary50,
    ),
    _SlideData(
      title: 'Seguí tus comercios favoritos',
      subtitle:
          'Recibí alertas cuando abren, cambian sus horarios o publican novedades.',
      icon: Icons.favorite_border_rounded,
      accentColor: AppColors.tertiary500,
      bgColor: AppColors.tertiary50,
    ),
  ];

  void _next() {
    if (_currentPage < _slides.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _continueAsGuest();
    }
  }

  Future<void> _continueAsGuest() async {
    await markOnboardingSeen();
    if (mounted) context.go(AppRoutes.home);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentSlide = _slides[_currentPage];
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
                onPressed: _continueAsGuest,
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
                  return _OnboardingSlide(data: _slides[index]);
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
                        ? currentSlide.accentColor
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
                label: isLastPage ? 'Empezar →' : 'Siguiente →',
                onPressed: _next,
                backgroundColor: currentSlide.accentColor,
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

/// Datos inmutables por slide.
class _SlideData {
  const _SlideData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.bgColor,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final Color bgColor;
}

class _OnboardingSlide extends StatelessWidget {
  const _OnboardingSlide({required this.data});

  final _SlideData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Ilustración con ícono y color de acento por slide
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: data.bgColor,
            ),
            child: Center(
              child: Icon(
                data.icon,
                size: 80,
                color: data.accentColor,
              ),
            ),
          ),

          const SizedBox(height: 40),

          Text(
            data.title,
            textAlign: TextAlign.center,
            style: AppTextStyles.headingMd,
          ),

          const SizedBox(height: 12),

          Text(
            data.subtitle,
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
