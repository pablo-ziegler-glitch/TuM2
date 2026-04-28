# Revisión TuM2-0029 — Onboarding CUSTOMER (2026-04-27)

## Resultado

- Tarjeta revisada: `TuM2-0029`
- Estado resultante: `READY_FOR_QA`

## Contexto

Durante el cierre de `TuM2-0002` (claim principal) se revisaron superficies de entrada de AUTH:

- `AUTH-01` Splash
- `AUTH-02` Onboarding
- `AUTH-03` Login/Registro

## Hallazgo principal (resuelto)

- `AUTH-01` (`mobile/lib/modules/auth/screens/splash_screen.dart`) requería asset visual de marca dedicada.
- Se integró pack de assets en `mobile/assets/auth01/` y selector por Remote Config (`splash_brand_variant`, `mobile_worldcup_enabled`) con fallback seguro a `original`.
- Se mantiene patrón guest-first sin agregar lecturas Firestore ni listeners.

## Impacto

- No impacta backend, Firestore, Functions ni costos.
- Mejora consistencia visual de primer contacto de marca.

## Validación técnica realizada

1. Integración de assets de splash original/mundialista en AUTH-01.
2. Resolución de variante por Remote Config con fallback `original`.
3. Onboarding AUTH-02 validado con persistencia local `onboarding_seen` y navegación a HOME en modo invitado.
4. Tests automáticos relevantes en verde:
   - `mobile/test/modules/auth/onboarding_screen_test.dart`
   - `mobile/test/modules/auth/splash_screen_test.dart`
   - `mobile/test/core/providers/feature_flags_provider_test.dart`
5. `flutter analyze` sin issues en módulos de auth/providers cubiertos por 0029.

## Pendiente para cierre final (`DONE`)

- QA manual/E2E en staging (`tum2-staging-45c83`) con checklist operativo:
  - variante original/mundialista aplicada por Remote Config,
  - timeout guest-first sin bloqueo,
  - navegación AUTH-01/AUTH-02/AUTH-03 sin regresiones,
  - confirmación de no impacto en costo (0 reads Firestore para onboarding/splash).

## Restricciones técnicas

- Cero cambios en backend/Firestore/Cloud Functions.
- Cero listeners o lecturas nuevas.
- Sin dependencias nuevas obligatorias.
