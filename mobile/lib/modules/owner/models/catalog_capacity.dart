import 'merchant_product.dart';

enum CatalogLimitSource {
  merchantOverride('merchant_override'),
  categoryOverride('category_override'),
  globalDefault('global_default');

  const CatalogLimitSource(this.value);
  final String value;

  String get label {
    switch (this) {
      case CatalogLimitSource.merchantOverride:
        return 'Excepción individual';
      case CatalogLimitSource.categoryOverride:
        return 'Regla por categoría';
      case CatalogLimitSource.globalDefault:
        return 'Regla global';
    }
  }
}

class OwnerCatalogLimitsConfig {
  const OwnerCatalogLimitsConfig({
    required this.defaultProductLimit,
    required this.categoryLimits,
  });

  final int defaultProductLimit;
  final Map<String, int> categoryLimits;

  factory OwnerCatalogLimitsConfig.fromMap(Map<String, dynamic> data) {
    final defaultLimit = _parsePositiveInt(data['defaultProductLimit']) ?? 100;
    final rawCategoryLimits = data['categoryLimits'];
    final parsedCategoryLimits = <String, int>{};
    if (rawCategoryLimits is Map) {
      for (final entry in rawCategoryLimits.entries) {
        final key = normalizeProductName(entry.key.toString());
        final value = _parsePositiveInt(entry.value);
        if (key.isEmpty || value == null) continue;
        parsedCategoryLimits[key] = value;
      }
    }
    return OwnerCatalogLimitsConfig(
      defaultProductLimit: defaultLimit,
      categoryLimits: parsedCategoryLimits,
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

class OwnerCatalogCapacity {
  const OwnerCatalogCapacity({
    required this.used,
    required this.limit,
    required this.remaining,
    required this.usageRatio,
    required this.usagePercent,
    required this.source,
  });

  final int used;
  final int limit;
  final int remaining;
  final double usageRatio;
  final int usagePercent;
  final CatalogLimitSource source;

  bool get isWarning => usageRatio >= 0.8 && usageRatio < 1;
  bool get isBlocked => usageRatio >= 1;
}

OwnerCatalogCapacity resolveOwnerCatalogCapacity({
  required String categoryId,
  required int activeProductCount,
  required int? merchantLimitOverride,
  required OwnerCatalogLimitsConfig config,
}) {
  final normalizedCategoryId = normalizeProductName(categoryId);
  final overrideLimit = _parsePositiveInt(merchantLimitOverride);
  final categoryLimit = config.categoryLimits[normalizedCategoryId];

  final resolved = overrideLimit ??
      (categoryLimit != null && categoryLimit > 0
          ? categoryLimit
          : config.defaultProductLimit);

  final source = overrideLimit != null
      ? CatalogLimitSource.merchantOverride
      : (categoryLimit != null && categoryLimit > 0
          ? CatalogLimitSource.categoryOverride
          : CatalogLimitSource.globalDefault);

  final safeUsed = activeProductCount < 0 ? 0 : activeProductCount;
  final safeLimit = resolved <= 0 ? 1 : resolved;
  final usageRatio = safeUsed / safeLimit;
  final usagePercent = (usageRatio * 100).round();

  return OwnerCatalogCapacity(
    used: safeUsed,
    limit: safeLimit,
    remaining: (safeLimit - safeUsed).clamp(0, safeLimit),
    usageRatio: usageRatio,
    usagePercent: usagePercent,
    source: source,
  );
}

int? _parsePositiveInt(Object? value) {
  if (value is int && value > 0) return value;
  if (value is num && value > 0 && value == value.toInt()) {
    return value.toInt();
  }
  return null;
}
