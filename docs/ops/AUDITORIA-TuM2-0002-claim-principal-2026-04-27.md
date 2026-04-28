# Auditoría TuM2-0002 — Claim principal (2026-04-27)

## Objetivo

Validar consistencia de claim de marca en superficies de entrada y confirmar impacto cero en infraestructura.

## Alcance auditado

- Mobile app (`mobile/lib`) en pantallas de entrada:
  - splash
  - auth/login (`AUTH-03`)
  - onboarding inicial
- Assets web de mobile (`mobile/web/index.html`) en metadata pública.
- Documentación de producto/branding (`docs/`, `README.md`, `CLAUDE.md`).

## Hallazgos previos al cambio

- El claim primario ya existía en documentación (`README.md`, `docs/VISION.md`) y en metadata web (`mobile/web/index.html`).
- No existía una fuente central de copys de marca en código mobile.
- `AUTH-03` mostraba copy funcional (`Usá tu email o Google para continuar`) pero sin claim primario.
- `Splash` no mostraba claim primario.
- Onboarding inicial no usaba el claim canónico.

## Cambios aplicados

- Se centralizó la jerarquía de claims en:
  - `mobile/lib/core/copy/brand_copy.dart`
- Se aplicó claim primario en:
  - `mobile/lib/modules/auth/screens/splash_screen.dart`
  - `mobile/lib/modules/auth/screens/login_screen.dart`
  - `mobile/lib/modules/auth/screens/onboarding_screen.dart` (slide 1)
- Se agregó test de contrato:
  - `mobile/test/core/copy/brand_copy_test.dart`
- Se publicó documentación de negocio/uso:
  - `docs/branding/TuM2-0002-claim-principal.md`

## Superficies sin cambio (auditadas)

- `web/` corresponde al panel Admin; no es la landing pública de vecinos.
- No se encontró una landing pública Flutter/Web activa en este repo distinta de metadata estática.
- `mobile/web/index.html` ya tenía meta description canónica y se mantuvo sin cambios funcionales.

## Validación de costo e infraestructura

- Nuevas lecturas Firestore: `0`
- Nuevas escrituras Firestore: `0`
- Nuevos listeners: `0`
- Cambios Cloud Functions: `0`
- Cambios Firestore Rules/Indexes: `0`
- Cambios de esquema/colecciones: `0`

Cumple restricción de costo Firestore y arquitectura del repositorio.
