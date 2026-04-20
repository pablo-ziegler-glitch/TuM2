import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

const _kCatalogLimitPresets = <int>[50, 100, 200, 300, 500, 1000];

const _kCatalogCategories = <_CatalogCategory>[
  _CatalogCategory(id: 'farmacia', label: 'Farmacias', icon: Icons.medication),
  _CatalogCategory(id: 'kiosco', label: 'Kioscos', icon: Icons.storefront),
  _CatalogCategory(
    id: 'almacen',
    label: 'Almacenes',
    icon: Icons.shopping_basket,
  ),
  _CatalogCategory(id: 'veterinaria', label: 'Veterinarias', icon: Icons.pets),
  _CatalogCategory(
    id: 'casa_de_comidas',
    label: 'Casas de comida / Rotiserías',
    icon: Icons.restaurant,
  ),
  _CatalogCategory(
    id: 'comida_al_paso',
    label: 'Tiendas de comida al paso',
    icon: Icons.lunch_dining,
  ),
  _CatalogCategory(id: 'gomeria', label: 'Gomerías', icon: Icons.tire_repair),
];

enum _CatalogSection { global, category, merchant }

enum _MerchantFilter { all, overThreshold, withOverride }

class CatalogLimitsScreen extends StatefulWidget {
  const CatalogLimitsScreen({super.key});

  @override
  State<CatalogLimitsScreen> createState() => _CatalogLimitsScreenState();
}

