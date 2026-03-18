import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/store_providers.dart';

class StoreDashboardScreen extends ConsumerWidget {
  final String storeId;

  const StoreDashboardScreen({super.key, required this.storeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storeAsync = ref.watch(storeDetailProvider(storeId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi comercio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push('/tienda/$storeId/editar'),
          ),
        ],
      ),
      body: storeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (store) {
          if (store == null) {
            return const Center(child: Text('Comercio no encontrado'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Store header
                Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: TuM2Colors.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.storefront,
                          size: 32, color: TuM2Colors.onSurfaceVariant),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(store.name, style: TuM2TextStyles.titleLarge),
                          Text(store.category,
                              style: TuM2TextStyles.bodySmall.copyWith(
                                  color: TuM2Colors.onSurfaceVariant)),
                          const SizedBox(height: 4),
                          _StatusChip(status: store.visibilityStatus),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Completeness score
                _CompletenessCard(
                    score: store.operationalDataCompletenessScore),
                const SizedBox(height: 16),

                // Quick actions
                Text('Gestión', style: TuM2TextStyles.titleMedium),
                const SizedBox(height: 12),
                _ActionTile(
                  icon: Icons.inventory_2_outlined,
                  title: 'Productos',
                  subtitle: 'Administrá tu catálogo',
                  onTap: () =>
                      context.push('/tienda/$storeId/productos'),
                ),
                _ActionTile(
                  icon: Icons.schedule_outlined,
                  title: 'Horarios',
                  subtitle: 'Configurá tu horario semanal',
                  onTap: () =>
                      context.push('/tienda/$storeId/horarios'),
                ),
                _ActionTile(
                  icon: Icons.notifications_outlined,
                  title: 'Señales operativas',
                  subtitle: '24hs, hasta tarde, horario especial',
                  onTap: () =>
                      context.push('/tienda/$storeId/senales'),
                ),
                const SizedBox(height: 16),
                Text('Visibilidad', style: TuM2TextStyles.titleMedium),
                const SizedBox(height: 12),
                _ActionTile(
                  icon: Icons.visibility_outlined,
                  title: 'Ver mi ficha pública',
                  subtitle: 'Así te ven los clientes',
                  onTap: () => context.push('/tienda/$storeId'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case 'active':
        color = TuM2Colors.success;
        label = 'Activo';
      case 'draft':
        color = TuM2Colors.warning;
        label = 'Borrador';
      default:
        color = TuM2Colors.onSurfaceVariant;
        label = 'Suspendido';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(label,
          style:
              TuM2TextStyles.labelSmall.copyWith(color: color)),
    );
  }
}

class _CompletenessCard extends StatelessWidget {
  final int score;

  const _CompletenessCard({required this.score});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TuM2Colors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Perfil operativo', style: TuM2TextStyles.titleMedium),
              Text('$score%',
                  style: TuM2TextStyles.titleMedium.copyWith(
                      color: score >= 70
                          ? TuM2Colors.success
                          : TuM2Colors.warning)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 100,
              backgroundColor: TuM2Colors.outline,
              color: score >= 70 ? TuM2Colors.success : TuM2Colors.warning,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            score >= 70
                ? 'Tu comercio tiene buen nivel de información operativa.'
                : 'Completá tu horario para que los clientes sepan cuándo encontrarte.',
            style: TuM2TextStyles.bodySmall
                .copyWith(color: TuM2Colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: TuM2Colors.primaryLight.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: TuM2Colors.primary, size: 22),
      ),
      title: Text(title, style: TuM2TextStyles.titleMedium),
      subtitle:
          Text(subtitle, style: TuM2TextStyles.bodySmall.copyWith(color: TuM2Colors.onSurfaceVariant)),
      trailing: const Icon(Icons.chevron_right, color: TuM2Colors.onSurfaceVariant),
      onTap: onTap,
    );
  }
}
