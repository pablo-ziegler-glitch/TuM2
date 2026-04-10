import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/search_filters.dart';
import '../providers/search_notifier.dart';
import '../widgets/merchant_search_card.dart';
import '../widgets/search_empty_state.dart';
import '../widgets/search_filters_sheet.dart';
import '../widgets/zone_selector_sheet.dart';

class SearchResultsScreen extends ConsumerStatefulWidget {
  const SearchResultsScreen({
    super.key,
    this.query = '',
    this.openNowFilter = false,
  });

  final String query;
  final bool openNowFilter;

  @override
  ConsumerState<SearchResultsScreen> createState() =>
      _SearchResultsScreenState();
}

class _SearchResultsScreenState extends ConsumerState<SearchResultsScreen> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final notifier = ref.read(searchNotifierProvider.notifier);
      await notifier.ensureInitialized();

      final initialQuery = widget.query.trim();
      if (initialQuery.isNotEmpty) {
        _controller.text = initialQuery;
        _controller.selection =
            TextSelection.collapsed(offset: initialQuery.length);
        notifier.setQuery(initialQuery);
        await notifier.submitQuery(initialQuery);
      }
      if (widget.openNowFilter) {
        final current = ref.read(searchNotifierProvider).filters;
        notifier.setFilters(current.copyWith(isOpenNow: true));
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submitSearch() {
    final query = _controller.text.trim();
    final notifier = ref.read(searchNotifierProvider.notifier);
    notifier.setQuery(query);
    notifier.submitQuery(query);
  }

  void _goToMap([String? merchantId]) {
    final notifier = ref.read(searchNotifierProvider.notifier);
    if (merchantId != null && merchantId.isNotEmpty) {
      notifier.selectMerchant(merchantId);
    }
    notifier.setShowMap(true);
    context.push(AppRoutes.searchMap);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchNotifierProvider);
    final notifier = ref.read(searchNotifierProvider.notifier);

    String zoneName = 'Tu zona';
    for (final zone in state.zones) {
      if (zone.zoneId == state.activeZoneId) {
        zoneName = zone.name;
        break;
      }
    }

    final visibleCount =
        state.corpus.where((e) => e.visibilityStatus == 'visible').length;
    final pendingCount = state.corpus
        .where((e) => e.visibilityStatus == 'review_pending')
        .length;
    final isColdStart = visibleCount < 3 && pendingCount > 0;
    final verifiedOnly = state.filters.minVerificationStatus == 'verified';

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      body: SafeArea(
        child: Column(
          children: [
            _ResultsTopBar(zoneName: zoneName),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.neutral200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 12),
                        const Icon(Icons.search,
                            color: AppColors.neutral600, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            textInputAction: TextInputAction.search,
                            onChanged: ref
                                .read(searchNotifierProvider.notifier)
                                .setQuery,
                            onSubmitted: (_) => _submitSearch(),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Buscar comercios...',
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => SearchFiltersSheet.show(context),
                          icon: const Icon(Icons.tune,
                              color: AppColors.primary500, size: 20),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _ResultFilterChip(
                          label: 'Verificados',
                          active: verifiedOnly,
                          onTap: () {
                            final next = verifiedOnly
                                ? state.filters
                                    .copyWith(clearMinVerificationStatus: true)
                                : state.filters.copyWith(
                                    minVerificationStatus: 'verified');
                            notifier.setFilters(next);
                          },
                        ),
                        const SizedBox(width: 8),
                        _ResultFilterChip(
                          label: 'Abierto ahora',
                          active: state.filters.isOpenNow,
                          onTap: () => notifier.setFilters(
                            state.filters
                                .copyWith(isOpenNow: !state.filters.isOpenNow),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _ResultFilterChip(
                          label: 'Zona: $zoneName',
                          active: true,
                          icon: Icons.location_on,
                          onTap: () => ZoneSelectorSheet.show(context),
                        ),
                        const SizedBox(width: 8),
                        _ResultFilterChip(
                          label: '',
                          icon: Icons.add,
                          compact: true,
                          onTap: () => SearchFiltersSheet.show(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: switch ((
                state.isLoading,
                state.error,
                state.results.isEmpty
              )) {
                (true, _, _) => const _ResultsLoadingList(),
                (_, final Object _, _) => _ErrorState(
                    onRetry: notifier.loadCorpus,
                  ),
                (_, _, true) => SearchEmptyState(
                    isColdStart: isColdStart,
                    query: state.query,
                    isZoneWithoutData: state.corpus.isEmpty,
                    openNowActive: state.filters.isOpenNow,
                  ),
                _ => Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${state.results.length} resultados encontrados',
                                style: AppTextStyles.bodySm.copyWith(
                                  color: AppColors.neutral700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            PopupMenuButton<SearchSortBy>(
                              onSelected: (sortBy) => notifier.setFilters(
                                state.filters.copyWith(sortBy: sortBy),
                              ),
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: SearchSortBy.sortBoost,
                                  child: Text('Relevancia'),
                                ),
                                PopupMenuItem(
                                  value: SearchSortBy.distance,
                                  child: Text('Distancia'),
                                ),
                                PopupMenuItem(
                                  value: SearchSortBy.name,
                                  child: Text('Nombre'),
                                ),
                              ],
                              child: Row(
                                children: [
                                  Text(
                                    'Relevancia',
                                    style: AppTextStyles.labelSm.copyWith(
                                      color: AppColors.primary500,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.expand_more,
                                    color: AppColors.primary500,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                          itemCount: state.results.length,
                          itemBuilder: (_, index) {
                            final item = state.results[index];
                            return MerchantSearchCard(
                              item: item,
                              imageSeed: index,
                              onTap: () {
                                notifier.logResultOpened(
                                  merchantId: item.merchantId,
                                  fromMap: false,
                                );
                                context.push(
                                  AppRoutes.commerceDetailPath(item.merchantId),
                                );
                              },
                              onMapTap: () {
                                notifier.logResultOpened(
                                  merchantId: item.merchantId,
                                  fromMap: false,
                                );
                                _goToMap(item.merchantId);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
              },
            ),
          ],
        ),
      ),
      floatingActionButton: state.isLoading || state.results.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _goToMap,
              backgroundColor: const Color(0xFF2F3130),
              foregroundColor: AppColors.surface,
              icon: const Icon(Icons.map_outlined),
              label: const Text('Ver mapa'),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class _ResultsTopBar extends StatelessWidget {
  const _ResultsTopBar({required this.zoneName});

  final String zoneName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: AppColors.primary500, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              zoneName,
              style: AppTextStyles.headingSm.copyWith(
                color: AppColors.neutral700,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            'TuM2',
            style: AppTextStyles.headingSm.copyWith(
              color: AppColors.primary500,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: AppColors.neutral200,
              shape: BoxShape.circle,
            ),
            child:
                const Icon(Icons.person, size: 18, color: AppColors.neutral700),
          ),
        ],
      ),
    );
  }
}

class _ResultFilterChip extends StatelessWidget {
  const _ResultFilterChip({
    required this.label,
    required this.onTap,
    this.active = false,
    this.icon,
    this.compact = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool active;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 14,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: active ? AppColors.secondary500 : AppColors.neutral100,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: active ? AppColors.surface : AppColors.neutral700,
              ),
              if (!compact) const SizedBox(width: 6),
            ],
            if (!compact)
              Text(
                label,
                style: AppTextStyles.labelSm.copyWith(
                  color: active ? AppColors.surface : AppColors.neutral700,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ResultsLoadingList extends StatelessWidget {
  const _ResultsLoadingList();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: const [
        _ResultSkeleton(height: 250),
        SizedBox(height: 14),
        _ResultSkeleton(height: 250),
        SizedBox(height: 14),
        _ResultSkeleton(height: 250),
      ],
    );
  }
}

class _ResultSkeleton extends StatelessWidget {
  const _ResultSkeleton({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.neutral100,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.onRetry,
  });

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 44, color: AppColors.neutral500),
            const SizedBox(height: 10),
            const Text('Sin conexión. Revisá tu red.',
                style: AppTextStyles.headingSm),
            const SizedBox(height: 8),
            const Text(
              'No pudimos cargar los resultados en este momento. Probá de nuevo en unos segundos.',
              style: AppTextStyles.bodyXs,
              maxLines: 3,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
