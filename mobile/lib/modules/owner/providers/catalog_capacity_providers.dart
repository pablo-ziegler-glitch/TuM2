import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/catalog_capacity.dart';
import '../repositories/catalog_limits_repository.dart';

const _kCatalogLimitsConfigTtl = Duration(minutes: 10);

final catalogLimitsRepositoryProvider =
    Provider<CatalogLimitsRepository>((ref) {
  return CatalogLimitsRepository();
});

final catalogLimitsConfigProvider =
    FutureProvider.autoDispose<OwnerCatalogLimitsConfig>((ref) async {
  final link = ref.keepAlive();
  Timer? disposeTimer;
  void scheduleDispose() {
    disposeTimer?.cancel();
    disposeTimer = Timer(_kCatalogLimitsConfigTtl, link.close);
  }

  ref.onCancel(scheduleDispose);
  ref.onResume(() => disposeTimer?.cancel());
  ref.onDispose(() => disposeTimer?.cancel());

  final repository = ref.watch(catalogLimitsRepositoryProvider);
  return repository.fetchCatalogLimitsConfig();
});
