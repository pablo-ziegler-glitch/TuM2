# TuM2-0002 — Claim principal de marca

## Estado

- Tarjeta: `TuM2-0002`
- Estado: `DONE`
- Fecha de cierre: `2026-04-27`
- Tipo: Producto / Branding / UX Messaging

## Decisión aprobada

Claim primario oficial:

> **Lo que necesitás, en tu zona.**

## Jerarquía oficial de claims

| Nivel | Claim | Uso |
|---|---|---|
| Primario / Marca | Lo que necesitás, en tu zona. | Splash, onboarding inicial, AUTH-03, landing y stores |
| Secundario / Campañas | Lo útil, a metros. | Campañas de awareness (afiches, redes, banners) |
| Performance / Activación | Abrí TuM2 y resolvés. | CTAs y piezas tácticas de activación |
| Confianza / Validación | Comercios reales, cerca tuyo. | Flujos de confianza, verificación y claim |

## Bajadas aprobadas

- Bajada institucional:
  - `Encontrá comercios, farmacias de turno y datos útiles cerca tuyo.`
- Bajada onboarding inicial:
  - `TuM2 te ayuda a encontrar soluciones locales cerca tuyo, cuando las necesitás.`

## Reglas de copy (obligatorias)

- El claim primario debe escribirse exactamente como:
  - `Lo que necesitás, en tu zona.`
- No usar variantes como:
  - `Lo que necesitás cerca tuyo`
  - `Todo lo que necesitás en tu zona`
  - `Lo que buscás, en tu zona`
  - `Tu zona, lo que necesitás`
- Evitar promesas no soportadas por el MVP:
  - compra directa
  - delivery garantizado
  - descuentos/promociones aseguradas
  - cobertura total o precisión perfecta

## Implementación técnica (mobile)

- Fuente central de copy:
  - `mobile/lib/core/copy/brand_copy.dart`
- Superficies actualizadas:
  - `mobile/lib/modules/auth/screens/splash_screen.dart`
  - `mobile/lib/modules/auth/screens/login_screen.dart` (`AUTH-03`)
  - `mobile/lib/modules/auth/screens/onboarding_screen.dart` (slide inicial)
- Test de contrato de copy:
  - `mobile/test/core/copy/brand_copy_test.dart`

## Impacto de infraestructura

- Sin cambios en backend.
- Sin cambios en Firestore.
- Sin cambios en Cloud Functions.
- Sin nuevas lecturas/escrituras/listeners.
- Sin dependencias nuevas.

## Criterios de aceptación

- Claim primario centralizado y reutilizable.
- Superficies de auth/entrada alineadas al copy aprobado.
- Documentación oficial de jerarquía y reglas de uso publicada.
- Auditoría de consistencia registrada en `docs/ops/AUDITORIA-TuM2-0002-claim-principal-2026-04-27.md`.
