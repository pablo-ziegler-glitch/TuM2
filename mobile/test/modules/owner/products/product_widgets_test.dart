import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tum2/modules/owner/models/merchant_product.dart';
import 'package:tum2/modules/owner/models/owner_merchant_summary.dart';
import 'package:tum2/modules/owner/providers/owner_providers.dart';
import 'package:tum2/modules/owner/providers/product_providers.dart';
import 'package:tum2/modules/owner/repositories/product_repository.dart';
import 'package:tum2/modules/owner/screens/product_form_screen.dart';
import 'package:tum2/modules/owner/widgets/product_card.dart';
import 'package:tum2/modules/owner/widgets/product_empty_state.dart';

void main() {
  group('Owner products widgets', () {
    testWidgets('empty state muestra microcopy y CTA', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProductEmptyState(
              onAddPressed: () {},
            ),
          ),
        ),
      );

      expect(
        find.text('Tu catálogo está vacío. ¡Sumá tu primer producto!'),
        findsOneWidget,
      );
      expect(find.text('Agregar producto'), findsOneWidget);
    });

    testWidgets('product card renderiza fila estilo catálogo', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProductCard(
              product: const MerchantProduct(
                id: 'p-1',
                merchantId: 'm-1',
                ownerUserId: 'owner-1',
                name: 'Yerba Mate Tradicional 1kg',
                normalizedName: 'yerba mate tradicional 1kg',
                priceLabel: '\$4.000',
                stockStatus: ProductStockStatus.outOfStock,
                visibilityStatus: ProductVisibilityStatus.hidden,
                status: ProductStatus.inactive,
                sourceType: 'owner_created',
                createdBy: 'owner-1',
                updatedBy: 'owner-1',
              ),
              onTapActions: () {},
              onVisibilityChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Yerba Mate Tradicional 1kg'), findsOneWidget);
      expect(find.text('OCULTO'), findsOneWidget);
      expect(find.text('SIN STOCK'), findsOneWidget);
      expect(find.text('INACTIVO'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('formulario muestra errores inline al enviar inválido',
        (tester) async {
      final merchant = OwnerMerchantSummary(
        id: 'm-1',
        name: 'Almacén Centro',
        categoryId: 'grocery',
        zoneId: 'zone-1',
        address: 'Av. Siempre Viva 123',
        status: 'active',
        visibilityStatus: 'visible',
        verificationStatus: 'claimed',
        sourceType: 'owner_created',
        hasProducts: false,
        hasSchedules: true,
        hasOperationalSignals: true,
        updatedAt: DateTime(2026, 4, 8),
        createdAt: DateTime(2026, 4, 1),
        isDataComplete: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ownerMerchantProvider.overrideWith((ref) async {
              return OwnerMerchantResolution(
                primaryMerchant: merchant,
                allMerchants: [merchant],
              );
            }),
            productRepositoryProvider
                .overrideWithValue(_WidgetFakeRepository()),
          ],
          child: const MaterialApp(
            home: ProductFormScreen(debugOwnerUserId: 'owner-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'A');
      await tester.enterText(find.byType(TextField).at(1), '');
      await tester.tap(find.text('Guardar producto'));
      await tester.pumpAndSettle();

      expect(
        find.text('El nombre debe tener al menos 2 caracteres.'),
        findsOneWidget,
      );
      expect(find.text('Ingresá el precio visible.'), findsOneWidget);
    });
  });
}

class _WidgetFakeRepository implements ProductRepository {
  @override
  Future<String> createProduct({
    required String merchantId,
    required String ownerUserId,
    required String actorUserId,
    required ProductDraftInput input,
    ProductImageUploadData? image,
  }) async {
    return 'new-product';
  }

  @override
  Future<void> deactivateProduct({
    required MerchantProduct product,
    required String actorUserId,
  }) async {}

  @override
  Future<List<MerchantProduct>> fetchPublicProducts({
    required String merchantId,
    int limit = 24,
  }) async {
    return const [];
  }

  @override
  Future<MerchantProduct?> getProductById(String productId) async {
    return null;
  }

  @override
  Future<void> setVisibilityStatus({
    required MerchantProduct product,
    required ProductVisibilityStatus visibilityStatus,
    required String actorUserId,
  }) async {}

  @override
  Future<void> updateProduct({
    required MerchantProduct product,
    required String actorUserId,
    required ProductDraftInput input,
    ProductImageUploadData? newImage,
  }) async {}

  @override
  Future<ProductImageUploadResult> uploadProductImage({
    required String merchantId,
    required String productId,
    required ProductImageUploadData image,
    String? existingImagePath,
  }) async {
    return ProductImageUploadResult(
      downloadUrl: 'https://example.com',
      storagePath: 'merchant-products/$merchantId/$productId/cover.jpg',
      sizeBytes: image.sizeBytes,
    );
  }

  @override
  Stream<MerchantProduct?> watchProductById(String productId) {
    return const Stream.empty();
  }

  @override
  Stream<List<MerchantProduct>> watchOwnerProducts({
    required String merchantId,
  }) {
    return const Stream.empty();
  }
}
