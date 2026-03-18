import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../brand/ranks/rank_utils.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../store/presentation/providers/store_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final firebaseUser = ref.watch(currentFirebaseUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            onPressed: () async {
              await ref.read(authNotifierProvider.notifier).signOut();
              if (context.mounted) context.go('/auth/login');
            },
          ),
        ],
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (user) {
          if (user == null) {
            return Center(
              child: ElevatedButton(
                onPressed: () => context.go('/auth/login'),
                child: const Text('Iniciar sesión'),
              ),
            );
          }

          final rank = user.currentRank;
          final rankColor = RankUtils.rankColor(rank);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 40,
                  backgroundColor: TuM2Colors.primaryLight.withOpacity(0.2),
                  child: Text(
                    user.displayName.isNotEmpty
                        ? user.displayName[0].toUpperCase()
                        : '?',
                    style: TuM2TextStyles.headlineLarge
                        .copyWith(color: TuM2Colors.primary),
                  ),
                ),
                const SizedBox(height: 12),
                Text(user.displayName, style: TuM2TextStyles.headlineMedium),
                Text(user.email,
                    style: TuM2TextStyles.bodySmall
                        .copyWith(color: TuM2Colors.onSurfaceVariant)),
                const SizedBox(height: 16),

                // Rank badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: rankColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(100),
                    border:
                        Border.all(color: rankColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(RankUtils.rankEmoji(rank)),
                      const SizedBox(width: 8),
                      Text(rank,
                          style: TuM2TextStyles.labelLarge
                              .copyWith(color: rankColor)),
                      const SizedBox(width: 8),
                      Text(
                        '${user.xpPoints} XP',
                        style: TuM2TextStyles.bodySmall
                            .copyWith(color: rankColor),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  RankUtils.rankDescription(rank),
                  style: TuM2TextStyles.bodySmall
                      .copyWith(color: TuM2Colors.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),

                const Divider(height: 40),

                // Owner section
                if (user.isOwner) ...[
                  _ProfileSection(
                    title: 'Mi comercio',
                    child: _OwnerStoresSection(),
                  ),
                  const Divider(height: 32),
                ],

                // Account actions
                _ProfileSection(
                  title: 'Cuenta',
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.person_outline),
                        title: const Text('Editar perfil'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _ProfileSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TuM2TextStyles.titleMedium),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _OwnerStoresSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storesAsync = ref.watch(ownerStoresProvider);

    return storesAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator()),
      error: (e, _) => const SizedBox(),
      data: (stores) {
        if (stores.isEmpty) {
          return OutlinedButton.icon(
            onPressed: () => context.push('/tienda/crear'),
            icon: const Icon(Icons.add),
            label: const Text('Registrar mi comercio'),
          );
        }

        return Column(
          children: stores
              .map((s) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.storefront_outlined),
                    title: Text(s.name),
                    subtitle: Text(s.category),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        context.push('/tienda/${s.id}/panel'),
                  ))
              .toList(),
        );
      },
    );
  }
}
