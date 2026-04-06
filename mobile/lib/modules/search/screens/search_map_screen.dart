import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/search_notifier.dart';
import '../widgets/search_results_map.dart';

class SearchMapScreen extends ConsumerWidget {
  const SearchMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(searchNotifierProvider);
    final notifier = ref.read(searchNotifierProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa'),
      ),
      backgroundColor: AppColors.scaffoldBg,
      body: SearchResultsMap(
        items: state.results,
        selectedMerchantId: state.selectedMerchantId,
        onPinTap: notifier.selectMerchant,
        onCardTap: (merchantId) {
          notifier.logResultOpened(merchantId: merchantId, fromMap: true);
          context.push(AppRoutes.commerceDetailPath(merchantId));
        },
      ),
    );
  }
}
