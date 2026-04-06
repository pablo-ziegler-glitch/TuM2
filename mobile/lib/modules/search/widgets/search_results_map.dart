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
  });

  final List<MerchantSearchItem> items;
  final String? selectedMerchantId;
  final ValueChanged<String> onPinTap;
  final ValueChanged<String> onCardTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
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
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
