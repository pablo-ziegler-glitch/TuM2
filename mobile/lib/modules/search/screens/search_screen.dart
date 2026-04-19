import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/merchant_search_item.dart';
import '../providers/search_notifier.dart';
import '../widgets/search_filters_sheet.dart';
import '../widgets/zone_selector_sheet.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  var _initializationStarted = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      ref.read(searchNotifierProvider.notifier).setQuery(_controller.text);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.text.isEmpty) {
      final query = ref.read(searchNotifierProvider).query;
      if (query.isNotEmpty) {
        _controller.text = query;
        _controller.selection = TextSelection.collapsed(offset: query.length);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _ensureInitializedOnce() async {
    if (_initializationStarted) return;
    _initializationStarted = true;
    await ref.read(searchNotifierProvider.notifier).ensureInitialized();
  }

  void _goToResults([String? query]) async {
    await _ensureInitializedOnce();
    if (!mounted) return;
    final q = (query ?? _controller.text).trim();
    if (q.isNotEmpty) {
      ref.read(searchNotifierProvider.notifier).submitQuery(q);
    }
    final route = q.isEmpty
        ? AppRoutes.searchResults
        : '${AppRoutes.searchResults}?q=${Uri.encodeComponent(q)}';
    context.push(route);
  }

  void _applyPresetQuery(String value) {
    _controller.text = value;
    _controller.selection = TextSelection.collapsed(offset: value.length);
    _goToResults(value);
  }

  void _toggleOpenNow() async {
    await _ensureInitializedOnce();
    if (!mounted) return;
    final notifier = ref.read(searchNotifierProvider.notifier);
    final current = ref.read(searchNotifierProvider).filters;
    final nextValue = !current.isOpenNow;
    notifier.setFilters(current.copyWith(isOpenNow: nextValue));
    final route = nextValue
        ? '${AppRoutes.searchResults}?openNow=true'
        : AppRoutes.searchResults;
    context.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchNotifierProvider);
    final hasTyping = _controller.text.trim().isNotEmpty;
    String zoneName = 'Tu zona';
    for (final zone in state.zones) {
      if (zone.zoneId == state.activeZoneId) {
        zoneName = zone.name;
        break;
      }
    }

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      body: SafeArea(
        child: Column(
          children: [
            _SearchTopBar(zoneName: zoneName),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.neutral200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search,
                            color: AppColors.neutral600, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            onTap: _ensureInitializedOnce,
                            textInputAction: TextInputAction.search,
                            onSubmitted: _goToResults,
                            decoration: const InputDecoration(
                              hintText: 'Farmacia, kiosco o algo abierto...',
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        if (hasTyping)
                          IconButton(
                            onPressed: () {
                              _controller.clear();
                              ref
                                  .read(searchNotifierProvider.notifier)
                                  .setQuery('');
                            },
                            icon: const Icon(Icons.close,
                                color: AppColors.neutral600, size: 18),
                          )
                        else
                          IconButton(
                            onPressed: () async {
                              await _ensureInitializedOnce();
                              if (!context.mounted) return;
                              SearchFiltersSheet.show(context);
                            },
                            icon: const Icon(Icons.tune_rounded,
                                color: AppColors.neutral600, size: 18),
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
                        _QuickChip(
                          label: 'Farmacias',
                          onTap: () => _applyPresetQuery('farmacia'),
                        ),
                        const SizedBox(width: 8),
                        _QuickChip(
                          label: 'Abierto ahora',
                          active: state.filters.isOpenNow,
                          icon: Icons.circle,
                          onTap: _toggleOpenNow,
                        ),
                        const SizedBox(width: 8),
                        _QuickChip(
                          label: 'Kioscos',
                          onTap: () => _applyPresetQuery('kiosco'),
                        ),
                        const SizedBox(width: 8),
                        _QuickChip(
                          label: 'Veterinarias',
                          onTap: () => _applyPresetQuery('veterinaria'),
                        ),
                        const SizedBox(width: 8),
                        _QuickChip(
                          label: 'Zona',
                          icon: Icons.location_on,
                          onTap: () async {
                            await _ensureInitializedOnce();
                            if (!context.mounted) return;
                            ZoneSelectorSheet.show(context);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: switch ((state.isLoading, state.initialized, hasTyping)) {
                (true, false, _) => const _SearchLoadingCanvas(),
                (_, _, true) => _SearchSuggestions(
                    suggestions: state.suggestions,
                    onTapSuggestion: (value) {
                      _controller.text = value;
                      _controller.selection =
                          TextSelection.collapsed(offset: value.length);
                      _goToResults(value);
                    },
                  ),
                _ => _SearchDiscoverCanvas(
                    onUrgencyTap: () => _applyPresetQuery('farmacia'),
                    onSnacksTap: () => _applyPresetQuery('kiosco'),
                  ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchTopBar extends StatelessWidget {
  const _SearchTopBar({required this.zoneName});

  final String zoneName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: AppColors.primary500, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TuM2',
                style: AppTextStyles.headingSm.copyWith(
                  color: AppColors.primary500,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                zoneName,
                style: AppTextStyles.bodyXs.copyWith(
                  color: AppColors.neutral700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications, color: AppColors.neutral700),
          ),
        ],
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.label,
    required this.onTap,
    this.active = false,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final bool active;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.secondary200 : AppColors.neutral100,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 12,
                color: active ? AppColors.secondary700 : AppColors.neutral700,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: AppTextStyles.labelSm.copyWith(
                color: active ? AppColors.secondary700 : AppColors.neutral700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchLoadingCanvas extends StatelessWidget {
  const _SearchLoadingCanvas();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: const [
        _SkeletonBox(height: 220),
        SizedBox(height: 18),
        Row(
          children: [
            Expanded(child: _SkeletonBox(height: 110)),
            SizedBox(width: 12),
            Expanded(child: _SkeletonBox(height: 110)),
          ],
        ),
        SizedBox(height: 18),
        _SkeletonBox(height: 90),
        SizedBox(height: 14),
        _SkeletonBox(height: 140),
      ],
    );
  }
}

class _SearchSuggestions extends StatelessWidget {
  const _SearchSuggestions({
    required this.suggestions,
    required this.onTapSuggestion,
  });

  final List<MerchantSearchItem> suggestions;
  final void Function(String value) onTapSuggestion;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      children: [
        const Text('Sugerencias', style: AppTextStyles.headingSm),
        const SizedBox(height: 8),
        ...suggestions.take(6).map(
              (item) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.search, color: AppColors.neutral600),
                title: Text(item.name),
                subtitle: Text(
                  item.categoryLabel.isEmpty
                      ? item.categoryId
                      : item.categoryLabel,
                  style: AppTextStyles.bodySm,
                ),
                onTap: () => onTapSuggestion(item.name),
              ),
            ),
      ],
    );
  }
}

class _SearchDiscoverCanvas extends StatelessWidget {
  const _SearchDiscoverCanvas({
    required this.onUrgencyTap,
    required this.onSnacksTap,
  });

  final VoidCallback onUrgencyTap;
  final VoidCallback onSnacksTap;

  static const _heroImage =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuCtHpRO1dI3oGzPuss991ocPcESYxG5L2z9yRM8GmUQ_JCoQaOsIFyA06-sXcMfg0zWNdU1OcvVFzsbfECnhWDBlgvnTNEseG41bSM_4qanIUk6XR4GyBCvKcWupB65I4gxBx9JLdTulbQS6Dgw1ZKcw4FkT3J3xOmGzSz0z47buH5pK4pUzC8DSCh27rSobzaz-j4Icvl-IEhkH3M2R8UwjYiLo1vuFoTvzBhLnO-fUPRDANfEg8MNsx9ZLspp7zkA4LZCjE5-uNVq';

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: SizedBox(
            height: 230,
            child: Image.network(
              _heroImage,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF5EBBD4), Color(0xFF5D90CC)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.storefront_outlined,
                    color: Colors.white,
                    size: 56,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Encontrá lo que necesitás\na la vuelta de tu casa',
          textAlign: TextAlign.center,
          style: AppTextStyles.headingLg.copyWith(
            fontSize: 38,
            height: 1.1,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Explorá los comercios cercanos, verificá horarios y encontrá opciones abiertas ahora mismo.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMd.copyWith(color: AppColors.neutral700),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _ActionCard(
                icon: Icons.bolt,
                iconColor: AppColors.tertiary500,
                title: 'Urgencias',
                subtitle: 'Farmacias de turno hoy',
                onTap: onUrgencyTap,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionCard(
                icon: Icons.restaurant,
                iconColor: AppColors.secondary500,
                title: 'Antojos',
                subtitle: 'Kioscos y locales 24h',
                onTap: onSnacksTap,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.neutral100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(height: 10),
            Text(
              title,
              style:
                  AppTextStyles.labelMd.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: AppTextStyles.bodyXs),
          ],
        ),
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.neutral100,
        borderRadius: BorderRadius.circular(18),
      ),
    );
  }
}
