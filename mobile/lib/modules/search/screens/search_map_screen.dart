import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../map/presentation/search_google_map_view.dart';
import '../providers/search_notifier.dart';

class SearchMapScreen extends ConsumerStatefulWidget {
  const SearchMapScreen({super.key});

  @override
  ConsumerState<SearchMapScreen> createState() => _SearchMapScreenState();
}

class _SearchMapScreenState extends ConsumerState<SearchMapScreen> {
  String? _selectedMerchantId;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final notifier = ref.read(searchNotifierProvider.notifier);
      await notifier.ensureInitialized();
      notifier.logMapViewed();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchNotifierProvider);
    final notifier = ref.read(searchNotifierProvider.notifier);
    final selectedMerchantId = _selectedMerchantId ?? state.selectedMerchantId;

    String zoneName = 'Tu zona';
    for (final zone in state.zones) {
      if (zone.zoneId == state.activeZoneId) {
        zoneName = zone.name;
        break;
      }
    }

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    color: AppColors.primary500,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TuM2',
                        style: AppTextStyles.headingSm.copyWith(
                          color: AppColors.primary500,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        zoneName,
                        style: AppTextStyles.bodyXs.copyWith(
                          color: AppColors.neutral700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(
                      Icons.notifications,
                      color: AppColors.neutral700,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SearchGoogleMapView(
                      merchants: state.results.isNotEmpty
                          ? state.results
                          : state.corpus,
                      selectedMerchantId: selectedMerchantId,
                      onMerchantSelected: (merchantId) {
                        if (merchantId.isNotEmpty) {
                          notifier.logResultOpened(
                            merchantId: merchantId,
                            fromMap: true,
                          );
                        }
                        setState(() {
                          _selectedMerchantId =
                              merchantId.isEmpty ? null : merchantId;
                        });
                      },
                      onMerchantOpen: (merchantId) {
                        notifier.logResultOpened(
                          merchantId: merchantId,
                          fromMap: true,
                        );
                        context.push(
                          AppRoutes.commerceDetailPath(
                            merchantId,
                            source: 'search_map',
                          ),
                        );
                      },
                      onListTap: () {
                        final query = state.query.trim();
                        final route = query.isEmpty
                            ? AppRoutes.searchResults
                            : '${AppRoutes.searchResults}?q=${Uri.encodeComponent(query)}';
                        context.go(route);
                      },
                      onRecenterTap: notifier.logMapRecenterTapped,
                      onSearchThisAreaTap: notifier.logMapSearchThisAreaTapped,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
