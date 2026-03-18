import 'package:cloud_firestore/cloud_firestore.dart';

enum StockStatus { available, low, out }

class ProductModel {
  final String id;
  final String storeId;
  final String name;
  final String description;
  final double price;
  final StockStatus stockStatus;
  final List<String> imageUrls;
  final bool isVisible;
  final DateTime updatedAt;

  const ProductModel({
    required this.id,
    required this.storeId,
    required this.name,
    required this.description,
    required this.price,
    required this.stockStatus,
    required this.imageUrls,
    required this.isVisible,
    required this.updatedAt,
  });

  factory ProductModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProductModel(
      id: doc.id,
      storeId: data['storeId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      stockStatus: _parseStock(data['stockStatus'] as String? ?? 'available'),
      imageUrls:
          (data['imageUrls'] as List<dynamic>?)?.cast<String>() ?? [],
      isVisible: data['isVisible'] as bool? ?? true,
      updatedAt:
          (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'storeId': storeId,
        'name': name,
        'description': description,
        'price': price,
        'stockStatus': _stockToString(stockStatus),
        'imageUrls': imageUrls,
        'isVisible': isVisible,
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  static StockStatus _parseStock(String value) {
    switch (value) {
      case 'low': return StockStatus.low;
      case 'out': return StockStatus.out;
      default: return StockStatus.available;
    }
  }

  static String _stockToString(StockStatus status) {
    switch (status) {
      case StockStatus.available: return 'available';
      case StockStatus.low: return 'low';
      case StockStatus.out: return 'out';
    }
  }

  ProductModel copyWith({
    String? name,
    String? description,
    double? price,
    StockStatus? stockStatus,
    List<String>? imageUrls,
    bool? isVisible,
  }) =>
      ProductModel(
        id: id,
        storeId: storeId,
        name: name ?? this.name,
        description: description ?? this.description,
        price: price ?? this.price,
        stockStatus: stockStatus ?? this.stockStatus,
        imageUrls: imageUrls ?? this.imageUrls,
        isVisible: isVisible ?? this.isVisible,
        updatedAt: DateTime.now(),
      );
}
