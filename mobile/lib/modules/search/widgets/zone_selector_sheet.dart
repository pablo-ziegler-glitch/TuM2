import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/search_zone_item.dart';
import '../providers/search_notifier.dart';
import '../repositories/zone_search_repository.dart';

final _zonesProvider = FutureProvider.autoDispose<List<SearchZoneItem>>(
  (ref) => ZoneSearchRepository().fetchAvailableZones(),
);

class ZoneSelectorSheet extends ConsumerStatefulWidget {
  const ZoneSelectorSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const ZoneSelectorSheet(),
    );
  }

  @override
  ConsumerState<ZoneSelectorSheet> createState() => _ZoneSelectorSheetState();
}

class _ZoneSelectorSheetState extends ConsumerState<ZoneSelectorSheet> {
  String? _selectedZoneId;

  @override
  Widget build(BuildContext context) {
    final currentZone = ref.watch(searchNotifierProvider).activeZoneId;
    _selectedZoneId ??= currentZone;

    final zonesAsync = ref.watch(_zonesProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Seleccionar zona', style: AppTextStyles.headingSm),
            const SizedBox(height: 12),
            zonesAsync.when(
              data: (zones) => Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: zones.length,
                  itemBuilder: (_, i) {
                    final zone = zones[i];
                    final selected = zone.zoneId == _selectedZoneId;
                    return ListTile(
                      leading: Icon(
                        selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: selected
                            ? AppColors.primary500
                            : AppColors.neutral500,
                      ),
                      title: Text(zone.name),
                      subtitle: Text(zone.cityId),
                      onTap: () =>
                          setState(() => _selectedZoneId = zone.zoneId),
                    );
                  },
                ),
              ),
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No se pudieron cargar zonas.'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary500,
                  foregroundColor: AppColors.surface,
                ),
                onPressed: _selectedZoneId == null
                    ? null
                    : () async {
                        await ref
                            .read(searchNotifierProvider.notifier)
                            .setZone(_selectedZoneId!);
                        if (mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                child: const Text('Confirmar zona'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
