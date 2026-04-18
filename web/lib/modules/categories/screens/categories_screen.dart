import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/categories_admin_repository.dart';

const _categoryIdRegex = r'^[a-z0-9]+(?:_[a-z0-9]+)*$';

String _canonicalCategoryToken(String raw) {
  final normalized = raw.trim().toLowerCase();
  if (normalized == 'vet') return 'veterinary';
  return normalized;
}

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key, CategoriesAdminDataSource? repository})
      : repository = repository ?? const _DefaultCategoriesRepository();

  final CategoriesAdminDataSource repository;

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

abstract class CategoriesAdminDataSource {
  Future<CategoryAdminPage> list({
    required int limit,
    String? cursor,
    bool includeInactive = true,
  });

  Future<CategoryAdminItem> upsert(UpsertCategoryInput input);

  Future<void> toggleActive({
    required String categoryId,
    required bool isActive,
  });
}

class _DefaultCategoriesRepository implements CategoriesAdminDataSource {
  const _DefaultCategoriesRepository();

  CategoriesAdminRepository get _repo => CategoriesAdminRepository();

  @override
  Future<CategoryAdminPage> list({
    required int limit,
    String? cursor,
    bool includeInactive = true,
  }) {
    return _repo.list(limit: limit, cursor: cursor, includeInactive: includeInactive);
  }

  @override
  Future<void> toggleActive({
    required String categoryId,
    required bool isActive,
  }) {
    return _repo.toggleActive(categoryId: categoryId, isActive: isActive);
  }

  @override
  Future<CategoryAdminItem> upsert(UpsertCategoryInput input) {
    return _repo.upsert(input);
  }
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  static const _pageSize = 20;

