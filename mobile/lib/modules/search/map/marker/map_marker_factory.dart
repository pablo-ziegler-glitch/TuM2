import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../models/merchant_search_item.dart';
import 'map_marker_bitmap_cache.dart';
import 'map_marker_resolver.dart';
import 'map_marker_style.dart';
import 'map_marker_type.dart';
import 'map_marker_visual_type.dart';

class MapMarkerSpec {
  const MapMarkerSpec({
    required this.baseType,
    required this.visualType,
    required this.zIndex,
  });

  final MapMarkerType baseType;
  final MapMarkerVisualType visualType;
  final double zIndex;
}

class MapMarkerFactory {
  MapMarkerFactory({
    MapMarkerBitmapCache? bitmapCache,
  }) : _bitmapCache = bitmapCache ?? MapMarkerBitmapCache();

  final MapMarkerBitmapCache _bitmapCache;

  MapMarkerSpec resolveSpec({
    required MerchantSearchItem merchant,
    required bool isSelected,
  }) {
    final baseType = MapMarkerResolver.resolveBaseType(merchant);
    final visualType = MapMarkerResolver.resolveVisualType(
      baseType: baseType,
      isSelected: isSelected,
    );
    return MapMarkerSpec(
      baseType: baseType,
      visualType: visualType,
      zIndex: MapMarkerResolver.resolveMarkerZIndex(visualType),
    );
  }

  Future<BitmapDescriptor> resolveIcon({
    required MapMarkerVisualType visualType,
    required double pixelRatio,
  }) {
    return _bitmapCache.getOrCreate(
      visualType: visualType,
      pixelRatio: pixelRatio,
      loader: _buildIcon,
    );
  }

  Future<BitmapDescriptor> _buildIcon(
    MapMarkerVisualType visualType,
    double pixelRatio,
  ) async {
    final baseType = _baseTypeFromVisual(visualType);
    if (kIsWeb) {
      return _fallbackForBaseType(baseType);
    }

    try {
      final bytes = await _renderBytes(
        visualType: visualType,
        pixelRatio: pixelRatio,
      );
      return BitmapDescriptor.bytes(bytes);
    } catch (_) {
      return _fallbackForBaseType(baseType);
    }
  }

  Future<Uint8List> _renderBytes({
    required MapMarkerVisualType visualType,
    required double pixelRatio,
  }) async {
    final sizeDp = MapMarkerStyle.sizeForVisualType(visualType);
    final sizePx = (sizeDp * pixelRatio).round();
    final selected = _isSelected(visualType);
    final baseType = _baseTypeFromVisual(visualType);
    final color = MapMarkerStyle.colorForBaseType(baseType);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, sizePx.toDouble(), sizePx.toDouble()),
    );

    _drawMarker(
      canvas: canvas,
      sizePx: sizePx.toDouble(),
      color: color,
      selected: selected,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(sizePx, sizePx);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) {
      throw StateError('No se pudo renderizar bitmap de marker.');
    }
    return data.buffer.asUint8List();
  }

  void _drawMarker({
    required Canvas canvas,
    required double sizePx,
    required Color color,
    required bool selected,
  }) {
    final inset = sizePx * 0.22;
    final path = Path()
      ..addPolygon([
        Offset(inset, 0),
        Offset(sizePx - inset, 0),
        Offset(sizePx, inset),
        Offset(sizePx, sizePx - inset),
        Offset(sizePx - inset, sizePx),
        Offset(inset, sizePx),
        Offset(0, sizePx - inset),
        Offset(0, inset),
      ], true);

    final fillPaint = Paint()..color = color;
    canvas.drawPath(path, fillPaint);

    if (selected) {
      final borderPaint = Paint()
        ..color = MapMarkerStyle.selectedBorderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = MapMarkerStyle.selectedBorderWidthDp * (sizePx / 40);
      canvas.drawPath(path, borderPaint);
    }

    final center = Offset(sizePx / 2, sizePx / 2);
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'M²',
        style: TextStyle(
          color: MapMarkerStyle.onMarkerColor,
          fontSize: sizePx * 0.4,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );
  }

  BitmapDescriptor _fallbackForBaseType(MapMarkerType baseType) {
    final hue = switch (baseType) {
      MapMarkerType.guardia => BitmapDescriptor.hueRed,
      MapMarkerType.open => BitmapDescriptor.hueGreen,
      MapMarkerType.open24h => BitmapDescriptor.hueAzure,
      MapMarkerType.defaultState => BitmapDescriptor.hueBlue,
      MapMarkerType.closed => BitmapDescriptor.hueOrange,
    };
    return BitmapDescriptor.defaultMarkerWithHue(hue);
  }

  static bool _isSelected(MapMarkerVisualType visualType) {
    switch (visualType) {
      case MapMarkerVisualType.selectedGuardia:
      case MapMarkerVisualType.selectedOpen:
      case MapMarkerVisualType.selectedOpen24h:
      case MapMarkerVisualType.selectedDefaultState:
      case MapMarkerVisualType.selectedClosed:
        return true;
      case MapMarkerVisualType.guardia:
      case MapMarkerVisualType.open:
      case MapMarkerVisualType.open24h:
      case MapMarkerVisualType.defaultState:
      case MapMarkerVisualType.closed:
        return false;
    }
  }

  static MapMarkerType _baseTypeFromVisual(MapMarkerVisualType visualType) {
    switch (visualType) {
      case MapMarkerVisualType.guardia:
      case MapMarkerVisualType.selectedGuardia:
        return MapMarkerType.guardia;
      case MapMarkerVisualType.open:
      case MapMarkerVisualType.selectedOpen:
        return MapMarkerType.open;
      case MapMarkerVisualType.open24h:
      case MapMarkerVisualType.selectedOpen24h:
        return MapMarkerType.open24h;
      case MapMarkerVisualType.defaultState:
      case MapMarkerVisualType.selectedDefaultState:
        return MapMarkerType.defaultState;
      case MapMarkerVisualType.closed:
      case MapMarkerVisualType.selectedClosed:
        return MapMarkerType.closed;
    }
  }
}
