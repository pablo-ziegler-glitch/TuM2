import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/user_model.dart';
import '../providers/auth_providers.dart';

class RoleSelectionScreen extends ConsumerStatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  ConsumerState<RoleSelectionScreen> createState() =>
      _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends ConsumerState<RoleSelectionScreen> {
  RoleType? _selected;
  bool _isLoading = false;

  Future<void> _confirm() async {
    if (_selected == null) return;

    final user = ref.read(currentFirebaseUserProvider);
    if (user == null) return;

    setState(() => _isLoading = true);

    await ref
        .read(authNotifierProvider.notifier)
        .selectRole(user.uid, _selected!);

    if (!mounted) return;
    setState(() => _isLoading = false);
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              Text(
                '¿Cómo usás TuM2?',
                style: TuM2TextStyles.headlineLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Elegí tu perfil para personalizar la experiencia.',
                style: TuM2TextStyles.bodyMedium
                    .copyWith(color: TuM2Colors.onSurfaceVariant),
              ),
              const SizedBox(height: 40),
              _RoleCard(
                selected: _selected == RoleType.customer,
                icon: Icons.explore_outlined,
                title: 'Soy Cliente',
                description:
                    'Buscá comercios, productos y farmacias en tu zona.',
                onTap: () => setState(() => _selected = RoleType.customer),
              ),
              const SizedBox(height: 16),
              _RoleCard(
                selected: _selected == RoleType.owner,
                icon: Icons.storefront_outlined,
                title: 'Soy Comerciante',
                description:
                    'Registrá tu comercio, cargá productos y gestioná tus horarios.',
                onTap: () => setState(() => _selected = RoleType.owner),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _selected == null || _isLoading ? null : _confirm,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Continuar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _RoleCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? TuM2Colors.primary : TuM2Colors.outline,
            width: selected ? 2 : 1,
          ),
          color: selected
              ? TuM2Colors.primary.withOpacity(0.06)
              : TuM2Colors.background,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: selected
                    ? TuM2Colors.primary.withOpacity(0.12)
                    : TuM2Colors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color:
                    selected ? TuM2Colors.primary : TuM2Colors.onSurfaceVariant,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TuM2TextStyles.titleMedium.copyWith(
                        color: selected
                            ? TuM2Colors.primary
                            : TuM2Colors.onBackground,
                        fontWeight: FontWeight.w600,
                      )),
                  const SizedBox(height: 4),
                  Text(description,
                      style: TuM2TextStyles.bodySmall
                          .copyWith(color: TuM2Colors.onSurfaceVariant)),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: TuM2Colors.primary),
          ],
        ),
      ),
    );
  }
}
