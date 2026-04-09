import 'package:flutter_test/flutter_test.dart';
import 'package:tum2/modules/owner/models/merchant_product.dart';

void main() {
  group('normalizeProductName', () {
    test('convierte a lowercase, quita diacríticos y colapsa espacios', () {
      final normalized = normalizeProductName('  Ñoquis  Árabes   500gr  ');
      expect(normalized, 'noquis arabes 500gr');
    });

    test('remueve símbolos no alfanuméricos', () {
      final normalized = normalizeProductName('Promo! 2x1 @ Kiosco');
      expect(normalized, 'promo 2x1 kiosco');
    });
  });

  group('buildProductSearchKeywords', () {
    test('genera prefijos por palabra más el nombre completo', () {
      final keywords = buildProductSearchKeywords('Yerba Mate');
      expect(
          keywords, containsAll(['ye', 'yer', 'yerba', 'ma', 'mat', 'mate']));
      expect(keywords, contains('yerba mate'));
    });
  });

  group('validaciones de formulario', () {
    test('name requerido y rango de longitud', () {
      expect(validateProductName(''), isNotNull);
      expect(validateProductName('A'), isNotNull);
      expect(validateProductName('Ibuprofeno'), isNull);
      expect(validateProductName('X' * 81), isNotNull);
    });

    test('priceLabel requerido y límite', () {
      expect(validateProductPriceLabel(''), isNotNull);
      expect(validateProductPriceLabel('Consultar'), isNull);
      expect(validateProductPriceLabel('X' * 61), isNotNull);
    });
  });

  group('MerchantProduct mapper', () {
    test('fromMap parsea enums y opcionales', () {
      final product = MerchantProduct.fromMap(
        'prod-1',
        {
          'merchantId': 'm-1',
          'ownerUserId': 'owner-1',
          'name': 'Leche Entera',
          'normalizedName': 'leche entera',
          'priceLabel': '\$2.500',
          'stockStatus': 'out_of_stock',
          'visibilityStatus': 'hidden',
          'status': 'inactive',
          'sourceType': 'owner_created',
          'createdBy': 'owner-1',
          'updatedBy': 'owner-1',
          'imageUrl': 'https://example.com/image.jpg',
          'imagePath': 'merchant-products/m-1/prod-1/cover.jpg',
          'imageUploadStatus': 'ready',
        },
      );

      expect(product.id, 'prod-1');
      expect(product.stockStatus, ProductStockStatus.outOfStock);
      expect(product.visibilityStatus, ProductVisibilityStatus.hidden);
      expect(product.status, ProductStatus.inactive);
      expect(product.imageUploadStatus, ProductImageUploadStatus.ready);
      expect(product.hasImage, isTrue);
    });
  });
}
