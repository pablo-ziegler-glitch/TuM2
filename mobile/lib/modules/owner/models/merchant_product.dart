import 'dart:collection';

import 'package:cloud_firestore/cloud_firestore.dart';

const int productNameMaxLength = 80;
const int productPriceLabelMaxLength = 60;
const int productDescriptionMaxLength = 180;

enum ProductStockStatus {
  available('available'),
  outOfStock('out_of_stock');

  const ProductStockStatus(this.value);
  final String value;

  static ProductStockStatus fromValue(String? value) {
    return ProductStockStatus.values.firstWhere(
      (item) => item.value == value,
      orElse: () => ProductStockStatus.available,
    );
  }
}

enum ProductVisibilityStatus {
  visible('visible'),
  hidden('hidden');

  const ProductVisibilityStatus(this.value);
  final String value;

  static ProductVisibilityStatus fromValue(String? value) {
    return ProductVisibilityStatus.values.firstWhere(
      (item) => item.value == value,
      orElse: () => ProductVisibilityStatus.visible,
    );
  }
}

enum ProductStatus {
  active('active'),
  inactive('inactive');

  const ProductStatus(this.value);
  final String value;

  static ProductStatus fromValue(String? value) {
    return ProductStatus.values.firstWhere(
      (item) => item.value == value,
      orElse: () => ProductStatus.active,
    );
  }
}

enum ProductPriceMode {
  none('none'),
  fixed('fixed'),
  consult('consult');

  const ProductPriceMode(this.value);
  final String value;

  static ProductPriceMode fromValue(
    String? value, {
    String? priceLabel,
  }) {
    final normalized = (value ?? '').trim().toLowerCase();
    for (final item in ProductPriceMode.values) {
      if (item.value == normalized) return item;
    }
    final normalizedPrice =
        normalizeProductField(priceLabel ?? '').toLowerCase();
    if (normalizedPrice.isEmpty) return ProductPriceMode.none;
    if (normalizedPrice.contains('consult')) return ProductPriceMode.consult;
    return ProductPriceMode.fixed;
  }
}

enum ProductImageUploadStatus {
  pending('pending'),
  ready('ready'),
  failed('failed');

  const ProductImageUploadStatus(this.value);
  final String value;

  static ProductImageUploadStatus? fromValue(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    for (final item in ProductImageUploadStatus.values) {
      if (item.value == value) return item;
    }
    return null;
  }
}

