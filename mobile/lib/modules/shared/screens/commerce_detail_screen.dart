import 'package:flutter/material.dart';

import '../../merchant_detail/presentation/merchant_detail_page.dart';

/// Wrapper de compatibilidad para mantener la ruta actual /commerce/:id.
class CommerceDetailScreen extends StatelessWidget {
  const CommerceDetailScreen({
    super.key,
    required this.commerceId,
  });

  final String commerceId;

  @override
  Widget build(BuildContext context) {
    return MerchantDetailPage(merchantId: commerceId);
  }
}
