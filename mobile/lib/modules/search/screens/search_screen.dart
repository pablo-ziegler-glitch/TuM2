import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../widgets/search_filters_sheet.dart';
import '../widgets/zone_selector_sheet.dart';

/// SEARCH-01 — Tab Buscar / Explorar.
///
/// Pantalla principal de descubrimiento activo con tres estados visuales:
/// - [_SearchMode.initial]  → feed de descubrimiento (acceso rápido + sugerencias)
/// - [_SearchMode.focused]  → barra activa sin texto (recientes + categorías)
/// - [_SearchMode.typing]   → autocompletado mientras el usuario escribe
enum _SearchMode { initial, focused, typing }

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  _SearchMode _mode = _SearchMode.initial;
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  static const _recentSearches = [
    'Cafetería de especialidad',
    'Panadería artesanal',
    'Gimnasio 24h',
  ];

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus && _controller.text.isEmpty) {
      setState(() => _mode = _SearchMode.initial);
    } else if (_focusNode.hasFocus && _controller.text.isEmpty) {
      setState(() => _mode = _SearchMode.focused);
    }
  }

  void _onTextChanged() {
    final hasText = _controller.text.isNotEmpty;
    setState(() => _mode = hasText ? _SearchMode.typing : _SearchMode.focused);
  }

  void _activateSearch() {
    setState(() => _mode = _SearchMode.focused);
    _focusNode.requestFocus();
  }

  void _dismissSearch() {
    _focusNode.unfocus();
    _controller.clear();
    setState(() => _mode = _SearchMode.initial);
  }

  void _clearText() {
    _controller.clear();
    setState(() => _mode = _SearchMode.focused);
  }

  void _submitSearch([String? query]) {
    final q = (query ?? _controller.text).trim();
    if (q.isEmpty) return;
    _focusNode.unfocus();
    context.push('${AppRoutes.searchResults}?q=${Uri.encodeComponent(q)}');
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: switch (_mode) {
        _SearchMode.initial => _InitialView(
            onSearchTap: _activateSearch,
            onFilterTap: () => SearchFiltersSheet.show(context),
            onZoneTap: () => ZoneSelectorSheet.show(context),
          ),
        _SearchMode.focused => _ActiveSearchView(
            controller: _controller,
            focusNode: _focusNode,
            isTyping: false,
            recentSearches: _recentSearches,
            onBack: _dismissSearch,
            onClear: _clearText,
            onSubmit: _submitSearch,
            onRecentTap: _submitSearch,
          ),
        _SearchMode.typing => _ActiveSearchView(
            controller: _controller,
            focusNode: _focusNode,
            isTyping: true,
            recentSearches: _recentSearches,
            onBack: _dismissSearch,
            onClear: _clearText,
            onSubmit: _submitSearch,
            onRecentTap: _submitSearch,
          ),
      },
    );
  }
}

// ── INITIAL VIEW ──────────────────────────────────────────────────────────────

class _InitialView extends StatelessWidget {
  final VoidCallback onSearchTap;
  final VoidCallback onFilterTap;
  final VoidCallback onZoneTap;