  final List<CategoryAdminItem> _items = <CategoryAdminItem>[];
  final Set<String> _togglingIds = <String>{};
  bool _loading = true;
  bool _loadingMore = false;
  bool _submitting = false;
  String? _nextCursor;
  String? _error;
  bool _includeInactive = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
      _nextCursor = null;
      _items.clear();
    });
    try {
      final page = await widget.repository.list(
        limit: _pageSize,
        includeInactive: _includeInactive,
      );
      if (!mounted) return;
      setState(() {
        _mergeItems(page.items, reset: true);
        _nextCursor = page.nextCursor;
      });
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message ?? 'No pudimos cargar categorías.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No pudimos cargar categorías.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    final cursor = _nextCursor;
    if (_loadingMore || cursor == null) return;
    setState(() => _loadingMore = true);
    try {
      final page = await widget.repository.list(
        limit: _pageSize,
        cursor: cursor,
        includeInactive: _includeInactive,
      );
      if (!mounted) return;
      setState(() {
        _mergeItems(page.items);
        _nextCursor = page.nextCursor;
      });
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      _showSnack(error.message ?? 'No pudimos cargar más categorías.', isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack('No pudimos cargar más categorías.', isError: true);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _openCreateDialog() async {
    final result = await showDialog<UpsertCategoryInput>(
      context: context,
      builder: (context) => const _CategoryDialog(),
    );
    if (result == null) return;
    await _saveCategory(result);
  }

  Future<void> _openEditDialog(CategoryAdminItem item) async {
    final result = await showDialog<UpsertCategoryInput>(
      context: context,
      builder: (context) => _CategoryDialog(initial: item),
    );
    if (result == null) return;
    await _saveCategory(result);
  }

  Future<void> _saveCategory(UpsertCategoryInput input) async {
    setState(() => _submitting = true);
    try {
      final updated = await widget.repository.upsert(input);
      if (!mounted) return;
      setState(() {
        _mergeItems([updated]);
      });
      _showSnack('Categoría guardada.');
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      _showSnack(error.message ?? 'No se pudo guardar la categoría.', isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack('No se pudo guardar la categoría.', isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _toggleActive(CategoryAdminItem item, bool nextState) async {
    if (_togglingIds.contains(item.categoryId)) return;
    setState(() => _togglingIds.add(item.categoryId));
    try {
      await widget.repository.toggleActive(
        categoryId: item.categoryId,
        isActive: nextState,
      );
      if (!mounted) return;
      final index = _items.indexWhere((row) => row.categoryId == item.categoryId);
      if (index >= 0) {
        setState(() {
          _items[index] = CategoryAdminItem(
            categoryId: item.categoryId,
            label: item.label,
            iconName: item.iconName,
            aliases: item.aliases,
            isActive: nextState,
            productLimit: item.productLimit,
            updatedAtMillis: item.updatedAtMillis,
          );
        });
      }
      _showSnack(nextState ? 'Categoría activada.' : 'Categoría desactivada.');
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      _showSnack(error.message ?? 'No pudimos actualizar el estado.', isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack('No pudimos actualizar el estado.', isError: true);
    } finally {
      if (mounted) {
        setState(() => _togglingIds.remove(item.categoryId));
      }
    }
  }

  void _mergeItems(List<CategoryAdminItem> incoming, {bool reset = false}) {
    final byId = <String, CategoryAdminItem>{
      if (!reset) for (final item in _items) item.categoryId: item,
    };
    for (final item in incoming) {
      byId[item.categoryId] = item;
    }
    _items
      ..clear()
      ..addAll(byId.values)
      ..sort((left, right) => left.categoryId.compareTo(right.categoryId));
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.errorFg : AppColors.secondary600,
      ),
    );
  }

  String _formatUpdatedAt(int? millis) {
    if (millis == null) return '—';
    final date = DateTime.fromMillisecondsSinceEpoch(millis);
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Categorías', style: AppTextStyles.headingMd),
                      const SizedBox(height: 4),
                      Text(
                        'Administrá categoryId canónico, aliases y estado activo.',
                        style: AppTextStyles.bodySm,
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: _submitting ? null : _openCreateDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Nueva categoría'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.neutral200),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Limitaciones de productos por categoría y overrides de comercio.',
                      style: AppTextStyles.bodySm,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/businesses'),
                    icon: const Icon(Icons.tune),
                    label: const Text('Abrir límites'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Switch(
                  value: _includeInactive,
                  onChanged: (value) {
                    setState(() => _includeInactive = value);
                    _reload();
                  },
                ),
                Text(
                  'Mostrar inactivas',
                  style: AppTextStyles.bodySm.copyWith(color: AppColors.neutral800),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _loading ? null : _reload,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Recargar'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.neutral200),
                ),
                child: _buildContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            style: AppTextStyles.bodySm.copyWith(color: AppColors.errorFg),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      if (_nextCursor != null) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'No hubo resultados en esta página con el filtro actual.',
                style: AppTextStyles.bodySm,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _loadingMore ? null : _loadMore,
                icon: const Icon(Icons.expand_more),
                label: const Text('Buscar más'),
              ),
            ],
          ),
        );
      }
      return const Center(
        child: Text('No hay categorías cargadas.', style: AppTextStyles.bodySm),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemBuilder: (context, index) {
        if (index == _items.length) {
          return Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _loadingMore ? null : _loadMore,
              icon: _loadingMore
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more),
              label: const Text('Cargar más'),
            ),
          );
        }
        final item = _items[index];
        return _CategoryRow(
          item: item,
          isToggling: _togglingIds.contains(item.categoryId),
          updatedAtLabel: _formatUpdatedAt(item.updatedAtMillis),
          onEdit: () => _openEditDialog(item),
          onToggle: (value) => _toggleActive(item, value),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemCount: _nextCursor == null ? _items.length : _items.length + 1,
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.item,
    required this.isToggling,
    required this.updatedAtLabel,
    required this.onEdit,
    required this.onToggle,
  });

  final CategoryAdminItem item;
  final bool isToggling;
  final String updatedAtLabel;
  final VoidCallback onEdit;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.neutral50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${item.label} (${item.categoryId})',
                  style: AppTextStyles.labelMd,
                ),
              ),
              Switch(
                value: item.isActive,
                onChanged: isToggling ? null : onToggle,
              ),
              const SizedBox(width: 6),
              OutlinedButton(
                onPressed: onEdit,
                child: const Text('Editar'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _Tag(text: item.isActive ? 'Activa' : 'Inactiva'),
              _Tag(text: 'iconName: ${item.iconName}'),
              _Tag(
                text: item.productLimit == null
                    ? 'Límite: global'
                    : 'Límite: ${item.productLimit}',
              ),
              _Tag(text: 'Actualizada: $updatedAtLabel'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.aliases.isEmpty ? 'Aliases: —' : 'Aliases: ${item.aliases.join(', ')}',
            style: AppTextStyles.bodyXs,
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.infoBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: AppTextStyles.bodyXs),
    );
  }
}

