import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/search_filters.dart';
import '../providers/search_notifier.dart';

class SearchFiltersSheet extends ConsumerStatefulWidget {
  const SearchFiltersSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const SearchFiltersSheet(),
    );
  }

  @override
  ConsumerState<SearchFiltersSheet> createState() => _SearchFiltersSheetState();
}

class _SearchFiltersSheetState extends ConsumerState<SearchFiltersSheet> {
  late SearchFilters _filters;

  @override
  void initState() {
    super.initState();
    _filters = ref.read(searchNotifierProvider).filters;
  }

  @override
  Widget build(BuildContext context) {
    final corpus = ref.watch(searchNotifierProvider).corpus;
    final categories = corpus
        .map((e) => e.categoryId)
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Filtros', style: AppTextStyles.headingSm),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                key: ValueKey('category-${_filters.categoryId ?? 'all'}'),
                initialValue: _filters.categoryId,
                decoration: const InputDecoration(labelText: 'Categoría'),
                items: [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('Todos')),
                  ...categories.map((c) =>
                      DropdownMenuItem<String?>(value: c, child: Text(c))),
                ],
                onChanged: (value) => setState(() {
                  _filters = _filters.copyWith(
                      categoryId: value, clearCategory: value == null);
                }),
              ),
              SwitchListTile(
                title: const Text('Abierto ahora'),
                value: _filters.isOpenNow,
                onChanged: (v) =>
                    setState(() => _filters = _filters.copyWith(isOpenNow: v)),
              ),
              DropdownButtonFormField<String?>(
                key: ValueKey(
                  'verification-${_filters.minVerificationStatus ?? 'all'}',
                ),
                initialValue: _filters.minVerificationStatus,
                decoration: const InputDecoration(
                    labelText: 'Nivel mínimo verificación'),
                items: const [
                  DropdownMenuItem<String?>(
                      value: null, child: Text('Cualquiera')),
                  DropdownMenuItem<String?>(
                      value: 'referential', child: Text('Referencial o más')),
                  DropdownMenuItem<String?>(
                      value: 'claimed', child: Text('Reclamado o más')),
                  DropdownMenuItem<String?>(
                      value: 'validated', child: Text('Validado o más')),
                  DropdownMenuItem<String?>(
                      value: 'verified', child: Text('Verificado')),
                ],
                onChanged: (value) => setState(() {
                  _filters = _filters.copyWith(
                    minVerificationStatus: value,
                    clearMinVerificationStatus: value == null,
                  );
                }),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<SearchSortBy>(
                key: ValueKey('sort-${_filters.sortBy.name}'),
                initialValue: _filters.sortBy,
                decoration: const InputDecoration(labelText: 'Ordenar por'),
                items: const [
                  DropdownMenuItem(
                      value: SearchSortBy.distance, child: Text('Distancia')),
                  DropdownMenuItem(
                      value: SearchSortBy.sortBoost, child: Text('Relevancia')),
                  DropdownMenuItem(
                      value: SearchSortBy.name, child: Text('Nombre')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _filters = _filters.copyWith(sortBy: value));
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() => _filters = SearchFilters.empty);
                      },
                      child: const Text('Limpiar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary500,
                        foregroundColor: AppColors.surface,
                      ),
                      onPressed: () {
                        ref
                            .read(searchNotifierProvider.notifier)
                            .setFilters(_filters);
                        Navigator.of(context).pop();
                      },
                      child: const Text('Aplicar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
