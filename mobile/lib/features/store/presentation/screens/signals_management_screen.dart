import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/signal_model.dart';
import '../providers/store_providers.dart';

class SignalsManagementScreen extends ConsumerWidget {
  final String storeId;

  const SignalsManagementScreen({super.key, required this.storeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signalsAsync = ref.watch(signalsProvider(storeId));

    return Scaffold(
      appBar: AppBar(title: const Text('Señales operativas')),
      body: signalsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (signals) {
          // Build a map from signalType → signal
          final signalMap = {
            for (final s in signals) s.signalType: s,
          };

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Indicá el estado operativo real de tu comercio.',
                style: TuM2TextStyles.bodyMedium
                    .copyWith(color: TuM2Colors.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              ...SignalType.values.map((type) {
                final signal = signalMap[type];
                final isActive = signal?.isActive ?? false;
                final info = OperationalSignalModel.displayInfo[type]!;

                return _SignalTile(
                  title: info['label'] as String,
                  description: info['description'] as String,
                  isActive: isActive,
                  notes: signal?.notes ?? '',
                  onToggle: (active) async {
                    await ref
                        .read(signalRepositoryProvider)
                        .setSignal(
                          storeId: storeId,
                          signalType: type,
                          active: active,
                        );
                  },
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

class _SignalTile extends StatelessWidget {
  final String title;
  final String description;
  final bool isActive;
  final String notes;
  final ValueChanged<bool> onToggle;

  const _SignalTile({
    required this.title,
    required this.description,
    required this.isActive,
    required this.notes,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isActive
            ? TuM2Colors.primary.withOpacity(0.05)
            : TuM2Colors.background,
        border: Border.all(
          color: isActive ? TuM2Colors.primary : TuM2Colors.outline,
          width: isActive ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TuM2TextStyles.titleMedium),
                const SizedBox(height: 2),
                Text(description,
                    style: TuM2TextStyles.bodySmall
                        .copyWith(color: TuM2Colors.onSurfaceVariant)),
              ],
            ),
          ),
          Switch(
            value: isActive,
            onChanged: onToggle,
            activeColor: TuM2Colors.primary,
          ),
        ],
      ),
    );
  }
}