class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog({this.initial});

  final CategoryAdminItem? initial;

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _categoryIdController;
  late final TextEditingController _labelController;
  late final TextEditingController _iconNameController;
  late final TextEditingController _aliasesController;
  late bool _isActive;

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _categoryIdController = TextEditingController(text: initial?.categoryId ?? '');
    _labelController = TextEditingController(text: initial?.label ?? '');
    _iconNameController = TextEditingController(text: initial?.iconName ?? 'store');
    _aliasesController =
        TextEditingController(text: initial?.aliases.join(', ') ?? '');
    _isActive = initial?.isActive ?? true;
  }

  @override
  void dispose() {
    _categoryIdController.dispose();
    _labelController.dispose();
    _iconNameController.dispose();
    _aliasesController.dispose();
    super.dispose();
  }

  List<String> _parseAliases() {
    final raw = _aliasesController.text.trim();
    if (raw.isEmpty) return const [];
    final values = raw
        .split(',')
        .map(_canonicalCategoryToken)
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    values.sort();
    return values;
  }

  String? _validateCategoryId(String? value) {
    final normalized = _canonicalCategoryToken(value ?? '');
    if (normalized.isEmpty) return 'Ingresá categoryId.';
    if (!RegExp(_categoryIdRegex).hasMatch(normalized)) {
      return 'Usá minúsculas, números y "_" (sin espacios).';
    }
    return null;
  }

  String? _validateAliases(String? _) {
    final aliases = _parseAliases();
    final categoryId = _canonicalCategoryToken(_categoryIdController.text);
    final seen = <String>{};
    for (final alias in aliases) {
      if (!RegExp(_categoryIdRegex).hasMatch(alias)) {
        return 'Alias inválido: $alias';
      }
      if (alias == categoryId) {
        return 'Un alias no puede ser igual al categoryId.';
      }
      if (!seen.add(alias)) {
        return 'Alias duplicado: $alias';
      }
    }
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final payload = UpsertCategoryInput(
      categoryId: _canonicalCategoryToken(_categoryIdController.text),
      label: _labelController.text.trim(),
      iconName: _iconNameController.text.trim().toLowerCase(),
      aliases: _parseAliases(),
      isActive: _isActive,
    );
    Navigator.of(context).pop(payload);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Editar categoría' : 'Nueva categoría'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _categoryIdController,
                enabled: !_isEdit,
                decoration: const InputDecoration(
                  labelText: 'categoryId canónico',
                  hintText: 'ej: prepared_food',
                ),
                validator: _validateCategoryId,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _labelController,
                decoration: const InputDecoration(labelText: 'Etiqueta'),
                validator: (value) {
                  final normalized = (value ?? '').trim();
                  if (normalized.length < 2) return 'Mínimo 2 caracteres.';
                  if (normalized.length > 80) return 'Máximo 80 caracteres.';
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _iconNameController,
                decoration: const InputDecoration(
                  labelText: 'iconName',
                  hintText: 'store, pets, local_pharmacy...',
                ),
                validator: (value) {
                  final normalized = (value ?? '').trim().toLowerCase();
                  if (normalized.isEmpty) return 'Ingresá iconName.';
                  if (!RegExp(r'^[a-z0-9_]{2,40}$').hasMatch(normalized)) {
                    return 'Formato inválido.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _aliasesController,
                decoration: const InputDecoration(
                  labelText: 'Aliases (separados por coma)',
                  hintText: 'ej: veterinaria, vet_shop',
                ),
                validator: _validateAliases,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value),
                title: const Text('Categoría activa'),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
