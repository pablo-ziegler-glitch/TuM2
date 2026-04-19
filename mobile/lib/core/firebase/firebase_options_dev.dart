// File generated manually for dev web fallback.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Dev Firebase options.
///
/// Web uses project `tum2-dev-6283d`.
/// Mobile platforms in dev environment are intentionally not configured here
/// and should keep using staging options to avoid breaking current mobile flows.
class DefaultFirebaseOptions {
  static const String _webApiKey = String.fromEnvironment(
    'FIREBASE_WEB_API_KEY',
    defaultValue: '',
  );

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      if (_webApiKey.isEmpty) {
        throw StateError(
          'Missing FIREBASE_WEB_API_KEY for dev web build.',
        );
      }
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'Dev mobile Firebase options are not configured in firebase_options_dev.dart. '
          'Use staging options for mobile dev builds.',
        );
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static final FirebaseOptions web = FirebaseOptions(
    apiKey: _webApiKey,
    appId: '1:967380985108:web:084981eea879c427900e01',
    messagingSenderId: '967380985108',
    projectId: 'tum2-dev-6283d',
    authDomain: 'tum2-dev-6283d.firebaseapp.com',
    storageBucket: 'tum2-dev-6283d.firebasestorage.app',
  );
}
