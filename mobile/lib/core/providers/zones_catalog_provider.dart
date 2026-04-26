import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../catalog/zones_catalog_repository.dart';

final zonesCatalogRepositoryProvider = Provider<ZonesCatalogRepository>(
  (ref) => ZonesCatalogRepository(),
);