class _CatalogLimitsScreenState extends State<CatalogLimitsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  final TextEditingController _globalLimitController = TextEditingController();
  final TextEditingController _categoryLimitController =
      TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  bool _loadingConfig = true;
  bool _savingGlobal = false;
  bool _savingCategory = false;
  bool _searchingMerchants = false;

  String _selectedCategoryId = _kCatalogCategories.first.id;
  _CatalogSection _section = _CatalogSection.global;
  _MerchantFilter _merchantFilter = _MerchantFilter.all;

  _CatalogLimitsConfig _config = _CatalogLimitsConfig.empty();
  List<_CatalogMerchantRow> _searchRows = const [];
  String? _searchMessage;

  @override
  void initState() {
    super.initState();
    _reloadConfig();
  }

  @override
  void dispose() {
    _globalLimitController.dispose();
    _categoryLimitController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reloadConfig() async {
    setState(() => _loadingConfig = true);
    try {
      final config = await _readCatalogConfig();
      if (!mounted) return;
      setState(() {
        _config = config;
        _globalLimitController.text = config.defaultProductLimit.toString();
        final categoryLimit = config.categoryLimits[_selectedCategoryId];
        _categoryLimitController.text =
            categoryLimit == null ? '' : categoryLimit.toString();
      });
    } catch (error) {
      if (!mounted) return;
      _showError('No pudimos cargar la configuración de catálogo.', error);
    } finally {
      if (mounted) setState(() => _loadingConfig = false);
    }
  }

  Future<_CatalogLimitsConfig> _readCatalogConfig() async {
    final snapshot = await _firestore.doc('admin_configs/catalog_limits').get();
    if (!snapshot.exists) return _CatalogLimitsConfig.empty();
    return _CatalogLimitsConfig.fromMap(snapshot.data() ?? const {});
  }

  Future<void> _saveGlobalLimit() async {
    final limit = _parseLimit(_globalLimitController.text);
    if (limit == null) {
      _showSnack('Ingresá un entero positivo válido.', isError: true);
      return;
    }

    setState(() => _savingGlobal = true);
    try {
      await _functions.httpsCallable('setGlobalCatalogProductLimit').call(
        <String, dynamic>{'defaultProductLimit': limit},
      );
      if (!mounted) return;
      _showSnack('Límite global actualizado.');
      await _reloadConfig();
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      _showError(
        'No se pudo guardar el límite global.',
        error.message ?? error,
      );
    } catch (error) {
      if (!mounted) return;
      _showError('No se pudo guardar el límite global.', error);
    } finally {
      if (mounted) setState(() => _savingGlobal = false);
    }
  }

  Future<void> _saveCategoryLimit() async {
    final limit = _parseLimit(_categoryLimitController.text);
    if (limit == null) {
      _showSnack('Ingresá un entero positivo válido.', isError: true);
      return;
    }

    setState(() => _savingCategory = true);
    try {
      await _functions.httpsCallable('setCategoryCatalogProductLimit').call(
        <String, dynamic>{
          'categoryId': _selectedCategoryId,
          'productLimit': limit,
        },
      );
      if (!mounted) return;
      _showSnack('Límite por categoría actualizado.');
      await _reloadConfig();
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      _showError(
        'No se pudo guardar el límite de categoría.',
        error.message ?? error,
      );
    } catch (error) {
      if (!mounted) return;
      _showError('No se pudo guardar el límite de categoría.', error);
    } finally {
      if (mounted) setState(() => _savingCategory = false);
    }
  }

  Future<void> _clearCategoryLimit() async {
    setState(() => _savingCategory = true);
    try {
      await _functions.httpsCallable('clearCategoryCatalogProductLimit').call(
        <String, dynamic>{'categoryId': _selectedCategoryId},
      );
      if (!mounted) return;
      _showSnack('Límite por categoría limpiado.');
      await _reloadConfig();
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      _showError(
        'No se pudo limpiar el límite de categoría.',
        error.message ?? error,
      );
    } catch (error) {
      if (!mounted) return;
      _showError('No se pudo limpiar el límite de categoría.', error);
    } finally {
      if (mounted) setState(() => _savingCategory = false);
    }
  }

  Future<void> _searchMerchants() async {
    final query = _searchController.text.trim();
    if (query.length < 2) {
      setState(() {
        _searchRows = const [];
        _searchMessage = 'Ingresá al menos 2 caracteres para buscar.';
      });
      return;
    }

    setState(() {
      _searchingMerchants = true;
      _searchMessage = null;
    });

    try {
      final response = await _functions
          .httpsCallable('searchCatalogLimitMerchants')
          .call(<String, dynamic>{'query': query, 'limit': 20});
      final data = (response.data as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};
      final rows = ((data['merchants'] as List?) ?? const <dynamic>[])
          .whereType<Map>()
          .map(
            (row) => _CatalogMerchantRow.fromMap(row.cast<String, dynamic>()),
          )
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        _searchRows = rows;
        _searchMessage =
            rows.isEmpty ? 'Sin coincidencias para "$query".' : null;
      });
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      _showError('No se pudo buscar comercios.', error.message ?? error);
      setState(() {
        _searchRows = const [];
        _searchMessage = 'No pudimos buscar comercios.';
      });
    } catch (error) {
      if (!mounted) return;
      _showError('No se pudo buscar comercios.', error);
      setState(() {
        _searchRows = const [];
        _searchMessage = 'No pudimos buscar comercios.';
      });
    } finally {
      if (mounted) setState(() => _searchingMerchants = false);
    }
  }

  Future<void> _openOverrideDialog(_CatalogMerchantRow row) async {
    final controller = TextEditingController(
      text: row.overrideLimit?.toString() ?? '',
    );
    var saving = false;
    final categoryLimit = _config.categoryLimits[row.categoryId];

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> onSavePressed() async {
              final limit = _parseLimit(controller.text);
              if (limit == null) {
                _showSnack('Ingresá un entero positivo válido.', isError: true);
                return;
              }
              setModalState(() => saving = true);
              try {
                await _functions
                    .httpsCallable('setMerchantCatalogLimitOverride')
                    .call(<String, dynamic>{
                  'merchantId': row.merchantId,
                  'productLimitOverride': limit,
                });
                if (!context.mounted) return;
                Navigator.of(context).pop(true);
              } on FirebaseFunctionsException catch (error) {
                if (!context.mounted) return;
                _showError(
                  'No se pudo guardar override.',
                  error.message ?? error,
                );
              } catch (error) {
                if (!context.mounted) return;
                _showError('No se pudo guardar override.', error);
              } finally {
                if (context.mounted) setModalState(() => saving = false);
              }
            }

            Future<void> onClearPressed() async {
              setModalState(() => saving = true);
              try {
                await _functions
                    .httpsCallable('clearMerchantCatalogLimitOverride')
                    .call(<String, dynamic>{'merchantId': row.merchantId});
                if (!context.mounted) return;
                Navigator.of(context).pop(true);
              } on FirebaseFunctionsException catch (error) {
                if (!context.mounted) return;
                _showError(
                  'No se pudo limpiar override.',
                  error.message ?? error,
                );
              } catch (error) {
                if (!context.mounted) return;
                _showError('No se pudo limpiar override.', error);
              } finally {
                if (context.mounted) setModalState(() => saving = false);
              }
            }

            return AlertDialog(
              titlePadding: const EdgeInsets.fromLTRB(24, 18, 24, 4),
              contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
              actionsPadding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Override individual',
                    style: AppTextStyles.headingSm.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    row.name,
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.neutral700,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 540,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InlineAdminMessage(
                      text:
                          'Jerarquía activa: override individual > categoría > global. Si limpiás el override, vuelve a herencia.',
                      isError: false,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _CompactMetricChip(
                          label: 'Categoría',
                          value: _categoryLabelById(row.categoryId),
                        ),
                        _CompactMetricChip(
                          label: 'Uso',
                          value:
                              '${row.activeProductCount}/${row.effectiveLimit}',
                        ),
                        _CompactMetricChip(
                          label: 'Límite global',
                          value: '${_config.defaultProductLimit}',
                        ),
                        _CompactMetricChip(
                          label: 'Límite categoría',
                          value: categoryLimit == null
                              ? 'Hereda global'
                              : '$categoryLimit',
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (row.isBlocked)
                      const _InlineAdminMessage(
                        text:
                            'El comercio está por encima del límite. Podrá editar o desactivar productos, pero no crear nuevos.',
                        isError: true,
                      )
                    else if (row.isWarning)
                      const _InlineAdminMessage(
                        text:
                            'El comercio está por encima del 80% de uso. Considerá validar necesidad de override.',
                        isError: false,
                      ),
                    if (row.isBlocked || row.isWarning)
                      const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Límite individual',
                        hintText: 'Ej: 300',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _kCatalogLimitPresets
                          .map(
                            (limit) => OutlinedButton(
                              onPressed: saving
                                  ? null
                                  : () => setModalState(
                                        () => controller.text = '$limit',
                                      ),
                              child: Text('$limit'),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                TextButton.icon(
                  onPressed: saving ? null : onClearPressed,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Usar herencia'),
                ),
                FilledButton.icon(
                  onPressed: saving ? null : onSavePressed,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Guardar override'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      _showSnack('Override actualizado.');
      await _reloadConfig();
      await _searchMerchants();
    }
  }

  int? _parseLimit(String input) {
    final value = int.tryParse(input.trim());
    if (value == null || value <= 0) return null;
    return value;
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.errorFg : AppColors.secondary500,
      ),
    );
  }

  void _showError(String contextMessage, Object error) {
    _showSnack('$contextMessage ${error.toString()}', isError: true);
  }

  void _selectCategoryForEdition(String categoryId) {
    final normalized = categoryId.trim().toLowerCase();
    final exists = _kCatalogCategories.any(
      (category) => category.id == normalized,
    );
    if (!exists) return;
    setState(() {
      _section = _CatalogSection.category;
      _selectedCategoryId = normalized;
      final nextLimit = _config.categoryLimits[normalized];
      _categoryLimitController.text = nextLimit == null ? '' : '$nextLimit';
    });
  }

  String _categoryLabelById(String categoryId) {
    for (final category in _kCatalogCategories) {
      if (category.id == categoryId.trim().toLowerCase()) return category.label;
    }
    if (categoryId.trim().isEmpty) return 'Sin categoría';
    return categoryId.trim();
  }

  List<_CatalogMerchantRow> get _filteredRows {
    switch (_merchantFilter) {
      case _MerchantFilter.overThreshold:
        return _searchRows
            .where((row) => row.usageRatio >= 0.8)
            .toList(growable: false);
      case _MerchantFilter.withOverride:
        return _searchRows
            .where((row) => row.overrideLimit != null)
            .toList(growable: false);
      case _MerchantFilter.all:
        return _searchRows;
    }
  }

  _UsageSnapshot _usageSnapshot() {
    if (_searchRows.isEmpty) {
      return const _UsageSnapshot(
        totalUsed: 0,
        totalLimit: 0,
        usagePercent: 0,
        merchantsOverThreshold: 0,
      );
    }
    final used = _searchRows.fold<int>(
      0,
      (sum, row) => sum + row.activeProductCount,
    );
    final limit = _searchRows.fold<int>(
      0,
      (sum, row) => sum + row.effectiveLimit,
    );
    final percent = limit <= 0 ? 0 : ((used / limit) * 100).round();
    final overThreshold =
        _searchRows.where((row) => row.usageRatio >= 0.8).length;
    return _UsageSnapshot(
      totalUsed: used,
      totalLimit: limit,
      usagePercent: percent.clamp(0, 999),
      merchantsOverThreshold: overThreshold,
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedCategoryLimit = _config.categoryLimits[_selectedCategoryId];
    final width = MediaQuery.sizeOf(context).width;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: RefreshIndicator(
        onRefresh: _reloadConfig,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(28, 22, 28, 30),
          children: [
            _HeaderBlock(
              loading: _loadingConfig,
              section: _section,
              onSectionChanged: (section) => setState(() => _section = section),
            ),
            const SizedBox(height: 18),
            if (_section == _CatalogSection.global)
              _buildGlobalSection(width)
            else if (_section == _CatalogSection.category)
              _buildCategorySection(selectedCategoryLimit)
            else
              _buildMerchantsSection(width),
          ],
        ),
      ),
    );
  }

  Widget _buildGlobalSection(double width) {
    final usage = _usageSnapshot();
    final isDesktop = width >= 1160;
    final left = _SectionCard(
      title: 'Configuración de cuota',
      subtitle:
          'Definí el límite global usado cuando no hay reglas por categoría ni override individual.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Seleccionar ajuste preestablecido',
            style: AppTextStyles.bodyXs.copyWith(
              color: AppColors.neutral700,
              fontWeight: FontWeight.w700,
              letterSpacing: .4,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _kCatalogLimitPresets
                .map(
                  (limit) => _PresetLimitButton(
                    value: limit,
                    selected: _globalLimitController.text.trim() == '$limit',
                    onPressed: _savingGlobal
                        ? null
                        : () => setState(
                              () => _globalLimitController.text = '$limit',
                            ),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: 220,
            child: TextField(
              controller: _globalLimitController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Límite de SKUs',
                suffixText: 'SKUs',
              ),
            ),
          ),
          const SizedBox(height: 8),
          const _InlineAdminMessage(
            text:
                'El valor debe ser superior a 0 para mantener la operatividad del catálogo.',
            isError: false,
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _savingGlobal ? null : _saveGlobalLimit,
            icon: const Icon(Icons.save_outlined),
            label: Text(_savingGlobal ? 'Guardando...' : 'Guardar cambios'),
          ),
        ],
      ),
    );

    final right = Column(
      children: [
        _SectionCard(
          title: 'Uso actual',
          subtitle: _searchRows.isEmpty
              ? 'Buscá comercios para obtener una foto operativa real.'
              : 'Con base en la última búsqueda de overrides.',
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      usage.totalLimit == 0
                          ? '${_config.defaultProductLimit}'
                          : '${usage.totalUsed} / ${usage.totalLimit}',
                      style: AppTextStyles.headingLg.copyWith(fontSize: 34),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      usage.totalLimit == 0
                          ? 'Límite global configurado'
                          : '${usage.merchantsOverThreshold} comercios en zona de alerta (>=80%)',
                      style: AppTextStyles.bodySm,
                    ),
                  ],
                ),
              ),
              _CircularUsage(value: usage.usagePercent),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const _SectionCard(
          title: 'Análisis de impacto',
          subtitle: 'Efectos del límite en costos y operación de catálogo.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BulletLine(
                icon: Icons.check_circle,
                color: AppColors.secondary500,
                text:
                    'Reduce fan-out de productos y baja costo de sincronización.',
              ),
              SizedBox(height: 8),
              _BulletLine(
                icon: Icons.check_circle,
                color: AppColors.secondary500,
                text: 'Controla crecimiento desordenado en comercios nuevos.',
              ),
              SizedBox(height: 8),
              _BulletLine(
                icon: Icons.warning_amber_rounded,
                color: AppColors.tertiary500,
                text:
                    'Si bajás el límite debajo del uso actual, se bloquean altas hasta regularizar.',
              ),
            ],
          ),
        ),
      ],
    );

    if (!isDesktop) {
      return Column(children: [left, const SizedBox(height: 12), right]);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 7, child: left),
        const SizedBox(width: 12),
        Expanded(flex: 5, child: right),
      ],
    );
  }

  Widget _buildCategorySection(int? selectedCategoryLimit) {
    final overrideCount = _config.categoryLimits.length;
    return Column(
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _StatCard(
              width: 280,
              title: 'Límite global',
              value: '${_config.defaultProductLimit} SKUs',
              subtitle: 'Base para categorías sin override',
              highlighted: true,
            ),
            _StatCard(
              width: 220,
              title: 'Categorías totales',
              value: '${_kCatalogCategories.length}',
              subtitle: 'Rubros MVP activos',
            ),
            _StatCard(
              width: 260,
              title: 'Límites personalizados',
              value: '$overrideCount',
              subtitle: 'Categorías con excepción',
              warning: overrideCount > 0,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Configuración por categoría',
          subtitle:
              'El override por categoría aplica a todos los comercios salvo que tengan override individual.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _selectedCategoryId,
                decoration: const InputDecoration(labelText: 'Categoría'),
                items: _kCatalogCategories
                    .map(
                      (category) => DropdownMenuItem<String>(
                        value: category.id,
                        child: Text(category.label),
                      ),
                    )
                    .toList(growable: false),
                onChanged: _savingCategory
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() {
                          _selectedCategoryId = value;
                          final nextLimit = _config.categoryLimits[value];
                          _categoryLimitController.text =
                              nextLimit == null ? '' : '$nextLimit';
                        });
                      },
              ),
              const SizedBox(height: 10),
              Text(
                selectedCategoryLimit == null
                    ? 'Sin override (hereda global ${_config.defaultProductLimit}).'
                    : 'Valor actual: $selectedCategoryLimit',
                style: AppTextStyles.bodySm.copyWith(
                  color: AppColors.neutral700,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _kCatalogLimitPresets
                    .map(
                      (limit) => _PresetLimitButton(
                        value: limit,
                        selected:
                            _categoryLimitController.text.trim() == '$limit',
                        onPressed: _savingCategory
                            ? null
                            : () => setState(
                                  () =>
                                      _categoryLimitController.text = '$limit',
                                ),
                      ),
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 170,
                    child: TextField(
                      controller: _categoryLimitController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Custom'),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _savingCategory ? null : _saveCategoryLimit,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(_savingCategory ? 'Guardando...' : 'Guardar'),
                  ),
                  TextButton.icon(
                    onPressed: _savingCategory ? null : _clearCategoryLimit,
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Usar global'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Listado de categorías',
          subtitle: 'Edición rápida por rubro canónico del MVP.',
          child: Column(
            children: _kCatalogCategories.map((category) {
              final categoryLimit = _config.categoryLimits[category.id];
              final usingGlobal = categoryLimit == null;
              final displayLimit = categoryLimit ?? _config.defaultProductLimit;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.neutral50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppColors.primary50,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(
                          category.icon,
                          size: 18,
                          color: AppColors.primary700,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          category.label,
                          style: AppTextStyles.labelMd.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      _LimitTag(
                        text: usingGlobal
                            ? 'Usa global $displayLimit'
                            : 'Personalizado $displayLimit',
                        custom: !usingGlobal,
                      ),
                      const SizedBox(width: 10),
                      TextButton(
                        onPressed: () => _selectCategoryForEdition(category.id),
                        child: const Text('Editar'),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(growable: false),
          ),
        ),
      ],
    );
  }

  Widget _buildMerchantsSection(double width) {
    final rows = _filteredRows;
    final columns = width >= 1440
        ? 4
        : width >= 1180
            ? 3
            : width >= 860
                ? 2
                : 1;

    return Column(
      children: [
        _SectionCard(
          title: 'Merchant overrides search',
          subtitle:
              'Consulta acotada a 20 resultados por búsqueda para controlar consumo Firestore.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width:
                        math.min(width - 220, 620).clamp(260, 620).toDouble(),
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        labelText: 'Buscar por ID, legalName o fantasyName',
                        hintText: 'Ej: farmacia del sol',
                      ),
                      onSubmitted: (_) => _searchMerchants(),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _searchingMerchants ? null : _searchMerchants,
                    icon: const Icon(Icons.search),
                    label: const Text('Buscar'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ToggleChip(
                    text: 'Todos',
                    selected: _merchantFilter == _MerchantFilter.all,
                    onTap: () =>
                        setState(() => _merchantFilter = _MerchantFilter.all),
                  ),
                  _ToggleChip(
                    text: '>=80% uso',
                    selected: _merchantFilter == _MerchantFilter.overThreshold,
                    onTap: () => setState(
                      () => _merchantFilter = _MerchantFilter.overThreshold,
                    ),
                  ),
                  _ToggleChip(
                    text: 'Con override',
                    selected: _merchantFilter == _MerchantFilter.withOverride,
                    onTap: () => setState(
                      () => _merchantFilter = _MerchantFilter.withOverride,
                    ),
                  ),
                ],
              ),
              if (_searchingMerchants) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(minHeight: 3),
              ],
              if (_searchMessage != null) ...[
                const SizedBox(height: 12),
                _InlineAdminMessage(text: _searchMessage!, isError: false),
              ],
              if (rows.isNotEmpty) ...[
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: columns == 1 ? 2.5 : 1.12,
                  ),
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    final progressColor = row.isBlocked
                        ? AppColors.errorFg
                        : row.isWarning
                            ? AppColors.tertiary500
                            : AppColors.secondary500;
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary900.withValues(alpha: 0.05),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      row.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.headingSm.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _categoryLabelById(row.categoryId),
                                      style: AppTextStyles.bodyXs.copyWith(
                                        color: AppColors.neutral600,
                                        letterSpacing: .3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _StatusChip(
                                text: row.statusLabel,
                                warning: row.statusLabel == 'Pendiente',
                                neutral: row.statusLabel == 'Inactivo',
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Uso', style: AppTextStyles.bodyXs),
                              Text(
                                '${row.activeProductCount}/${row.effectiveLimit}',
                                style: AppTextStyles.labelMd.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              minHeight: 7,
                              value: row.usageRatio.clamp(0, 1),
                              backgroundColor: AppColors.neutral200,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                progressColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            row.isBlocked
                                ? 'Límite alcanzado. Requiere ajuste o reducción de catálogo.'
                                : row.isWarning
                                    ? 'Cerca del límite operativo.'
                                    : row.overrideLimit != null
                                        ? 'Con override individual activo.'
                                        : 'Hereda límite de categoría/global.',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyXs.copyWith(
                              color: row.isBlocked
                                  ? AppColors.errorFg
                                  : AppColors.neutral600,
                            ),
                          ),
                          const Spacer(),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () => _openOverrideDialog(row),
                              icon: const Icon(Icons.tune, size: 18),
                              label: const Text('Configurar límite'),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        const _SectionCard(
          title: 'Guía de excepciones',
          subtitle: 'Recordatorio operativo para administración de cupos.',
          child: _InlineAdminMessage(
            text:
                'Los overrides se usan para casos puntuales. Si el límite supera en más del 50% la categoría, requiere revisión administrativa.',
            isError: false,
          ),
        ),
      ],
    );
  }
}

class _HeaderBlock extends StatelessWidget {
  const _HeaderBlock({
    required this.loading,
    required this.section,
    required this.onSectionChanged,
  });

  final bool loading;
  final _CatalogSection section;
  final ValueChanged<_CatalogSection> onSectionChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary500, AppColors.primary700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Límites de catálogo',
            style: AppTextStyles.headingLg.copyWith(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Jerarquía: override individual > categoría > global. Cambios aplican sin listeners permanentes.',
            style: AppTextStyles.bodyMd.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TopToggle(
                text: 'Global',
                selected: section == _CatalogSection.global,
                onTap: () => onSectionChanged(_CatalogSection.global),
              ),
              _TopToggle(
                text: 'Por categoría',
                selected: section == _CatalogSection.category,
                onTap: () => onSectionChanged(_CatalogSection.category),
              ),
              _TopToggle(
                text: 'Comercios',
                selected: section == _CatalogSection.merchant,
                onTap: () => onSectionChanged(_CatalogSection.merchant),
              ),
            ],
          ),
          if (loading) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              minHeight: 3,
              borderRadius: BorderRadius.circular(999),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              backgroundColor: Colors.white.withValues(alpha: 0.2),
            ),
          ],
        ],
      ),
    );
  }
}

