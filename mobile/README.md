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

## Configuración segura de Firebase (API Keys)

Las API keys de Firebase no deben quedar hardcodeadas en el repositorio.
Este proyecto las toma por `--dart-define` en tiempo de build.

Ejemplo para correr local:

```bash
flutter run \
  --dart-define=FIREBASE_WEB_API_KEY=tu_web_key \
  --dart-define=FIREBASE_ANDROID_API_KEY=tu_android_key \
  --dart-define=FIREBASE_IOS_API_KEY=tu_ios_key
```

Para CI/CD, cargá esos valores como secretos del pipeline y pasalos también por `--dart-define`.
