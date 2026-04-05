import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../providers/search_history_provider.dart';
import '../providers/search_notifier.dart';
import '../widgets/category_chips_row.dart';
import '../widgets/search_filters_sheet.dart';
import '../widgets/zone_selector_sheet.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(searchNotifierProvider.notifier).ensureInitialized());
    _controller.addListener(() {
      ref.read(searchNotifierProvider.notifier).setQuery(_controller.text);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goToResults([String? query]) {
    final q = (query ?? _controller.text).trim();
    if (q.isEmpty) return;
    ref.read(searchNotifierProvider.notifier).submitQuery(q);
    context.push('${AppRoutes.searchResults}?q=${Uri.encodeComponent(q)}');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchNotifierProvider);
    final history = ref.watch(searchHistoryProvider);
    final categories = state.corpus
        .map((e) => e.categoryId)
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final hasTyping = state.query.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.search,
                      onSubmitted: _goToResults,
                      decoration: InputDecoration(
                        hintText: 'Buscar comercios',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: hasTyping
                            ? IconButton(
                                onPressed: () {
                                  _controller.clear();
                                  ref
                                      .read(searchNotifierProvider.notifier)
                                      .setQuery('');
                                },
                                icon: const Icon(Icons.close),
                              )
                            : null,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => SearchFiltersSheet.show(context),
                    icon: const Icon(Icons.tune_rounded),
                  ),
                  IconButton(
                    onPressed: () => ZoneSelectorSheet.show(context),
                    icon: const Icon(Icons.location_on_outlined),
                  ),
                ],
              ),
            ),
            CategoryChipsRow(
              categories: categories.take(7).toList(),
              selectedCategoryId: state.filters.categoryId,
              onSelected: (categoryId) {
                final next = state.filters.copyWith(
                  categoryId: categoryId,
                  clearCategory: categoryId == null,
                );
                ref.read(searchNotifierProvider.notifier).setFilters(next);
              },
            ),
            const SizedBox(height: 8),
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        Text(
                          'Zona activa: ${state.activeZoneId.isEmpty ? 'sin definir' : state.activeZoneId}',
                          style: AppTextStyles.bodySm,
                        ),
                        const SizedBox(height: 12),
                        if (hasTyping) ...[
                          Text('Sugerencias', style: AppTextStyles.headingSm),
                          const SizedBox(height: 6),
                          ...state.suggestions.take(5).map(
                                (item) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.search),
                                  title: Text(item.name),
                                  subtitle: Text(item.categoryLabel.isEmpty
                                      ? item.categoryId
                                      : item.categoryLabel),
                                  onTap: () {
                                    _controller.text = item.name;
                                    _controller.selection =
                                        TextSelection.collapsed(
                                      offset: _controller.text.length,
                                    );
                                    _goToResults(item.name);
                                  },
                                ),
                              ),
                        ] else ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Búsquedas recientes',
                                  style: AppTextStyles.headingSm),
                              TextButton(
                                onPressed: () => ref
                                    .read(searchNotifierProvider.notifier)
                                    .clearHistory(),
                                child: const Text('Limpiar'),
                              ),
                            ],
                          ),
                          ...history.take(5).map(
                                (term) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.history),
                                  title: Text(term),
                                  onTap: () {
                                    _controller.text = term;
                                    _controller.selection =
                                        TextSelection.collapsed(
                                      offset: _controller.text.length,
                                    );
                                    _goToResults(term);
                                  },
                                ),
                              ),
                          if (history.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Todavía no tenés búsquedas guardadas.',
                                style: AppTextStyles.bodySm,
                              ),
                            ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _goToResults,
        backgroundColor: AppColors.primary500,
        foregroundColor: AppColors.surface,
        icon: const Icon(Icons.arrow_forward),
        label: const Text('Ver resultados'),
      ),
    );
  }
}
