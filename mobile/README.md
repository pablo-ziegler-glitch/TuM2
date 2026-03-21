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