class MerchantProduct {
  const MerchantProduct({
    required this.id,
    required this.merchantId,
    required this.ownerUserId,
    required this.name,
    required this.normalizedName,
    required this.description,
    required this.priceLabel,
    required this.priceMode,
    required this.stockStatus,
    required this.visibilityStatus,
    required this.status,
    required this.sourceType,
    required this.createdBy,
    required this.updatedBy,
    this.imageUrl,
    this.imagePath,
    this.imageUploadStatus,
    this.sortOrder,
    this.searchKeywords,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String merchantId;
  final String ownerUserId;
  final String name;
  final String normalizedName;
  final String description;
  final String priceLabel;
  final ProductPriceMode priceMode;
  final ProductStockStatus stockStatus;
  final ProductVisibilityStatus visibilityStatus;
  final ProductStatus status;
  final String sourceType;
  final String createdBy;
  final String updatedBy;
  final String? imageUrl;
  final String? imagePath;
  final ProductImageUploadStatus? imageUploadStatus;
  final int? sortOrder;
  final List<String>? searchKeywords;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isInactive => status == ProductStatus.inactive;
  bool get isVisible => visibilityStatus == ProductVisibilityStatus.visible;
  bool get isAvailable => stockStatus == ProductStockStatus.available;
  bool get isPubliclyVisible => !isInactive && isVisible;
  bool get hasImage => (imageUrl ?? '').trim().isNotEmpty;
  bool get hasDescription => description.trim().isNotEmpty;

  String get displayPriceLabel {
    if (priceMode == ProductPriceMode.consult) return 'Consultar precio';
    if (priceMode == ProductPriceMode.none) return '';
    return priceLabel;
  }

  MerchantProduct copyWith({
    String? id,
    String? merchantId,
    String? ownerUserId,
    String? name,
    String? normalizedName,
    String? description,
    String? priceLabel,
    ProductPriceMode? priceMode,
    ProductStockStatus? stockStatus,
    ProductVisibilityStatus? visibilityStatus,
    ProductStatus? status,
    String? sourceType,
    String? createdBy,
    String? updatedBy,
    String? imageUrl,
    bool clearImageUrl = false,
    String? imagePath,
    bool clearImagePath = false,
    ProductImageUploadStatus? imageUploadStatus,
    bool clearImageUploadStatus = false,
    int? sortOrder,
    bool clearSortOrder = false,
    List<String>? searchKeywords,
    bool clearSearchKeywords = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MerchantProduct(
      id: id ?? this.id,
      merchantId: merchantId ?? this.merchantId,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      name: name ?? this.name,
      normalizedName: normalizedName ?? this.normalizedName,
      description: description ?? this.description,
      priceLabel: priceLabel ?? this.priceLabel,
      priceMode: priceMode ?? this.priceMode,
      stockStatus: stockStatus ?? this.stockStatus,
      visibilityStatus: visibilityStatus ?? this.visibilityStatus,
      status: status ?? this.status,
      sourceType: sourceType ?? this.sourceType,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      imageUrl: clearImageUrl ? null : (imageUrl ?? this.imageUrl),
      imagePath: clearImagePath ? null : (imagePath ?? this.imagePath),
      imageUploadStatus: clearImageUploadStatus
          ? null
          : (imageUploadStatus ?? this.imageUploadStatus),
      sortOrder: clearSortOrder ? null : (sortOrder ?? this.sortOrder),
      searchKeywords:
          clearSearchKeywords ? null : (searchKeywords ?? this.searchKeywords),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory MerchantProduct.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    return MerchantProduct.fromMap(document.id, document.data() ?? const {});
  }

  factory MerchantProduct.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    final name = normalizeProductField(data['name'] as String? ?? '');
    final normalizedName = normalizeProductName(
      data['normalizedName'] as String? ?? name,
    );
    final description =
        normalizeProductField(data['description'] as String? ?? '');
    final priceLabel =
        normalizeProductField(data['priceLabel'] as String? ?? '');
    final priceMode = ProductPriceMode.fromValue(
      data['priceMode'] as String?,
      priceLabel: priceLabel,
    );

    return MerchantProduct(
      id: id,
      merchantId: normalizeProductField(data['merchantId'] as String? ?? ''),
      ownerUserId: normalizeProductField(data['ownerUserId'] as String? ?? ''),
      name: name,
      normalizedName: normalizedName,
      description: description,
      priceLabel: priceLabel,
      priceMode: priceMode,
      stockStatus: ProductStockStatus.fromValue(
        (data['stockStatus'] as String?)?.trim().toLowerCase(),
      ),
      visibilityStatus: ProductVisibilityStatus.fromValue(
        (data['visibilityStatus'] as String?)?.trim().toLowerCase(),
      ),
      status: ProductStatus.fromValue(
        (data['status'] as String?)?.trim().toLowerCase(),
      ),
      imageUrl: normalizeNullableProductField(data['imageUrl'] as String?),
      imagePath: normalizeNullableProductField(data['imagePath'] as String?),
      imageUploadStatus: ProductImageUploadStatus.fromValue(
        (data['imageUploadStatus'] as String?)?.trim().toLowerCase(),
      ),
      sourceType: normalizeProductField(
        data['sourceType'] as String? ?? 'owner_created',
      ),
      sortOrder: (data['sortOrder'] as num?)?.toInt(),
      searchKeywords: _readStringList(data['searchKeywords']),
      createdAt: _readDate(data['createdAt']),
      updatedAt: _readDate(data['updatedAt']),
      createdBy: normalizeProductField(data['createdBy'] as String? ?? ''),
      updatedBy: normalizeProductField(data['updatedBy'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'id': id,
      'merchantId': merchantId,
      'ownerUserId': ownerUserId,
      'name': name,
      'normalizedName': normalizedName,
      'description': description,
      'searchKeywords': searchKeywords ?? buildProductSearchKeywords(name),
      'priceLabel': priceLabel,
      'priceMode': priceMode.value,
      'stockStatus': stockStatus.value,
      'visibilityStatus': visibilityStatus.value,
      'status': status.value,
      'sourceType': sourceType,
      if (imageUrl != null && imageUrl!.trim().isNotEmpty) 'imageUrl': imageUrl,
      if (imagePath != null && imagePath!.trim().isNotEmpty)
        'imagePath': imagePath,
      if (imageUploadStatus != null)
        'imageUploadStatus': imageUploadStatus!.value,
      if (sortOrder != null) 'sortOrder': sortOrder,
      'createdBy': createdBy,
      'updatedBy': updatedBy,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }

  static List<String>? _readStringList(Object? value) {
    if (value is! List) return null;
    final items = value
        .whereType<String>()
        .map(normalizeProductField)
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    return items.isEmpty ? null : items;
  }

  static DateTime? _readDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

/// Normaliza el nombre para búsquedas simples sin dependencias externas.
String normalizeProductName(String input) {
  final lower = normalizeProductField(input).toLowerCase();
  if (lower.isEmpty) return '';

  var normalized = lower;
  _diacriticMap.forEach((key, value) {
    normalized = normalized.replaceAll(key, value);
  });

  normalized = normalized
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return normalized;
}

String normalizeProductField(String input) {
  return input.trim().replaceAll(RegExp(r'\s+'), ' ');
}

String? normalizeNullableProductField(String? input) {
  if (input == null) return null;
  final normalized = normalizeProductField(input);
  return normalized.isEmpty ? null : normalized;
}

List<String> buildProductSearchKeywords(String name) {
  final normalizedName = normalizeProductName(name);
  if (normalizedName.isEmpty) return const [];

  final keywords = SplayTreeSet<String>()..add(normalizedName);
  final parts = normalizedName.split(' ');
  for (final part in parts) {
    if (part.isEmpty) continue;
    final minPrefixLength = part.length >= 2 ? 2 : 1;
    for (var size = minPrefixLength; size <= part.length; size++) {
      keywords.add(part.substring(0, size));
    }
  }
  return UnmodifiableListView<String>(keywords);
}

String? validateProductName(String value) {
  final normalized = normalizeProductField(value);
  if (normalized.isEmpty) return 'Ingresá el nombre del producto.';
  if (normalized.length < 2) {
    return 'El nombre debe tener al menos 2 caracteres.';
  }
  if (normalized.length > productNameMaxLength) {
    return 'El nombre no puede superar $productNameMaxLength caracteres.';
  }
  return null;
}

String? validateProductPriceLabel(
  String value, {
  int maxLength = productPriceLabelMaxLength,
  required ProductPriceMode mode,
}) {
  final normalized = normalizeProductField(value);
  if (mode == ProductPriceMode.none || mode == ProductPriceMode.consult) {
    if (normalized.length > maxLength) {
      return 'El precio no puede superar $maxLength caracteres.';
    }
    return null;
  }
  if (normalized.isEmpty) return 'Ingresá un precio válido o dejalo vacío.';
  if (normalized.length > maxLength) {
    return 'El precio no puede superar $maxLength caracteres.';
  }
  return null;
}

String? validateProductDescription(
  String value, {
  int maxLength = productDescriptionMaxLength,
}) {
  final normalized = normalizeProductField(value);
  if (normalized.length > maxLength) {
    return 'La descripción no puede superar $maxLength caracteres.';
  }
  return null;
}

const Map<String, String> _diacriticMap = {
  'á': 'a',
  'à': 'a',
  'ä': 'a',
  'â': 'a',
  'ã': 'a',
  'å': 'a',
  'é': 'e',
  'è': 'e',
  'ë': 'e',
  'ê': 'e',
  'í': 'i',
  'ì': 'i',
  'ï': 'i',
  'î': 'i',
  'ó': 'o',
  'ò': 'o',
  'ö': 'o',
  'ô': 'o',
  'õ': 'o',
  'ú': 'u',
  'ù': 'u',
  'ü': 'u',
  'û': 'u',
  'ñ': 'n',
  'ç': 'c',
};
