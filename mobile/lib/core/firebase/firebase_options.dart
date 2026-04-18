import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

import 'app_environment.dart';
import 'firebase_options_dev.dart' as dev_options;
import 'firebase_options_prod.dart' as prod_options;
import 'firebase_options_staging.dart' as staging_options;

/// Firebase options selector based on `--dart-define=ENV=dev|staging|prod`.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform =>
      switch (AppEnvironmentConfig.current) {
        AppEnvironment.dev => kIsWeb
            ? dev_options.DefaultFirebaseOptions.currentPlatform
            : staging_options.DefaultFirebaseOptions.currentPlatform,
        AppEnvironment.staging =>
          staging_options.DefaultFirebaseOptions.currentPlatform,
        AppEnvironment.prod =>
          prod_options.DefaultFirebaseOptions.currentPlatform,
      };
}
