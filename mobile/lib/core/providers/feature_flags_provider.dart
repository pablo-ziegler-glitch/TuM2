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
    });
    await remoteConfig.fetchAndActivate();
    return remoteConfig.getBool('owner_schedule_editor_enabled');
  } catch (_) {
    return true;
  }
});
