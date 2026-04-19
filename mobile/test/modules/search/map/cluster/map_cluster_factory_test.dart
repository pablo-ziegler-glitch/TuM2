import 'package:flutter_test/flutter_test.dart';
import 'package:tum2/modules/search/map/cluster/map_cluster_factory.dart';
import 'package:tum2/modules/search/map/cluster/map_cluster_model.dart';

void main() {
  test('MapClusterFactory cachea por prioridad/count/pixelRatio', () async {
    final factory = MapClusterFactory();

    final a = factory.resolveIcon(
      priority: MapClusterPriority.green,
      count: 12,
      pixelRatio: 2.0,
    );
    final b = factory.resolveIcon(
      priority: MapClusterPriority.green,
      count: 12,
      pixelRatio: 2.0,
    );

    expect(identical(a, b), isTrue);
    await Future.wait([a, b]);
  });
}
