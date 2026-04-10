import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final firebaseRemoteConfigProvider = Provider<FirebaseRemoteConfig>((ref) {
  return FirebaseRemoteConfig.instance;
});

final ownerScheduleEditorEnabledProvider = FutureProvider<bool>((ref) async {
  final remoteConfig = ref.watch(firebaseRemoteConfigProvider);
  try {
    await remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 8),
        minimumFetchInterval: const Duration(minutes: 30),
      ),
    );
    await remoteConfig.setDefaults(const {
      'owner_schedule_editor_enabled': true,
      'owner_products_enabled': true,
    });
    await remoteConfig.fetchAndActivate();
    return remoteConfig.getBool('owner_schedule_editor_enabled');
  } catch (_) {
    return true;
  }
});

final ownerProductsEnabledProvider = FutureProvider<bool>((ref) async {
  final remoteConfig = ref.watch(firebaseRemoteConfigProvider);
  try {
    await remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 8),
        minimumFetchInterval: const Duration(minutes: 30),
      ),
    );
    await remoteConfig.setDefaults(const {
      'owner_products_enabled': true,
    });
    await remoteConfig.fetchAndActivate();
    return remoteConfig.getBool('owner_products_enabled');
  } catch (_) {
    return true;
  }
});

final ownerPharmacyDutiesEnabledProvider = FutureProvider<bool>((ref) async {
  final remoteConfig = ref.watch(firebaseRemoteConfigProvider);
  try {
    await remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 8),
        minimumFetchInterval: const Duration(minutes: 30),
      ),
    );
    await remoteConfig.setDefaults(const {
      'owner_pharmacy_duties_enabled': true,
      'owner_pharmacy_duties_edit_past_enabled': false,
      'owner_pharmacy_duties_multi_shift_enabled': true,
      'owner_pharmacy_duty_mitigation_enabled': true,
    });
    await remoteConfig.fetchAndActivate();
    return remoteConfig.getBool('owner_pharmacy_duties_enabled');
  } catch (_) {
    return true;
  }
});

final ownerPharmacyDutyMitigationEnabledProvider =
    FutureProvider<bool>((ref) async {
  final remoteConfig = ref.watch(firebaseRemoteConfigProvider);
  try {
    await remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 8),
        minimumFetchInterval: const Duration(minutes: 30),
      ),
    );
    await remoteConfig.setDefaults(const {
      'owner_pharmacy_duty_mitigation_enabled': true,
      'owner_pharmacy_duties_enabled': true,
    });
    await remoteConfig.fetchAndActivate();
    return remoteConfig.getBool('owner_pharmacy_duty_mitigation_enabled');
  } catch (_) {
    return true;
  }
});

final catalogCapacityPolicyEnabledProvider = FutureProvider<bool>((ref) async {
  final remoteConfig = ref.watch(firebaseRemoteConfigProvider);
  try {
    await remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 8),
        minimumFetchInterval: const Duration(minutes: 30),
      ),
    );
    await remoteConfig.setDefaults(const {
      'catalog_capacity_policy_enabled': true,
      'catalog_capacity_hard_block_enabled': true,
      'catalog_product_create_via_cf_enabled': true,
    });
    await remoteConfig.fetchAndActivate();
    return remoteConfig.getBool('catalog_capacity_policy_enabled');
  } catch (_) {
    return true;
  }
});

final catalogCapacityHardBlockEnabledProvider =
    FutureProvider<bool>((ref) async {
  final remoteConfig = ref.watch(firebaseRemoteConfigProvider);
  try {
    await remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 8),
        minimumFetchInterval: const Duration(minutes: 30),
      ),
    );
    await remoteConfig.setDefaults(const {
      'catalog_capacity_hard_block_enabled': true,
      'catalog_capacity_policy_enabled': true,
      'catalog_product_create_via_cf_enabled': true,
    });
    await remoteConfig.fetchAndActivate();
    return remoteConfig.getBool('catalog_capacity_hard_block_enabled');
  } catch (_) {
    return true;
  }
});

final catalogProductCreateViaCfEnabledProvider =
    FutureProvider<bool>((ref) async {
  final remoteConfig = ref.watch(firebaseRemoteConfigProvider);
  try {
    await remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 8),
        minimumFetchInterval: const Duration(minutes: 30),
      ),
    );
    await remoteConfig.setDefaults(const {
      'catalog_product_create_via_cf_enabled': true,
      'catalog_capacity_policy_enabled': true,
      'catalog_capacity_hard_block_enabled': true,
    });
    await remoteConfig.fetchAndActivate();
    return remoteConfig.getBool('catalog_product_create_via_cf_enabled');
  } catch (_) {
    return true;
  }
});
