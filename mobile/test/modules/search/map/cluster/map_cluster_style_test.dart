import 'package:flutter_test/flutter_test.dart';
import 'package:tum2/modules/search/map/cluster/map_cluster_style.dart';

void main() {
  test('size por count', () {
    expect(MapClusterStyle.resolveSizeDp(2), 40);
    expect(MapClusterStyle.resolveSizeDp(9), 40);
    expect(MapClusterStyle.resolveSizeDp(10), 48);
    expect(MapClusterStyle.resolveSizeDp(49), 48);
    expect(MapClusterStyle.resolveSizeDp(50), 56);
    expect(MapClusterStyle.resolveSizeDp(120), 56);
  });
}
