import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/search_filters.dart';
import '../providers/search_notifier.dart';
import '../widgets/category_chips_row.dart';
import '../widgets/merchant_search_card.dart';
import '../widgets/search_empty_state.dart';
import '../widgets/search_filters_sheet.dart';
import '../widgets/search_results_map.dart';

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
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final notifier = ref.read(searchNotifierProvider.notifier);
      await notifier.ensureInitialized();
      if (widget.query.trim().isNotEmpty) {
        notifier.setQuery(widget.query.trim());
        await notifier.submitQuery(widget.query.trim());
      }
      if (widget.openNowFilter) {
        final current = ref.read(searchNotifierProvider).filters;
        notifier.setFilters(current.copyWith(isOpenNow: true));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchNotifierProvider);
    final notifier = ref.read(searchNotifierProvider.notifier);
    final categories = state.corpus
        .map((e) => e.categoryId)
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final visibleCount =
        state.corpus.where((e) => e.visibilityStatus == 'visible').length;
    final pendingCount = state.corpus
        .where((e) => e.visibilityStatus == 'review_pending')
        .length;
    final isColdStart = visibleCount < 3 && pendingCount > 0;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: Text(state.query.isEmpty ? 'Resultados' : state.query),
        actions: [
          IconButton(
            onPressed: () => SearchFiltersSheet.show(context),
            icon: const Icon(Icons.tune_rounded),
          ),
          IconButton(
            onPressed: notifier.toggleMap,
            icon: Icon(state.showMap ? Icons.view_list : Icons.map_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          CategoryChipsRow(
            categories: categories.take(7).toList(),
            selectedCategoryId: state.filters.categoryId,
            onSelected: (categoryId) {
              final next = state.filters.copyWith(
                categoryId: categoryId,
                clearCategory: categoryId == null,
              );
              notifier.setFilters(next);
            },
          ),
          if (state.filters.isOpenNow ||
              state.filters.minVerificationStatus != null ||
              state.filters.categoryId != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Wrap(
                spacing: 8,
                children: [
                  if (state.filters.categoryId != null)
                    _activeChip('Categoria: ${state.filters.categoryId}'),
                  if (state.filters.isOpenNow) _activeChip('Abierto ahora'),
                  if (state.filters.minVerificationStatus != null)
                    _activeChip(
                        'Verificación: ${state.filters.minVerificationStatus}'),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: switch ((
              state.isLoading,
              state.error,
              state.results.isEmpty,
              state.showMap
            )) {
              (true, _, _, _) =>
                const Center(child: CircularProgressIndicator()),
              (_, final Object error?, _, _) => _ErrorState(
                  error: error,
                  onRetry: notifier.loadCorpus,
                ),
              (_, _, _, true) => SearchResultsMap(
                  items: state.results,
                  selectedMerchantId: state.selectedMerchantId,
                  onPinTap: notifier.selectMerchant,
                  onCardTap: (merchantId) {
                    notifier.logResultOpened(
                      merchantId: merchantId,
                      fromMap: true,
                    );
                    context.push(AppRoutes.commerceDetailPath(merchantId));
                  },
                ),
              (_, _, true, _) => SearchEmptyState(
                  isColdStart: isColdStart,
                  query: state.query,
                  isZoneWithoutData: state.corpus.isEmpty,
                  openNowActive: state.filters.isOpenNow,
                ),
              _ => ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: state.results.length,
                  itemBuilder: (_, i) {
                    final item = state.results[i];
                    return MerchantSearchCard(
                      item: item,
                      onTap: () {
                        notifier.logResultOpened(
                          merchantId: item.merchantId,
                          fromMap: false,
                        );
                        context.push(
                            AppRoutes.commerceDetailPath(item.merchantId));
                      },
                    );
                  },
                ),
            },
          ),
        ],
      ),
      bottomNavigationBar: state.showMap
          ? null
          : Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Row(
                children: [
                  Text(
                    '${state.results.length} resultados',
                    style: AppTextStyles.bodySm,
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: notifier.toggleMap,
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Ver mapa'),
                  ),
                  PopupMenuButton<SearchSortBy>(
                    icon: const Icon(Icons.sort),
                    onSelected: (sortBy) => notifier
                        .setFilters(state.filters.copyWith(sortBy: sortBy)),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: SearchSortBy.distance,
                        child: Text('Distancia'),
                      ),
                      PopupMenuItem(
                        value: SearchSortBy.sortBoost,
                        child: Text('Relevancia'),
                      ),
                      PopupMenuItem(
                        value: SearchSortBy.name,
                        child: Text('Nombre'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _activeChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: AppTextStyles.bodyXs.copyWith(color: AppColors.primary600)),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.error,
    required this.onRetry,
  });

  final Object error;
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
            Text('Sin conexión. Revisá tu red.',
                style: AppTextStyles.headingSm),
            const SizedBox(height: 8),
            Text(error.toString(), style: AppTextStyles.bodyXs, maxLines: 3),
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
