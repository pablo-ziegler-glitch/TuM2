import 'package:flutter/material.dart';

import '../../search/map/cluster/map_cluster_model.dart';

class MerchantClusterStyleResolver {
  const MerchantClusterStyleResolver._();

  static Color colorForPriority(MapClusterPriority priority) {
    switch (priority) {
      case MapClusterPriority.red:
        return const Color(0xFFE53935);
      case MapClusterPriority.blue:
        return const Color(0xFF0E5BD8);
      case MapClusterPriority.green:
        return const Color(0xFF0F766E);
      case MapClusterPriority.neutral:
        return const Color(0xFF6B7280);
    }
  }
}