class _TopToggle extends StatelessWidget {
  const _TopToggle({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: AppTextStyles.labelSm.copyWith(
            color: selected ? AppColors.primary700 : Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.headingSm.copyWith(
              color: AppColors.neutral900,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: AppTextStyles.bodySm.copyWith(color: AppColors.neutral700),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _InlineAdminMessage extends StatelessWidget {
  const _InlineAdminMessage({required this.text, required this.isError});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isError ? AppColors.errorBg : AppColors.infoBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: AppTextStyles.bodySm.copyWith(
          color: isError ? AppColors.errorFg : AppColors.primary700,
        ),
      ),
    );
  }
}

class _PresetLimitButton extends StatelessWidget {
  const _PresetLimitButton({
    required this.value,
    required this.selected,
    required this.onPressed,
  });

  final int value;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final buttonStyle = OutlinedButton.styleFrom(
      foregroundColor: selected ? Colors.white : AppColors.neutral800,
      backgroundColor: selected ? AppColors.primary500 : AppColors.neutral100,
      side: BorderSide(
        color: selected ? AppColors.primary500 : AppColors.neutral200,
      ),
      textStyle: AppTextStyles.labelSm.copyWith(
        fontWeight: FontWeight.w700,
        fontSize: 13,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
    return OutlinedButton(
      onPressed: onPressed,
      style: buttonStyle,
      child: Text('$value'),
    );
  }
}

class _CircularUsage extends StatelessWidget {
  const _CircularUsage({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    final safeValue = value.clamp(0, 999);
    final normalized = safeValue > 100 ? 1.0 : safeValue / 100;
    return SizedBox(
      width: 86,
      height: 86,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: normalized,
            strokeWidth: 8,
            backgroundColor: AppColors.neutral200,
            valueColor: AlwaysStoppedAnimation<Color>(
              safeValue >= 100
                  ? AppColors.errorFg
                  : safeValue >= 80
                      ? AppColors.tertiary500
                      : AppColors.primary500,
            ),
          ),
          Text(
            '$safeValue%',
            style: AppTextStyles.labelMd.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _BulletLine extends StatelessWidget {
  const _BulletLine({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodySm.copyWith(color: AppColors.neutral800),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.width,
    required this.title,
    required this.value,
    required this.subtitle,
    this.highlighted = false,
    this.warning = false,
  });

  final double width;
  final String title;
  final String value;
  final String subtitle;
  final bool highlighted;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final background = highlighted
        ? const LinearGradient(
            colors: [AppColors.primary500, AppColors.primary700],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : null;

    final baseColor = warning ? AppColors.tertiary50 : AppColors.surface;
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlighted ? null : baseColor,
        gradient: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: AppTextStyles.bodyXs.copyWith(
              color: highlighted ? Colors.white70 : AppColors.neutral700,
              fontWeight: FontWeight.w700,
              letterSpacing: .5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.headingMd.copyWith(
              color: highlighted ? Colors.white : AppColors.neutral900,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: AppTextStyles.bodyXs.copyWith(
              color: highlighted ? Colors.white70 : AppColors.neutral700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LimitTag extends StatelessWidget {
  const _LimitTag({required this.text, required this.custom});

  final String text;
  final bool custom;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: custom ? AppColors.primary50 : AppColors.neutral100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: AppTextStyles.bodyXs.copyWith(
          color: custom ? AppColors.primary700 : AppColors.neutral700,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary500 : AppColors.neutral100,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          style: AppTextStyles.bodyXs.copyWith(
            color: selected ? Colors.white : AppColors.neutral700,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.text,
    this.warning = false,
    this.neutral = false,
  });

  final String text;
  final bool warning;
  final bool neutral;

  @override
  Widget build(BuildContext context) {
    final Color bg = warning
        ? AppColors.tertiary50
        : neutral
            ? AppColors.neutral100
            : AppColors.secondary50;
    final Color fg = warning
        ? AppColors.tertiary700
        : neutral
            ? AppColors.neutral700
            : AppColors.secondary700;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: AppTextStyles.bodyXs.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CompactMetricChip extends StatelessWidget {
  const _CompactMetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.neutral100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: AppTextStyles.bodyXs.copyWith(
              color: AppColors.neutral700,
              fontWeight: FontWeight.w700,
              letterSpacing: .4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTextStyles.labelMd.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _CatalogLimitsConfig {
  const _CatalogLimitsConfig({
    required this.defaultProductLimit,
    required this.categoryLimits,
  });

  final int defaultProductLimit;
  final Map<String, int> categoryLimits;

  factory _CatalogLimitsConfig.empty() {
    return const _CatalogLimitsConfig(
      defaultProductLimit: 100,
      categoryLimits: <String, int>{},
    );
  }

  factory _CatalogLimitsConfig.fromMap(Map<String, dynamic> data) {
    final defaultLimit = _parsePositiveInt(data['defaultProductLimit']) ?? 100;
    final categoryLimits = <String, int>{};
    final rawCategoryLimits = data['categoryLimits'];
    if (rawCategoryLimits is Map) {
      for (final entry in rawCategoryLimits.entries) {
        final categoryId = entry.key.toString().trim().toLowerCase();
        final limit = _parsePositiveInt(entry.value);
        if (categoryId.isEmpty || limit == null) continue;
        categoryLimits[categoryId] = limit;
      }
    }
    return _CatalogLimitsConfig(
      defaultProductLimit: defaultLimit,
      categoryLimits: categoryLimits,
    );
  }

  static int? _parsePositiveInt(Object? value) {
    if (value is int && value > 0) return value;
    if (value is num && value > 0 && value == value.toInt()) {
      return value.toInt();
    }
    return null;
  }
}

class _CatalogMerchantRow {
  const _CatalogMerchantRow({
    required this.merchantId,
    required this.name,
    required this.legalName,
    required this.fantasyName,
    required this.categoryId,
    required this.activeProductCount,
    required this.effectiveLimit,
    required this.limitSource,
    required this.usageRatio,
    required this.usagePercent,
    required this.overrideLimit,
    required this.status,
    required this.visibilityStatus,
  });

  final String merchantId;
  final String name;
  final String legalName;
  final String fantasyName;
  final String categoryId;
  final int activeProductCount;
  final int effectiveLimit;
  final String limitSource;
  final double usageRatio;
  final int usagePercent;
  final int? overrideLimit;
  final String status;
  final String visibilityStatus;

  bool get isBlocked => usageRatio >= 1;
  bool get isWarning => usageRatio >= 0.8 && usageRatio < 1;

  String get statusLabel {
    final normalizedStatus = status.trim().toLowerCase();
    final normalizedVisibility = visibilityStatus.trim().toLowerCase();
    if (normalizedStatus == 'inactive' || normalizedStatus == 'archived')
      return 'Inactivo';
    if (normalizedVisibility == 'review_pending') return 'Pendiente';
    return 'Activo';
  }

  factory _CatalogMerchantRow.fromMap(Map<String, dynamic> data) {
    int toInt(Object? raw) {
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      return 0;
    }

    double toDouble(Object? raw) {
      if (raw is num) return raw.toDouble();
      return 0;
    }

    return _CatalogMerchantRow(
      merchantId: (data['merchantId'] as String?)?.trim() ?? '',
      name: (data['name'] as String?)?.trim() ?? 'Comercio sin nombre',
      legalName: (data['legalName'] as String?)?.trim() ?? '',
      fantasyName: (data['fantasyName'] as String?)?.trim() ?? '',
      categoryId: (data['categoryId'] as String?)?.trim() ?? '',
      activeProductCount: toInt(data['activeProductCount']),
      effectiveLimit: toInt(data['effectiveLimit']),
      limitSource: (data['limitSource'] as String?)?.trim() ?? 'global_default',
      usageRatio: toDouble(data['usageRatio']),
      usagePercent: toInt(data['usagePercent']),
      overrideLimit: data['overrideLimit'] is num
          ? (data['overrideLimit'] as num).toInt()
          : null,
      status: (data['status'] as String?)?.trim() ?? '',
      visibilityStatus: (data['visibilityStatus'] as String?)?.trim() ?? '',
    );
  }
}

class _CatalogCategory {
  const _CatalogCategory({
    required this.id,
    required this.label,
    required this.icon,
  });

  final String id;
  final String label;
  final IconData icon;
}

class _UsageSnapshot {
  const _UsageSnapshot({
    required this.totalUsed,
    required this.totalLimit,
    required this.usagePercent,
    required this.merchantsOverThreshold,
  });

  final int totalUsed;
  final int totalLimit;
  final int usagePercent;
  final int merchantsOverThreshold;
}
