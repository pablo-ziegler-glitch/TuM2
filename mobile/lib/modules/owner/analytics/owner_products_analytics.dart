import 'package:firebase_analytics/firebase_analytics.dart';

import '../models/merchant_product.dart';

abstract class OwnerProductsAnalytics {
  static FirebaseAnalytics? get _analytics {
    try {
      return FirebaseAnalytics.instance;
    } catch (_) {
      return null;
    }
  }

  static Future<void> logCreated({
    required String merchantId,
    required String productId,
    required bool hasImage,
    required ProductStockStatus stockStatus,
    required ProductVisibilityStatus visibilityStatus,
    required int latencyMs,
  }) =>
      _safeLog(
        'product_created',
        parameters: _baseParams(
          merchantId: merchantId,
          productId: productId,
          hasImage: hasImage,
          stockStatus: stockStatus,
          visibilityStatus: visibilityStatus,
          latencyMs: latencyMs,
        ),
      );

  static Future<void> logEdited({
    required String merchantId,
    required String productId,
    required bool hasImage,
    required ProductStockStatus stockStatus,
    required ProductVisibilityStatus visibilityStatus,
    required int latencyMs,
  }) =>
      _safeLog(
        'product_edited',
        parameters: _baseParams(
          merchantId: merchantId,
          productId: productId,
          hasImage: hasImage,
          stockStatus: stockStatus,
          visibilityStatus: visibilityStatus,
          latencyMs: latencyMs,
        ),
      );

  static Future<void> logDeactivated({
    required String merchantId,
    required String productId,
  }) =>
      _safeLog(
        'product_deactivated',
        parameters: {
          'merchant_id': merchantId,
          'product_id': productId,
          'source': 'owner',
        },
      );

  static Future<void> logVisibilityChanged({
    required String merchantId,
    required String productId,
    required ProductVisibilityStatus visibilityStatus,
  }) async {
    final eventName = visibilityStatus == ProductVisibilityStatus.hidden
        ? 'product_hidden'
        : 'product_made_visible';
    await _safeLog(
      eventName,
      parameters: {
        'merchant_id': merchantId,
        'product_id': productId,
        'visibility_status': visibilityStatus.value,
        'source': 'owner',
      },
    );
  }

  static Future<void> logImageUploaded({
    required String merchantId,
    required String productId,
    required int imageSizeBytes,
    required int latencyMs,
  }) =>
      _safeLog(
        'product_image_uploaded',
        parameters: {
          'merchant_id': merchantId,
          'product_id': productId,
          'image_size_bytes': imageSizeBytes,
          'latency_ms': latencyMs,
          'source': 'owner',
        },
      );

  static Future<void> logImageUploadFailed({
    required String merchantId,
    required String productId,
    required String reason,
  }) =>
      _safeLog(
        'product_image_upload_failed',
        parameters: {
          'merchant_id': merchantId,
          'product_id': productId,
          'reason': reason,
          'source': 'owner',
        },
      );

  static Future<void> logCatalogLimitWarningSeen({
    required String merchantId,
    required int used,
    required int limit,
    required String source,
  }) =>
      _safeLog(
        'owner_catalog_limit_warning_seen',
        parameters: {
          'merchant_id': merchantId,
          'used': used,
          'limit': limit,
          'source': source,
        },
      );

  static Future<void> logCatalogLimitBlockSeen({
    required String merchantId,
    required int used,
    required int limit,
    required String source,
  }) =>
      _safeLog(
        'owner_catalog_limit_block_seen',
        parameters: {
          'merchant_id': merchantId,
          'used': used,
          'limit': limit,
          'source': source,
        },
      );

  static Future<void> logCatalogContactAdmin({
    required String merchantId,
    required String source,
  }) =>
      _safeLog(
        'owner_contact_admin_from_catalog_limit',
        parameters: {
          'merchant_id': merchantId,
          'source': source,
        },
      );

  static Future<void> logProductCreateBlockedByLimit({
    required String merchantId,
    required int used,
    required int limit,
    required String source,
  }) =>
      _safeLog(
        'owner_product_create_blocked_by_limit',
        parameters: {
          'merchant_id': merchantId,
          'used': used,
          'limit': limit,
          'source': source,
        },
      );

  static Map<String, Object> _baseParams({
    required String merchantId,
    required String productId,
    required bool hasImage,
    required ProductStockStatus stockStatus,
    required ProductVisibilityStatus visibilityStatus,
    required int latencyMs,
  }) {
    return {
      'merchant_id': merchantId,
      'product_id': productId,
      'has_image': hasImage,
      'stock_status': stockStatus.value,
      'visibility_status': visibilityStatus.value,
      'latency_ms': latencyMs,
      'source': 'owner',
    };
  }

  static Future<void> _safeLog(
    String eventName, {
    Map<String, Object>? parameters,
  }) async {
    final analytics = _analytics;
    if (analytics == null) return;
    try {
      await analytics.logEvent(name: eventName, parameters: parameters);
    } catch (_) {
      // Analytics nunca debe romper el flujo principal.
    }
  }
}
