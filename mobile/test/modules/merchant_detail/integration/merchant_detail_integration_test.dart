import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tum2/core/router/app_routes.dart';
import 'package:tum2/modules/merchant_detail/analytics/merchant_detail_analytics.dart';
import 'package:tum2/modules/merchant_detail/application/merchant_location_reader.dart';
import 'package:tum2/modules/merchant_detail/data/merchant_detail_repository.dart';
import 'package:tum2/modules/merchant_detail/domain/merchant_maps.dart';
import 'package:tum2/modules/merchant_detail/presentation/merchant_detail_copy.dart';
import 'package:tum2/modules/merchant_detail/presentation/merchant_detail_page.dart';
import 'package:tum2/modules/merchant_detail/presentation/product_detail_page.dart';

import '../test_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpFlow(
    WidgetTester tester, {
    required FakeMerchantDetailRepository repository,
    RecordingMerchantDetailAnalytics? analytics,
    RecordingMapsLauncher? mapsLauncher,
  }) async {
    final router = GoRouter(
      initialLocation: '/commerce/merchant-1',
      routes: [
        GoRoute(
          path: AppRoutes.commerceDetail,
          builder: (context, state) {
            final merchantId = state.pathParameters['merchantId']!;
            return MerchantDetailPage(merchantId: merchantId);
          },
        ),
        GoRoute(
          path: AppRoutes.commerceProductDetail,
          builder: (context, state) {
            final merchantId = state.pathParameters['merchantId']!;
            final productId = state.pathParameters['productId']!;
            return ProductDetailPage(
              merchantId: merchantId,
              productId: productId,
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          merchantDetailRepositoryProvider.overrideWithValue(repository),
          merchantDetailAnalyticsProvider.overrideWithValue(
            analytics ?? RecordingMerchantDetailAnalytics(),
          ),
          merchantMapsLauncherProvider.overrideWithValue(
            mapsLauncher ?? RecordingMapsLauncher(),
          ),
          merchantLocationReaderProvider.overrideWithValue(
            FakeLocationReader(null),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
  }

  group('Merchant detail integration-style', () {
    testWidgets('carga completa exitosa', (tester) async {
      final repository = FakeMerchantDetailRepository();
      repository.fetchCoreHandler = (_) async => buildCoreDto();
      repository.fetchProductsHandler = (_, __) async => [buildProductDto()];
      repository.fetchScheduleHandler = (_) async => buildScheduleDto();
      repository.fetchSignalsHandler = (_) async => buildSignalsDto();

      await pumpFlow(tester, repository: repository);
      await tester.pumpAndSettle();

      expect(find.text('Farmacia Central'), findsOneWidget);
      expect(find.text('Ibuprofeno 400'), findsOneWidget);
      final scheduleTile =
          find.byKey(const Key('merchant_schedule_expansion_tile'));
      await tester.scrollUntilVisible(
        scheduleTile,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(scheduleTile, findsOneWidget);
    });

    testWidgets('falla de productos sin romper hero', (tester) async {
      final repository = FakeMerchantDetailRepository();
      repository.fetchCoreHandler = (_) async => buildCoreDto();
      repository.fetchProductsHandler = (_, __) async {
        throw Exception('products error');
      };
      repository.fetchScheduleHandler = (_) async => buildScheduleDto();
      repository.fetchSignalsHandler = (_) async => buildSignalsDto();

      await pumpFlow(tester, repository: repository);
      await tester.pumpAndSettle();

      expect(find.text('Farmacia Central'), findsOneWidget);
      expect(
        find.text('No pudimos cargar productos destacados por ahora.'),
        findsOneWidget,
      );
    });

    testWidgets('comercio no encontrado', (tester) async {
      final repository = FakeMerchantDetailRepository();
      repository.fetchCoreHandler = (_) async => null;

      await pumpFlow(tester, repository: repository);
      await tester.pumpAndSettle();

      expect(find.text(MerchantDetailCopy.notFound), findsOneWidget);
    });

    testWidgets('tap en producto', (tester) async {
      final repository = FakeMerchantDetailRepository();
      repository.fetchCoreHandler = (_) async => buildCoreDto();
      repository.fetchProductsHandler =
          (_, __) async => [buildProductDto(id: 'product-77')];
      repository.fetchScheduleHandler = (_) async => buildScheduleDto();
      repository.fetchSignalsHandler = (_) async => null;

      await pumpFlow(tester, repository: repository);
      await tester.pumpAndSettle();

      final productCard =
          find.byKey(const Key('merchant_product_card_product-77'));
      await tester.scrollUntilVisible(
        productCard,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(productCard);
      await tester.pumpAndSettle();

      expect(find.text('productId: product-77'), findsOneWidget);
      expect(find.text('merchantId: merchant-1'), findsOneWidget);
    });

    testWidgets('tap en Como llegar', (tester) async {
      final repository = FakeMerchantDetailRepository();
      final mapsLauncher = RecordingMapsLauncher();
      repository.fetchCoreHandler = (_) async => buildCoreDto();
      repository.fetchProductsHandler = (_, __) async => [];
      repository.fetchScheduleHandler = (_) async => null;
      repository.fetchSignalsHandler = (_) async => null;

      await pumpFlow(
        tester,
        repository: repository,
        mapsLauncher: mapsLauncher,
      );
      await tester.pumpAndSettle();

      final directionsButton =
          find.byKey(const Key('merchant_how_to_arrive_button'));
      await tester.scrollUntilVisible(
        directionsButton,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(directionsButton);
      await tester.pumpAndSettle();

      expect(mapsLauncher.callCount, 1);
    });
  });
}
