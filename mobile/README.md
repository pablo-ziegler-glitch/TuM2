# TuM2 — Mobile App

Stack: **Flutter** (definido en ARCHITECTURE.md, sección 3)

## Inicialización del proyecto

```bash
cd mobile
flutter create . --org com.floki.tum2 --project-name tum2 --platforms android,ios
```

## Estructura esperada

```
mobile/
  lib/
    main.dart
    core/          # navegación, sesión, theming, analytics, remote config
    modules/
      owner/       # gestión comercio, productos, horarios, señales, turnos
      customer/    # buscar, mapa, categorías, perfil, favoritos, abierto ahora, farmacias
      brand/       # onboarding, badges, sellos, copy, notificaciones
  test/
  android/
  ios/
  pubspec.yaml
```

## Dependencias previstas

- `firebase_core`
- `firebase_auth`
- `cloud_firestore`
- `firebase_storage`
- `firebase_messaging`
- `firebase_analytics`
- `firebase_crashlytics`
- `firebase_remote_config`
- `firebase_app_check`
- `google_maps_flutter` (módulo geográfico)
- `geolocator`
- `geoflutterfire_plus` o equivalente (queries por cercanía)

## Flavors y entorno Firebase

Entornos soportados:
- `staging` (`tum2-staging-45c83`)
- `prod` (`tum2-prod-bc9b4`)

Android package IDs:
- staging: `com.floki.tum2.staging`
- prod: `com.floki.tum2`

El runtime Firebase se selecciona con:
- `--dart-define=ENV=staging`
- `--dart-define=ENV=prod`

### Ejecutar app mobile

```bash
# Android staging
flutter run --flavor staging -t lib/main.dart --dart-define=ENV=staging

# Android prod
flutter run --flavor prod -t lib/main.dart --dart-define=ENV=prod
```

### Build web (customer app desde /mobile)

```bash
# Staging
flutter build web --release -t lib/main.dart \
  --dart-define=ENV=staging \
  --dart-define=FIREBASE_WEB_API_KEY=__STAGING_WEB_API_KEY__

# Prod
flutter build web --release -t lib/main.dart \
  --dart-define=ENV=prod \
  --dart-define=FIREBASE_WEB_API_KEY=__PROD_WEB_API_KEY__
```

## FlutterFire CLI (sin mezclar entornos)

```bash
cd mobile

# Staging
~/.pub-cache/bin/flutterfire configure \
  --yes \
  --project=tum2-staging-45c83 \
  --platforms=android,ios,web \
  --android-package-name=com.floki.tum2.staging \
  --ios-bundle-id=com.floki.tum2.staging \
  --web-app-id=1:227534906025:web:41ca1f2d60d73c58b03fb8 \
  --out=lib/core/firebase/firebase_options_staging.dart \
  --android-out=android/app/src/staging/google-services.json \
  --ios-out=/tmp/GoogleService-Info-staging.plist

# Prod
~/.pub-cache/bin/flutterfire configure \
  --yes \
  --project=tum2-prod-bc9b4 \
  --platforms=android,ios,web \
  --android-package-name=com.floki.tum2 \
  --ios-bundle-id=com.floki.tum2 \
  --web-app-id=1:57567901381:web:dadc4aec40273a4e6662ac \
  --out=lib/core/firebase/firebase_options_prod.dart \
  --android-out=android/app/src/prod/google-services.json \
  --ios-out=/tmp/GoogleService-Info-prod.plist
```

## iOS (estado actual y soporte de esquemas)

Actualmente este repo no incluye `mobile/ios`.  
Cuando se regenere iOS (`flutter create . --platforms=ios`), crear esquemas:
- `staging` con bundle id `com.floki.tum2.staging`
- `prod` con bundle id `com.floki.tum2`

Y mapear sus `GoogleService-Info.plist` por esquema/build configuration.
