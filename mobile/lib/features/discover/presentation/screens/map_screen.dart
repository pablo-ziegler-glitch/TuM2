import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/discover_providers.dart';

class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storesAsync = ref.watch(discoverStoresProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mapa')),
      body: Stack(
        children: [
          // Map placeholder — replace with GoogleMap widget after API key setup
          Container(
            color: TuM2Colors.surfaceVariant,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.map_outlined,
                      size: 72, color: TuM2Colors.onSurfaceVariant),
                  SizedBox(height: 16),
                  Text(
                    'Mapa de comercios',
                    style: TuM2TextStyles.titleLarge,
                  ),
                  SizedBox(height: 8),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 48),
                    child: Text(
                      'Configurá la API key de Google Maps en AndroidManifest.xml e Info.plist para activar el mapa.',
                      textAlign: TextAlign.center,
                      style: TuM2TextStyles.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Store count chip
          Positioned(
            top: 16,
            left: 16,
            child: storesAsync.when(
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
              data: (stores) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: TuM2Colors.background,
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Text(
                  '${stores.length} comercios',
                  style: TuM2TextStyles.labelLarge,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
