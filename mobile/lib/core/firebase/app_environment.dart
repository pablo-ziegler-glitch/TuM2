enum AppEnvironment {
  dev,
  staging,
  prod,
}

final class AppEnvironmentConfig {
  AppEnvironmentConfig._();

  static const String _rawEnv = String.fromEnvironment(
    'ENV',
    defaultValue: 'staging',
  );

  static AppEnvironment get current {
    switch (_rawEnv.toLowerCase()) {
      case 'dev':
      case 'development':
        return AppEnvironment.dev;
      case 'staging':
        return AppEnvironment.staging;
      case 'prod':
      case 'production':
        return AppEnvironment.prod;
      default:
        throw StateError(
          "Invalid ENV='$_rawEnv'. Supported values: dev | staging | prod.",
        );
    }
  }

  static String get androidApplicationId => switch (current) {
        AppEnvironment.dev => 'com.floki.tum2.staging',
        AppEnvironment.staging => 'com.floki.tum2.staging',
        AppEnvironment.prod => 'com.floki.tum2',
      };

  static String get iosBundleId => switch (current) {
        AppEnvironment.dev => 'com.floki.tum2.staging',
        AppEnvironment.staging => 'com.floki.tum2.staging',
        AppEnvironment.prod => 'com.floki.tum2',
      };

  static String get firebaseProjectId => switch (current) {
        AppEnvironment.dev => 'tum2-dev-6283d',
        AppEnvironment.staging => 'tum2-staging-45c83',
        AppEnvironment.prod => 'tum2-prod-bc9b4',
      };
}
