import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final firebaseRemoteConfigProvider = Provider<FirebaseRemoteConfig>((ref) {
  return FirebaseRemoteConfig.instance;
});

const Map<String, Object> _kRemoteConfigDefaults = {
  'owner_dashboard_enabled': true,
  'owner_schedule_editor_enabled': true,
  'owner_products_enabled': true,
  'owner_pharmacy_duties_enabled': true,
  'owner_pharmacy_duties_edit_past_enabled': false,
  'owner_pharmacy_duties_multi_shift_enabled': true,
  'owner_pharmacy_duty_mitigation_enabled': true,
  'catalog_capacity_policy_enabled': true,
  'catalog_capacity_hard_block_enabled': true,
  'catalog_product_create_via_cf_enabled': true,
};

final remoteConfigSnapshotProvider =
    FutureProvider<Map<String, bool>>((ref) async {
  final remoteConfig = ref.watch(firebaseRemoteConfigProvider);
  try {
    await remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 8),
        minimumFetchInterval: const Duration(minutes: 30),
      ),
    );
    await remoteConfig.setDefaults(_kRemoteConfigDefaults);
    await remoteConfig.fetchAndActivate();
  } catch (_) {
    // Fallback silencioso: usar defaults locales cuando falle red/SDK.
  }

  final values = <String, bool>{};
  for (final entry in _kRemoteConfigDefaults.entries) {
    try {
      values[entry.key] = remoteConfig.getBool(entry.key);
    } catch (_) {
      final fallback = entry.value is bool ? entry.value as bool : false;
      values[entry.key] = fallback;
    }
  }
  return values;
});

Future<bool> _readFlag(Ref ref, String key, {required bool fallback}) async {
  final snapshot = await ref.watch(remoteConfigSnapshotProvider.future);
  return snapshot[key] ?? fallback;
}

final ownerDashboardEnabledProvider = FutureProvider<bool>((ref) {
  return _readFlag(
    ref,
    'owner_dashboard_enabled',
    fallback: true,
  );
});

final ownerScheduleEditorEnabledProvider = FutureProvider<bool>((ref) {
  return _readFlag(
    ref,
    'owner_schedule_editor_enabled',
    fallback: true,
  );
});

final ownerProductsEnabledProvider = FutureProvider<bool>((ref) {
  return _readFlag(
    ref,
    'owner_products_enabled',
    fallback: true,
  );
});

final ownerPharmacyDutiesEnabledProvider = FutureProvider<bool>((ref) {
  return _readFlag(
    ref,
    'owner_pharmacy_duties_enabled',
    fallback: true,
  );
});

final ownerPharmacyDutyMitigationEnabledProvider = FutureProvider<bool>((ref) {
  return _readFlag(
    ref,
    'owner_pharmacy_duty_mitigation_enabled',
    fallback: true,
  );
});

final catalogCapacityPolicyEnabledProvider = FutureProvider<bool>((ref) {
  return _readFlag(
    ref,
    'catalog_capacity_policy_enabled',
    fallback: true,
  );
});

final catalogCapacityHardBlockEnabledProvider = FutureProvider<bool>((ref) {
  return _readFlag(
    ref,
    'catalog_capacity_hard_block_enabled',
    fallback: true,
  );
});

final catalogProductCreateViaCfEnabledProvider = FutureProvider<bool>((ref) {
  return _readFlag(
    ref,
    'catalog_product_create_via_cf_enabled',
    fallback: true,
  );
});
