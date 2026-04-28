# Revisión TuM2-0029 — Onboarding CUSTOMER (2026-04-27)

## Resultado

- Tarjeta revisada: `TuM2-0029`
- Estado resultante: `BUGFIX_REQUIRED`

## Contexto

Durante el cierre de `TuM2-0002` (claim principal) se revisaron superficies de entrada de AUTH:

- `AUTH-01` Splash
- `AUTH-02` Onboarding
- `AUTH-03` Login/Registro

## Hallazgo principal

- `AUTH-01` (`mobile/lib/modules/auth/screens/splash_screen.dart`) no usa imagen/asset visual de marca dedicada.
- Implementación actual: wordmark textual + claim + spinner.
- Para cierre completo de 0029 según expectativa actual de producto/branding, falta resolver la pieza visual de splash.

## Impacto

- No impacta backend, Firestore, Functions ni costos.
- Impacta consistencia visual de primer contacto de marca.

## Acciones requeridas

1. Definir/generar asset visual de splash (branding).
2. Integrar asset en `SplashScreen` sin bloquear carga inicial.
3. Validar:
   - pantallas chicas/grandes
   - contraste y legibilidad
   - escalado de fuente/accesibilidad
4. Revalidar estado de `TuM2-0029` para volver a `DONE`.

## Restricciones técnicas

- Cero cambios en backend/Firestore/Cloud Functions.
- Cero listeners o lecturas nuevas.
- Sin dependencias nuevas obligatorias.
