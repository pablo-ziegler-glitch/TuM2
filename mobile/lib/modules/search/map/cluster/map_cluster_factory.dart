import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'map_cluster_model.dart';
import 'map_cluster_style.dart';

class MapClusterFactory {
  final Map<String, Future<BitmapDescriptor>> _cache = {};

  Future<BitmapDescriptor> resolveIcon({
    required MapClusterPriority priority,
    required int count,
    required double pixelRatio,
  }) {
    final displayCount = _displayCount(count);
    final size = MapClusterStyle.resolveSizeDp(count);
    final key =
        '${priority.name}@${size.toStringAsFixed(0)}@$displayCount@${pixelRatio.toStringAsFixed(2)}';

    return _cache.putIfAbsent(key, () async {
      if (kIsWeb) {
        return _fallback(priority);
      }
      try {
        final bytes = await _renderBytes(
          priority: priority,
          countLabel: displayCount,
          sizeDp: size,
          pixelRatio: pixelRatio,
        );
        return BitmapDescriptor.bytes(bytes);
      } catch (_) {
        return _fallback(priority);
      }
    });
  }

  void clear() {
    _cache.clear();
  }

  Future<Uint8List> _renderBytes({
    required MapClusterPriority priority,
    required String countLabel,
    required double sizeDp,
    required double pixelRatio,
  }) async {
    final sizePx = (sizeDp * pixelRatio).round();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, sizePx.toDouble(), sizePx.toDouble()),
    );

    final color = MapClusterStyle.resolveColor(priority);
    final center = Offset(sizePx / 2, sizePx / 2);
    final radius = sizePx / 2;

    final fill = Paint()..color = color;
    canvas.drawCircle(center, radius, fill);

    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = (sizePx / 20).clamp(1.5, 3.0);
    canvas.drawCircle(center, radius - border.strokeWidth / 2, border);

    final textPainter = TextPainter(
      text: TextSpan(
        text: countLabel,
        style: TextStyle(
          color: Colors.white,
          fontSize: sizePx * 0.34,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(sizePx, sizePx);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw StateError('No se pudo renderizar cluster bitmap.');
    }
    return byteData.buffer.asUint8List();
  }

  BitmapDescriptor _fallback(MapClusterPriority priority) {
    final hue = switch (priority) {
      MapClusterPriority.guardia => BitmapDescriptor.hueRed,
      MapClusterPriority.open => BitmapDescriptor.hueGreen,
      MapClusterPriority.defaultState => BitmapDescriptor.hueBlue,
      MapClusterPriority.closed => BitmapDescriptor.hueOrange,
    };
    return BitmapDescriptor.defaultMarkerWithHue(hue);
  }

  String _displayCount(int count) {
    if (count > 99) return '99+';
    return '$count';
  }
}
