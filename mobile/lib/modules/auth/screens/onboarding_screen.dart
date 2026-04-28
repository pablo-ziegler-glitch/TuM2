import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/analytics/auth_analytics.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/primary_button.dart';

/// AUTH-02 — Onboarding CUSTOMER (carrusel 3 slides)
///
/// Pantalla de bienvenida para primer uso.
/// Cada slide tiene su propio color de acento: primary, secondary, tertiary.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({
    super.key,
    this.source = 'first_launch',
  });

  final String source;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _currentPage = 0;
  bool _hasLoggedStart = false;

  static const _slides = [
    _SlideData(
      id: 'open_now',
      title: 'Encontrá comercios abiertos ahora en tu cuadra',
      subtitle:
          'Kioscos, almacenes, panaderías y comercios de tu zona, claros y a mano.',
      icon: Icons.location_on_rounded,
      accentColor: AppColors.primary500,
      bgColor: AppColors.primary50,
    ),
    _SlideData(
      id: 'pharmacy_duty',
      title: 'Farmacias de turno al instante',
      subtitle:
          'Cuando necesitás resolver rápido, ves qué farmacia está de guardia cerca.',
      icon: Icons.local_pharmacy_outlined,
      accentColor: AppColors.secondary500,
      bgColor: AppColors.secondary50,
    ),
    _SlideData(
      id: 'places_near',
      title: 'Tené tus lugares de siempre más cerca',
      subtitle:
          'Guardá los lugares que usás seguido y volvé a encontrarlos más fácil.',
      icon: Icons.favorite_border_rounded,
      accentColor: AppColors.tertiary500,
      bgColor: AppColors.tertiary50,
    ),
  ];

  String get _source {
    final raw = widget.source.trim();
    if (raw == 'profile_help') return raw;
    if (raw == 'manual') return raw;
    return 'first_launch';
  }

  @override
  void initState() {
    super.initState();
    _logOnboardingStart();
    _logSlideViewed(0);
  }

  void _logOnboardingStart() {
    if (_hasLoggedStart) return;
    _hasLoggedStart = true;
    AuthAnalytics.logOnboardingStarted(
      source: _source,
      totalSlides: _slides.length,
    ).ignore();
  }

  void _logSlideViewed(int index) {
    AuthAnalytics.logOnboardingSlideViewed(
      slideIndex: index,
      slideId: _slides[index].id,
      totalSlides: _slides.length,
      source: _source,
    ).ignore();
  }

  void _onPageChanged(int index) {
    if (_currentPage == index) return;
    setState(() => _currentPage = index);
    _logSlideViewed(index);
  }

  void _next() {
    if (_currentPage < _slides.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeAsGuest();
    }
  }

  Future<void> _completeAsGuest() async {
    final current = _slides[_currentPage];
    AuthAnalytics.logOnboardingCompleted(
      slideIndex: _currentPage,
      slideId: current.id,
      totalSlides: _slides.length,
      source: _source,
    ).ignore();
    await markOnboardingSeen();
    ref.invalidate(isFirstLaunchProvider);
    if (mounted) context.go(AppRoutes.home);
  }

  Future<void> _skipAsGuest() async {
    final current = _slides[_currentPage];
    AuthAnalytics.logOnboardingSkipped(
      slideIndex: _currentPage,
      slideId: current.id,
      totalSlides: _slides.length,
      source: _source,
    ).ignore();
    await markOnboardingSeen();
    ref.invalidate(isFirstLaunchProvider);
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
            // Botón "Omitir" (top right)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _skipAsGuest,
                child: Text(
                  'Omitir',
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
                onPageChanged: _onPageChanged,
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
                label: isLastPage ? 'Empezar' : 'Siguiente',
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
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.bgColor,
  });

  final String id;
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