  const _InitialView({
    required this.onSearchTap,
    required this.onFilterTap,
    required this.onZoneTap,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildHeader(context)),
        SliverToBoxAdapter(child: _buildFakeSearchBar()),
        SliverToBoxAdapter(child: _buildAccesoRapido(context)),
        SliverToBoxAdapter(child: _buildSugerenciasHeader(context)),
        SliverToBoxAdapter(child: _buildHeroCard(context)),
        SliverToBoxAdapter(child: _buildCategoryGrid(context)),
        SliverToBoxAdapter(child: _buildSuggestionList(context)),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 16, 20, 0),
      child: Row(
        children: [
          Text(
            'TuM2',
            style: AppTextStyles.headingMd.copyWith(
              color: AppColors.primary500,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onZoneTap,
            child: CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.neutral200,
              child: Icon(Icons.person_outline,
                  size: 20, color: AppColors.neutral700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFakeSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: GestureDetector(
        onTap: onSearchTap,
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.neutral200),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Icon(Icons.search, color: AppColors.neutral400, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Farmacia, algo abierto...',
                  style: AppTextStyles.bodyMd
                      .copyWith(color: AppColors.neutral400),
                ),
              ),
              GestureDetector(
                onTap: onFilterTap,
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.tune_rounded,
                      color: AppColors.primary500, size: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccesoRapido(BuildContext context) {
    final items = [
      (
        label: 'Farmacias de turno',
        icon: Icons.local_pharmacy_outlined,
        selected: true,
        onTap: () => context.push(AppRoutes.searchFarmacias),
      ),
      (
        label: 'Kioscos 24h',
        icon: Icons.store_outlined,
        selected: false,
        onTap: () =>
            context.push('${AppRoutes.searchResults}?q=kioscos'),
      ),
      (
        label: 'Cerca de ti',
        icon: Icons.near_me_outlined,
        selected: false,
        onTap: () => context.push(AppRoutes.searchResults),
      ),
      (
        label: 'Mi zona',
        icon: Icons.location_on_outlined,
        selected: false,
        onTap: () => ZoneSelectorSheet.show(context),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
          child: Text('Acceso Rápido', style: AppTextStyles.headingSm),
        ),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final item = items[i];
              return GestureDetector(
                onTap: item.onTap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: item.selected
                        ? AppColors.primary500
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: item.selected
                          ? AppColors.primary500
                          : AppColors.neutral300,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(item.icon,
                          size: 14,
                          color: item.selected
                              ? AppColors.surface
                              : AppColors.neutral600),
                      const SizedBox(width: 5),
                      Text(
                        item.label,
                        style: AppTextStyles.labelSm.copyWith(
                          color: item.selected
                              ? AppColors.surface
                              : AppColors.neutral700,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSugerenciasHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Sugerencias para ti', style: AppTextStyles.headingSm),
          GestureDetector(
            onTap: () => context.push(AppRoutes.searchResults),
            child: Text('Ver todo',
                style: AppTextStyles.labelSm
                    .copyWith(color: AppColors.primary500)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: GestureDetector(
        onTap: () => context.push(AppRoutes.searchResults),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: 160,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  color: const Color(0xFF8B4513),
                  child: Center(
                    child: Icon(Icons.local_cafe,
                        size: 56, color: Colors.white.withOpacity(0.25)),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.65)
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.tertiary500,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      'OFERTA',
                      style: AppTextStyles.bodyXs.copyWith(
                        color: AppColors.surface,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 12,
                  left: 14,
                  right: 14,
                  child: Text(
                    'Cafeterías de Especialidad',
                    style: AppTextStyles.headingSm
                        .copyWith(color: AppColors.surface),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryGrid(BuildContext context) {
    final items = [
      (
        icon: Icons.restaurant,
        label: 'Restaurantes Vegetarianos',
        color: AppColors.secondary500,
        bg: AppColors.secondary50
      ),
      (
        icon: Icons.content_cut,
        label: 'Barberias y Salones',
        color: AppColors.tertiary500,
        bg: AppColors.tertiary50
      ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Row(
        children: List.generate(items.length, (i) {
          final item = items[i];
          return Expanded(
            child: GestureDetector(
              onTap: () => context.push(AppRoutes.searchResults),
              child: Container(
                margin: EdgeInsets.only(right: i == 0 ? 8 : 0),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: item.bg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(item.icon, color: item.color, size: 18),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(item.label,
                          style: AppTextStyles.labelSm, maxLines: 2),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSuggestionList(BuildContext context) {
    final items = [
      (
        icon: Icons.bakery_dining,
        label: 'Panadería artesanal mana madre',
        sub: 'Panadería · 320m'
      ),
      (
        icon: Icons.build_outlined,
        label: 'Ferretería abierta ahora',
        sub: 'Ferretería · 480m'
      ),
    ];
    return Column(
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: GestureDetector(
                onTap: () =>
                    context.push('${AppRoutes.searchResults}?q=${item.label}'),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2))
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.neutral100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(item.icon,
                            color: AppColors.neutral600, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.label,
                                style: AppTextStyles.labelMd,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text(item.sub, style: AppTextStyles.bodyXs),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right,
                          color: AppColors.neutral400, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

// ── ACTIVE SEARCH VIEW (focused + typing) ─────────────────────────────────────

class _ActiveSearchView extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isTyping;
  final List<String> recentSearches;
  final VoidCallback onBack;
  final VoidCallback onClear;
  final void Function(String) onSubmit;
  final void Function(String) onRecentTap;

  const _ActiveSearchView({
    required this.controller,
    required this.focusNode,
    required this.isTyping,
    required this.recentSearches,
    required this.onBack,
    required this.onClear,
    required this.onSubmit,
    required this.onRecentTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSearchHeader(context),
        _buildFilterChips(),
        Expanded(
          child: isTyping
              ? _buildTypingContent(context)
              : _buildFocusedContent(context),
        ),
      ],
    );
  }

  Widget _buildSearchHeader(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: EdgeInsets.fromLTRB(
          16, MediaQuery.of(context).padding.top + 12, 16, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Icon(Icons.arrow_back,
                  color: AppColors.neutral700, size: 22),
            ),
          ),
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.scaffoldBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Icon(Icons.search, color: AppColors.neutral400, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      onSubmitted: onSubmit,
                      decoration: InputDecoration(
                        hintText: '¿Qué estás buscando?',
                        hintStyle: AppTextStyles.bodyMd
                            .copyWith(color: AppColors.neutral400),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: AppTextStyles.bodyMd
                          .copyWith(color: AppColors.neutral900),
                    ),
                  ),
                  if (isTyping)
                    GestureDetector(
                      onTap: onClear,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: AppColors.neutral400,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              color: Colors.white, size: 13),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    const chips = ['Al norte ideas', 'Cerca de mi', 'Top ventas'];
    return Container(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 0, 12),
        child: SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(right: 16),
            itemCount: chips.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) => Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.scaffoldBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.neutral200),
              ),
              child: Text(chips[i],
                  style: AppTextStyles.labelSm
                      .copyWith(color: AppColors.neutral700)),
            ),
          ),
        ),
      ),
    );
  }

  // ── Focused content (sin texto) ──────────────────────────────────────────

  Widget _buildFocusedContent(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        _buildRecentSearches(),
        _buildExplorarCategorias(context),
        _buildBarriosPopulares(context),
      ],
    );
  }

  Widget _buildRecentSearches() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Búsquedas recientes',
                  style: AppTextStyles.headingSm),
              Text('BORRAR ALL',
                  style: AppTextStyles.labelSm.copyWith(
                      color: AppColors.primary500, letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 8),
          ...recentSearches.map(
            (q) => GestureDetector(
              onTap: () => onRecentTap(q),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
                decoration: const BoxDecoration(
                  border: Border(
                      bottom: BorderSide(color: AppColors.neutral100)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.history,
                        color: AppColors.neutral400, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                        child:
                            Text(q, style: AppTextStyles.bodyMd)),
                    Icon(Icons.north_west,
                        color: AppColors.neutral400, size: 15),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExplorarCategorias(BuildContext context) {
    final cats = [
      (icon: Icons.restaurant, label: 'Restaurantes', color: AppColors.secondary500),
      (icon: Icons.shopping_bag_outlined, label: 'Compras', color: AppColors.primary500),
      (icon: Icons.local_cafe, label: 'Café', color: AppColors.tertiary500),
      (icon: Icons.more_horiz, label: 'Ver más', color: AppColors.neutral600),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Explorar Categorías', style: AppTextStyles.headingSm),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: cats
                .map(
                  (c) => Expanded(
                    child: GestureDetector(
                      onTap: () => context.push(AppRoutes.searchResults),
                      child: Column(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: AppColors.neutral100,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(c.icon,
                                color: c.color, size: 24),
                          ),
                          const SizedBox(height: 6),
                          Text(c.label,
                              style: AppTextStyles.bodyXs.copyWith(
                                  color: AppColors.neutral800),
                              textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBarriosPopulares(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Barrios Populares', style: AppTextStyles.headingSm),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => context.push(AppRoutes.searchResults),
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFF4A6741),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Icon(Icons.map_outlined,
                        color: Colors.white.withOpacity(0.12), size: 90),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.55)
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    left: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Palermo Soho',
                            style: AppTextStyles.labelMd
                                .copyWith(color: Colors.white)),
                        Text('124 resultados · Barrio activo',
                            style: AppTextStyles.bodyXs
                                .copyWith(
                                    color: Colors.white.withOpacity(0.8))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Typing content (autocompletado) ─────────────────────────────────────

  Widget _buildTypingContent(BuildContext context) {
    final query = controller.text.toLowerCase();
    final suggestions = _getSuggestions(query);

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        _buildSuggestionsList(suggestions),
        _buildTendencias(context),
      ],
    );
  }

  List<({String name, String type, IconData icon})> _getSuggestions(
      String query) {
    const all = [
      (name: 'Farmacia', type: 'Salud', icon: Icons.local_pharmacy_outlined),
      (name: 'Farmacity', type: 'Negocio', icon: Icons.storefront_outlined),
      (name: 'Ferretería', type: 'Servicios', icon: Icons.build_outlined),
      (name: 'Kiosco', type: 'Comercio', icon: Icons.store_outlined),
      (name: 'Panadería', type: 'Gastronomía', icon: Icons.bakery_dining),
      (name: 'Veterinaria', type: 'Salud Animal', icon: Icons.pets_outlined),
      (name: 'Almacén', type: 'Comercio', icon: Icons.local_grocery_store_outlined),
    ];
    if (query.isEmpty) return all.take(4).toList();
    return all
        .where((s) =>
            s.name.toLowerCase().contains(query) ||
            s.type.toLowerCase().contains(query))
        .toList();
  }

  Widget _buildSuggestionsList(
      List<({String name, String type, IconData icon})> suggestions) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SUGERENCIAS',
              style: AppTextStyles.labelSm
                  .copyWith(color: AppColors.neutral500, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          ...suggestions.map(
            (s) => GestureDetector(
              onTap: () => onRecentTap(s.name),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    vertical: 10, horizontal: 4),
                decoration: const BoxDecoration(
                  border: Border(
                      bottom: BorderSide(color: AppColors.neutral100)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.neutral100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(s.icon,
                          color: AppColors.neutral600, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.name, style: AppTextStyles.labelMd),
                          Text(s.type, style: AppTextStyles.bodyXs),
                        ],
                      ),
                    ),
                    Icon(Icons.favorite_border,
                        color: AppColors.neutral400, size: 18),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTendencias(BuildContext context) {
    final trends = [
      (label: 'Café & Co', sub: '14 lugares', color: const Color(0xFF5C4033)),
      (
        label: 'Ofertas del día',
        sub: '8 lugares',
        color: AppColors.primary700,
        badge: true
      ),
      (
        label: 'Mercados',
        sub: '11 lugares',
        color: const Color(0xFF2D5A27),
        badge: false
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Text('Tendencias en el barrio',
                style: AppTextStyles.headingSm),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 20),
              itemCount: trends.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final t = trends[i];
                final hasBadge = t.badge;
                return GestureDetector(
                  onTap: () => context.push(AppRoutes.searchResults),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 130,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(color: t.color),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.5)
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                          if (hasBadge)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.tertiary500,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'VER MÁS',
                                  style: AppTextStyles.bodyXs.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                            ),
                          Positioned(
                            bottom: 8,
                            left: 10,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t.label,
                                    style: AppTextStyles.labelMd
                                        .copyWith(color: Colors.white)),
                                Text(t.sub,
                                    style: AppTextStyles.bodyXs.copyWith(
                                        color: Colors.white.withOpacity(0.8))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
