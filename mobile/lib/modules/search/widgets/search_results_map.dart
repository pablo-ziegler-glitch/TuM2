import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/merchant_search_item.dart';

class SearchResultsMap extends StatelessWidget {
  const SearchResultsMap({
    super.key,
    required this.items,
    required this.selectedMerchantId,
    required this.onPinTap,
    required this.onCardTap,
    required this.onListTap,
  });

  final List<MerchantSearchItem> items;
  final String? selectedMerchantId;
  final void Function(String merchantId) onPinTap;
  final void Function(String merchantId) onCardTap;
  final VoidCallback onListTap;

  static const _mapImage =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuATMFtm9S3YgUXlIsYWR6124f2HJ1J3XB7kJVDGJEE6jHR7_uoz5_5GDq37aY8AUz5vO0oJ-oXQ98ya7jBWUttuLuitljJyYxB0l3Ae-cDcg0Vi9Q_0ed8wPhajv-XJpX5jH1nLpzhml_U4nGAHHy4CGvuPIpgnuJkfS5s19mxIcBX-SbFUFd1jrNRalkigpqetX1c6jZjbMIxmd6lfvz8jIsoHLkmhhSSJvdhUMNDtZSYoe1WAn9R5cYNhXtl3kUC0rufllwrIdOUC';

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No hay resultados para mostrar en el mapa.',
            style: AppTextStyles.bodyMd,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final selected = items.firstWhere(
      (item) => item.merchantId == selectedMerchantId,
      orElse: () => items.first,
    );

    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              flex: 6,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    _mapImage,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFFCEE2D7),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.neutral50.withValues(alpha: 0.7),
                            Colors.transparent,
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: _MapToggle(onListTap: onListTap),
                    ),
                  ),
                  ..._buildPins(selectedId: selected.merchantId),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Container(
                color: AppColors.neutral50,
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(
                          'RESULTADOS CERCA DE TI',
                          style: AppTextStyles.labelSm.copyWith(
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${items.length} lugares',
                          style: AppTextStyles.labelSm.copyWith(
                            color: AppColors.primary500,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.only(bottom: 130),
                        itemCount: items.length.clamp(1, 4),
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, index) {
                          final item = items[index];
                          return _MapResultTile(
                            item: item,
                            highlighted: item.merchantId == selected.merchantId,
                            onTap: () => onPinTap(item.merchantId),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 76,
          child: _SelectedBottomCard(
            item: selected,
            onTapDirections: () => onCardTap(selected.merchantId),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildPins({required String selectedId}) {
    final positions = <({double top, double left})>[
      (top: 220, left: 182),
      (top: 164, left: 96),
      (top: 282, left: 84),
      (top: 152, left: 248),
      (top: 250, left: 260),
    ];

    return items.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      final pos = positions[index % positions.length];
      final selected = item.merchantId == selectedId;
      return Positioned(
        top: pos.top,
        left: pos.left,
        child: GestureDetector(
          onTap: () => onPinTap(item.merchantId),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: selected ? 62 : 48,
            height: selected ? 62 : 48,
            decoration: BoxDecoration(
              color: selected ? AppColors.primary500 : AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? AppColors.surface : AppColors.primary100,
                width: selected ? 4 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.neutral900.withValues(alpha: 0.18),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              _iconForCategory(item.categoryId),
              color: selected ? AppColors.surface : AppColors.primary500,
              size: selected ? 30 : 24,
            ),
          ),
        ),
      );
    }).toList(growable: false);
  }

  static IconData _iconForCategory(String categoryId) {
    final value = categoryId.toLowerCase();
    if (value.contains('pharmacy') || value.contains('farm')) {
      return Icons.local_pharmacy;
    }
    if (value.contains('kiosk')) {
      return Icons.local_mall;
    }
    if (value.contains('veter')) {
      return Icons.pets;
    }
    if (value.contains('food') || value.contains('restaurant')) {
      return Icons.restaurant;
    }
    return Icons.coffee;
  }
}

class _MapToggle extends StatelessWidget {
  const _MapToggle({required this.onListTap});

  final VoidCallback onListTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.neutral900.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
            decoration: BoxDecoration(
              color: AppColors.primary500,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.map, color: AppColors.surface, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Mapa',
                  style: AppTextStyles.labelMd.copyWith(
                    color: AppColors.surface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onListTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              child: Row(
                children: [
                  const Icon(Icons.list, color: AppColors.neutral700, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Ver lista',
                    style: AppTextStyles.labelMd.copyWith(
                      color: AppColors.neutral700,
                      fontWeight: FontWeight.w700,
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
}

class _MapResultTile extends StatelessWidget {
  const _MapResultTile({
    required this.item,
    required this.highlighted,
    required this.onTap,
  });

  final MerchantSearchItem item;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final distanceText = item.distanceMeters == null
        ? ''
        : '${(item.distanceMeters! / 1000).toStringAsFixed(1)} km';
    final subtitle =
        item.address.trim().isEmpty ? item.categoryLabel : item.address.trim();

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: highlighted ? AppColors.primary50 : AppColors.neutral100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: highlighted ? AppColors.primary200 : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: AppColors.neutral200,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(
                SearchResultsMap._iconForCategory(item.categoryId),
                color: AppColors.primary500,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: AppTextStyles.labelMd.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodyXs,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Text(
              distanceText,
              style: AppTextStyles.bodyXs.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedBottomCard extends StatelessWidget {
  const _SelectedBottomCard({
    required this.item,
    required this.onTapDirections,
  });

  final MerchantSearchItem item;
  final VoidCallback onTapDirections;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.neutral900.withValues(alpha: 0.15),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: AppColors.neutral200,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(
                  SearchResultsMap._iconForCategory(item.categoryId),
                  color: AppColors.primary500,
                  size: 30,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.isOpenNow == true ? 'ABIERTO AHORA' : 'CERRADO',
                      style: AppTextStyles.bodyXs.copyWith(
                        color: AppColors.secondary500,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                    Text(
                      item.name,
                      style: AppTextStyles.headingSm.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      item.distanceMeters == null
                          ? 'Sin distancia disponible'
                          : 'a ${item.distanceMeters!.round()}m de tu ubicación',
                      style: AppTextStyles.bodyXs,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  colors: [Color(0xFF0044AA), Color(0xFF0E5BD8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: onTapDirections,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.directions,
                          color: AppColors.surface,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Cómo llegar',
                          style: AppTextStyles.labelMd.copyWith(
                            color: AppColors.surface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
