import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/discover_filters.dart';
import '../providers/discover_providers.dart';
import '../../../../core/constants/app_constants.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(discoverFiltersProvider);
    final storesAsync = ref.watch(discoverStoresProvider);
    final userAsync = ref.watch(currentUserProvider);

    final isOwner = userAsync.valueOrNull?.isOwner ?? false;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            title: const Text('Buscar'),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(120),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  children: [
                    // Search bar
                    SearchBar(
                      controller: _searchController,
                      hintText: 'Buscar comercios, rubros...',
                      leading: const Icon(Icons.search),
                      onChanged: (q) {
                        ref
                            .read(discoverFiltersProvider.notifier)
                            .update((f) => f.copyWith(searchQuery: q));
                      },
                    ),
                    const SizedBox(height: 10),
                    // Filter chips
                    SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _FilterChip(
                            label: 'Abierto ahora',
                            selected: filters.openNow,
                            onSelected: (v) => ref
                                .read(discoverFiltersProvider.notifier)
                                .update((f) => f.copyWith(openNow: v)),
                          ),
                          _FilterChip(
                            label: '24 hs',
                            selected: filters.open24hs,
                            onSelected: (v) => ref
                                .read(discoverFiltersProvider.notifier)
                                .update((f) => f.copyWith(open24hs: v)),
                          ),
                          _FilterChip(
                            label: 'Hasta tarde',
                            selected: filters.lateNight,
                            onSelected: (v) => ref
                                .read(discoverFiltersProvider.notifier)
                                .update((f) => f.copyWith(lateNight: v)),
                          ),
                          _FilterChip(
                            label: 'Farmacia de turno',
                            selected: filters.onDutyToday,
                            onSelected: (v) => ref
                                .read(discoverFiltersProvider.notifier)
                                .update((f) => f.copyWith(onDutyToday: v)),
                          ),
                          _FilterChip(
                            label: 'Cerca mío',
                            selected: filters.nearMe,
                            onSelected: (v) => ref
                                .read(discoverFiltersProvider.notifier)
                                .update((f) => f.copyWith(nearMe: v)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          storesAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(child: Text('Error: $e')),
            ),
            data: (stores) {
              if (stores.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.storefront_outlined,
                            size: 64, color: TuM2Colors.onSurfaceVariant),
                        const SizedBox(height: 16),
                        Text(
                          filters.hasActiveFilters
                              ? 'No hay resultados con esos filtros.'
                              : 'El barrio está esperando sus primeros comercios.',
                          style: TuM2TextStyles.bodyMedium.copyWith(
                              color: TuM2Colors.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                        if (filters.hasActiveFilters) ...[
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => ref
                                .read(discoverFiltersProvider.notifier)
                                .state = const DiscoverFilters(),
                            child: const Text('Limpiar filtros'),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _StoreCard(
                      store: stores[i],
                      onTap: () =>
                          context.push('/tienda/${stores[i].id}'),
                    ),
                    childCount: stores.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: isOwner
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/tienda/crear'),
              icon: const Icon(Icons.add),
              label: const Text('Mi comercio'),
            )
          : null,
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: onSelected,
      ),
    );
  }
}

class _StoreCard extends StatelessWidget {
  final dynamic store;
  final VoidCallback onTap;

  const _StoreCard({required this.store, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: TuM2Colors.background,
          border: Border.all(color: TuM2Colors.outline),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: TuM2Colors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.storefront,
                  color: TuM2Colors.onSurfaceVariant),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(store.name, style: TuM2TextStyles.titleMedium),
                  Text(store.category,
                      style: TuM2TextStyles.bodySmall
                          .copyWith(color: TuM2Colors.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _StatusDot(isOpen: store.isOpenNow),
                      const SizedBox(width: 6),
                      Text(
                        store.isOpenNow ? 'Abierto' : 'Cerrado',
                        style: TuM2TextStyles.labelSmall.copyWith(
                          color: store.isOpenNow
                              ? TuM2Colors.openGreen
                              : TuM2Colors.closedRed,
                        ),
                      ),
                      if (store.isOnDutyToday) ...[
                        const SizedBox(width: 8),
                        const _MicroBadge(
                            label: 'Turno', color: TuM2Colors.dutyBlue),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: TuM2Colors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final bool isOpen;

  const _StatusDot({required this.isOpen});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: isOpen ? TuM2Colors.openGreen : TuM2Colors.closedRed,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _MicroBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _MicroBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(label,
          style: TuM2TextStyles.labelSmall.copyWith(color: color)),
    );
  }
}
