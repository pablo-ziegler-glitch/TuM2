import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_notifier.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// HOME-01 — Pantalla de inicio del cliente.
///
/// Muestra el saludo personalizado, barra de búsqueda rápida y la sección
/// de recomendados con comercios destacados de la zona (datos mockeados).
class HomePlaceholderScreen extends ConsumerWidget {
  const HomePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider).authState;
    final displayName = authState is AuthAuthenticated
        ? (authState.user.displayName?.split(' ').first ?? 'vos')
        : 'vos';

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header con saludo y avatar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BIENVENIDO OTRA VEZ',
                        style: AppTextStyles.labelSm.copyWith(
                          color: AppColors.neutral500,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text('Tu barrio', style: AppTextStyles.headingLg),
                    ],
                  ),
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primary100,
                    child: Text(
                      displayName.isNotEmpty
                          ? displayName[0].toUpperCase()
                          : 'U',
                      style: AppTextStyles.labelMd.copyWith(
                        color: AppColors.primary500,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Barra de búsqueda rápida (redirige al tab Buscar)
              GestureDetector(
                onTap: () => context.go(AppRoutes.search),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.neutral200),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search,
                        size: 20,
                        color: AppColors.neutral400,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Buscá comercios del barrio...',
                        style: AppTextStyles.bodyMd.copyWith(
                          color: AppColors.neutral400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Sección de recomendados
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Elegidos del barrio',
                      style: AppTextStyles.headingSm),
                  TextButton(
                    onPressed: () {},
                    child: Text(
                      'Ver todo',
                      style: AppTextStyles.labelSm.copyWith(
                        color: AppColors.primary500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              SizedBox(
                height: 220,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _mockCommerces.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final item = _mockCommerces[index];
                    return _CommerceCard(
                      item: item,
                      onTap: () => context.push(
                        AppRoutes.commerceDetailPath(item.id),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Datos mockeados ────────────────────────────────────────────────────────────

class _MockCommerce {
  final String id;
  final String district;
  final String name;
  final double rating;
  final String description;

  const _MockCommerce({
    required this.id,
    required this.district,
    required this.name,
    required this.rating,
    required this.description,
  });
}

const _mockCommerces = [
  _MockCommerce(
    id: 'paper-atelier',
    district: 'ZONA 01',
    name: 'Taller de Papel',
    rating: 4.9,
    description:
        'Papelería artesanal y cuadernos hechos a mano para la vida urbana.',
  ),
  _MockCommerce(
    id: 'cafe-aura',
    district: 'CENTRO',
    name: 'Café Aura',
    rating: 4.7,
    description:
        'El corazón del barrio desde 2010. Café de especialidad y ambiente acogedor.',
  ),
];

// ── Widget de tarjeta de comercio ─────────────────────────────────────────────

class _CommerceCard extends StatelessWidget {
  final _MockCommerce item;
  final VoidCallback onTap;

  const _CommerceCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.neutral100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen con badge de distrito
            Stack(
              children: [
                Container(
                  height: 110,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: AppColors.neutral100,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  child: const Icon(
                    Icons.storefront_outlined,
                    size: 40,
                    color: AppColors.neutral300,
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary500,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.district,
                      style: AppTextStyles.labelSm.copyWith(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Info del comercio
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: AppTextStyles.labelMd.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.star,
                            size: 12,
                            color: AppColors.tertiary500,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            item.rating.toString(),
                            style: AppTextStyles.labelSm,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.description,
                    style: AppTextStyles.bodyXs.copyWith(
                      color: AppColors.neutral600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
