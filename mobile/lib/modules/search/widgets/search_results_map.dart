import 'dart:math' as math;

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
  final ValueChanged<String> onPinTap;
  final ValueChanged<String> onCardTap;

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

    final selected = items.cast<MerchantSearchItem?>().firstWhere(
          (item) => item?.merchantId == selectedMerchantId,
          orElse: () => items.first,
        )!;

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
                          final highlighted =
                              item.merchantId == selected.merchantId;
                          return _MapResultTile(
                            item: item,
                            highlighted: highlighted,
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
      return const Center(
        child: Text('Sin resultados para mostrar en mapa'),
      );
    }

    MerchantSearchItem selected = items.first;
    for (final item in items) {
      if (item.merchantId == selectedMerchantId) {
        selected = item;
        break;
      }
    }
    final points = _buildPoints(items);

    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFE8F3EC), Color(0xFFDCEEE3)],
            ),
          ),
          child: CustomPaint(
            painter: _GridPainter(),
            size: Size.infinite,
          ),
        ),
        ...points.map(
          (point) => Positioned(
            left: point.dx,
            top: point.dy,
            child: _Pin(
              item: point.item,
              selected: point.item.merchantId == selected.merchantId,
              onTap: () => onPinTap(point.item.merchantId),
            ),
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: _CompactMerchantCard(
            item: selected,
            onTap: () => onCardTap(selected.merchantId),
          ),
        ),
      ],
    );
  }

  List<_MapPoint> _buildPoints(List<MerchantSearchItem> items) {
    final withCoordinates =
        items.where((item) => item.lat != null && item.lng != null).toList();
    final hasRealCoordinates = withCoordinates.length >= 2;

    if (hasRealCoordinates) {
      final lats = withCoordinates.map((item) => item.lat!).toList();
      final lngs = withCoordinates.map((item) => item.lng!).toList();
      final minLat = lats.reduce(math.min);
      final maxLat = lats.reduce(math.max);
      final minLng = lngs.reduce(math.min);
      final maxLng = lngs.reduce(math.max);
      final latRange =
          (maxLat - minLat).abs() < 0.0001 ? 0.0001 : (maxLat - minLat);
      final lngRange =
          (maxLng - minLng).abs() < 0.0001 ? 0.0001 : (maxLng - minLng);

      return items.map((item) {
        final normalizedX = item.lng == null
            ? _fallbackRatio(item.merchantId)
            : (item.lng! - minLng) / lngRange;
        final normalizedY = item.lat == null
            ? _fallbackRatio(item.name)
            : (item.lat! - minLat) / latRange;
        return _MapPoint(
          dx: _clamp((normalizedX * 280) + 18, 10, 300),
          dy: _clamp((1 - normalizedY) * 320 + 24, 16, 340),
          item: item,
        );
      }).toList();
    }

    return items.map((item) {
      final x = _clamp((_fallbackRatio(item.merchantId) * 300) + 8, 8, 300);
      final y = _clamp((_fallbackRatio(item.name) * 330) + 12, 12, 340);
      return _MapPoint(dx: x, dy: y, item: item);
    }).toList();
  }

  double _fallbackRatio(String input) {
    final hash = input.codeUnits
        .fold<int>(0, (acc, value) => (acc * 31 + value) & 0x7fffffff);
    return (hash % 1000) / 1000;
  }

  double _clamp(double value, double min, double max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }
}

class _CompactMerchantCard extends StatelessWidget {
  const _CompactMerchantCard({
    required this.item,
    required this.onTap,
  });

  final MerchantSearchItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.labelMd,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.address.isEmpty
                          ? 'Sin dirección cargada'
                          : item.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyXs,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final MerchantSearchItem item;
  final bool highlighted;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
                    item.addressSummary.isEmpty
                        ? item.categoryLabel
                        : item.addressSummary,
                    style: AppTextStyles.bodyXs,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Text(
              item.distanceMeters == null
                  ? ''
                  : '${(item.distanceMeters! / 1000).toStringAsFixed(1)} km',
              style: AppTextStyles.bodyXs.copyWith(fontWeight: FontWeight.w700),
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
                          : 'a ${item.distanceMeters}m de tu ubicación',
                      style: AppTextStyles.bodyXs,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.star, color: AppColors.tertiary500, size: 18),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
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
                            const Icon(Icons.directions,
                                color: AppColors.surface, size: 20),
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
              const SizedBox(width: 10),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.neutral100,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.favorite, color: AppColors.primary500),
              ),
            ],
          ),
        ],
      ),
    );
  }
    final color = switch (item.isOpenNow) {
      true => const Color(0xFF2E7D32),
      false => const Color(0xFFC62828),
      null => const Color(0xFF757575),
    };

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: selected ? 34 : 30,
        height: selected ? 34 : 30,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color:
                selected ? Colors.white : Colors.black.withValues(alpha: 0.15),
            width: selected ? 3 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.location_on, size: 16, color: Colors.white),
      ),
    );
  }
}

class _MapPoint {
  _MapPoint({
    required this.dx,
    required this.dy,
    required this.item,
  });

  final double dx;
  final double dy;
  final MerchantSearchItem item;
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFBBD1C2)
      ..strokeWidth = 1;
    const step = 36.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
