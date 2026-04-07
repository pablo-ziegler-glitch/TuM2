import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tum2/core/router/app_routes.dart';
import 'package:tum2/modules/merchant_detail/analytics/merchant_detail_analytics.dart';
import 'package:tum2/modules/merchant_detail/application/merchant_detail_actions.dart';
import 'package:tum2/modules/merchant_detail/application/merchant_location_reader.dart';
import 'package:tum2/modules/merchant_detail/data/merchant_detail_repository.dart';
import 'package:tum2/modules/merchant_detail/presentation/merchant_detail_page.dart';

import '../test_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpFlow(
    WidgetTester tester, {
    required FakeMerchantDetailRepository repository,
    FakeMerchantDetailActions? actions,
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
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          merchantDetailRepositoryProvider.overrideWithValue(repository),
          merchantDetailAnalyticsProvider.overrideWithValue(
            RecordingMerchantDetailAnalytics(),
          ),
          merchantDetailActionsProvider.overrideWithValue(
            actions ?? FakeMerchantDetailActions(),
          ),
          merchantLocationReaderProvider.overrideWithValue(
            FakeLocationReader(null),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
  }

  group('Merchant detail integration', () {
    testWidgets('renderiza la ficha desde /commerce/:merchantId',
        (tester) async {
      final repository = FakeMerchantDetailRepository();
      repository.fetchCoreHandler = (_) async => buildCoreDto();
      repository.fetchProductsHandler =
          (_, __, ___) async => [buildProductDto()];
      repository.fetchScheduleHandler = (_) async => buildScheduleDto();
      repository.fetchSignalsHandler = (_) async => buildSignalsDto();

      await pumpFlow(tester, repository: repository);
      await tester.pumpAndSettle();

      expect(find.text('Farmacia Central'), findsOneWidget);
      expect(find.text('Ibuprofeno 400'), findsOneWidget);
    });

    testWidgets('tap en CTA de como llegar llama accion', (tester) async {
      final repository = FakeMerchantDetailRepository();
      final actions = FakeMerchantDetailActions();
      repository.fetchCoreHandler = (_) async => buildCoreDto();
      repository.fetchProductsHandler = (_, __, ___) async => [];
      repository.fetchScheduleHandler = (_) async => null;
      repository.fetchSignalsHandler = (_) async => null;

      await pumpFlow(
        tester,
        repository: repository,
        actions: actions,
      );
      await tester.pumpAndSettle();

      final directionsCta = find.byKey(const Key('merchant_cta_directions'));
      await tester.scrollUntilVisible(
        directionsCta,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(directionsCta);
      await tester.pumpAndSettle();

      expect(actions.directionsCount, 1);
    });
  });
}
