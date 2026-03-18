import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/pharmacy_providers.dart';

class PharmacyScreen extends ConsumerWidget {
  const PharmacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dutyAsync = ref.watch(todayDutySchedulesProvider);
    final today = DateFormat('d MMMM yyyy', 'es').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(title: const Text('Farmacias')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Farmacias de turno', style: TuM2TextStyles.headlineMedium),
                Text(
                  today,
                  style: TuM2TextStyles.bodyMedium
                      .copyWith(color: TuM2Colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: dutyAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (duties) {
                if (duties.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.local_pharmacy_outlined,
                            size: 64,
                            color: TuM2Colors.onSurfaceVariant),
                        const SizedBox(height: 16),
                        Text(
                          'No hay farmacias de turno registradas para hoy.',
                          style: TuM2TextStyles.bodyMedium.copyWith(
                              color: TuM2Colors.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 8),
                  itemCount: duties.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 12),
                  itemBuilder: (ctx, i) {
                    final duty = duties[i];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: TuM2Colors.infoLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: TuM2Colors.dutyBlue.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: TuM2Colors.dutyBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.local_pharmacy,
                                color: TuM2Colors.dutyBlue),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(duty.storeId,
                                    style: TuM2TextStyles.titleMedium),
                                Text(
                                  '${duty.startTime} – ${duty.endTime}',
                                  style: TuM2TextStyles.bodySmall.copyWith(
                                      color: TuM2Colors.onSurfaceVariant),
                                ),
                                if (duty.notes.isNotEmpty)
                                  Text(duty.notes,
                                      style: TuM2TextStyles.bodySmall),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
