import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tum2/modules/merchant_detail/analytics/merchant_detail_analytics.dart';
import 'package:tum2/modules/merchant_detail/application/merchant_detail_controller.dart';
import 'package:tum2/modules/merchant_detail/application/merchant_location_reader.dart';
import 'package:tum2/modules/merchant_detail/data/dtos/merchant_detail_dto.dart';
import 'package:tum2/modules/merchant_detail/data/merchant_detail_repository.dart';

import '../test_fakes.dart';

void main() {
  group('MerchantDetailController', () {
    ProviderContainer buildContainer({
      required FakeMerchantDetailRepository repository,
      RecordingMerchantDetailAnalytics? analytics,
      FakeLocationReader? locationReader,
    }) {
      return ProviderContainer(
        overrides: [
          merchantDetailRepositoryProvider.overrideWithValue(repository),
          merchantDetailAnalyticsProvider.overrideWithValue(
            analytics ?? RecordingMerchantDetailAnalytics(),
          ),
          merchantLocationReaderProvider.overrideWithValue(
            locationReader ?? FakeLocationReader(null),
          ),
        ],
      );
    }

    test('resuelve core primero y actualiza secundarios despues', () async {
      final repository = FakeMerchantDetailRepository();
      repository.fetchCoreHandler = (_) async => buildCoreDto();

      final productsCompleter = Completer<List<MerchantProductDto>>();
      final scheduleCompleter = Completer<MerchantScheduleDto?>();
      final signalsCompleter = Completer<MerchantOperationalSignalsDto?>();

      repository.fetchProductsHandler = (_, __) => productsCompleter.future;
      repository.fetchScheduleHandler = (_) => scheduleCompleter.future;
      repository.fetchSignalsHandler = (_) => signalsCompleter.future;

      final container = buildContainer(repository: repository);
      addTearDown(container.dispose);
      final subscription = container.listen(
        merchantDetailControllerProvider('merchant-1'),
        (_, __) {},
      );
      addTearDown(subscription.close);

      final loadedState = await container.read(
        merchantDetailControllerProvider('merchant-1').future,
      );
      expect(loadedState.core.name, 'Farmacia Central');

      final stateAfterCore = subscription.read().valueOrNull!;
      expect(stateAfterCore.products.isLoading, isTrue);
      expect(stateAfterCore.schedule.isLoading, isTrue);

      productsCompleter.complete([buildProductDto()]);
      scheduleCompleter.complete(buildScheduleDto());
      signalsCompleter.complete(buildSignalsDto());

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final finalState = subscription.read().valueOrNull!;
      expect(finalState.products.valueOrNull?.length, 1);
      expect(finalState.schedule.valueOrNull, isNotNull);
      expect(finalState.signals.valueOrNull?.isNotEmpty, isTrue);
    });

    test('si falla productos mantiene ficha principal usable', () async {
      final repository = FakeMerchantDetailRepository();
      repository.fetchCoreHandler = (_) async => buildCoreDto();
      repository.fetchProductsHandler = (_, __) async {
        throw Exception('products failed');
      };
      repository.fetchScheduleHandler = (_) async => buildScheduleDto();
      repository.fetchSignalsHandler = (_) async => buildSignalsDto();

      final container = buildContainer(repository: repository);
      addTearDown(container.dispose);
      final subscription = container.listen(
        merchantDetailControllerProvider('merchant-1'),
        (_, __) {},
      );
      addTearDown(subscription.close);

      await container.read(
        merchantDetailControllerProvider('merchant-1').future,
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final state = subscription.read().valueOrNull!;
      expect(state.core.name, 'Farmacia Central');
      expect(state.products.hasError, isTrue);
      expect(state.schedule.valueOrNull, isNotNull);
    });
  });
}
