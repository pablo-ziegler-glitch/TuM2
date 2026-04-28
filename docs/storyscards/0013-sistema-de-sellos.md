# TuM2-0013 — Sistema de sellos operativos y de confianza costo-eficientes

## Estado

- Implementado en `develop` (backend + mobile).
- Alcance centrado en costo Firestore y separación entre estado operativo temporal vs sellos de confianza persistidos.

## Cambios técnicos implementados

### Backend (Cloud Functions)

- `TrustBadgeId` tipado y canónico en `functions/src/lib/types.ts`.
- `computeTrustBadges()` implementado en `functions/src/lib/projection.ts`.
- `computePrimaryTrustBadge()` implementado con prioridad:
  `duty_loaded > schedule_verified > verified_merchant > claimed_by_owner > validated_info > schedule_updated > community_info > visible_in_tum2`.
- `computeSortBoost()` refactorizado a función pura y testeable con base por verificación + bonos y tope `120`.
- Integración de badges y campos derivados en `computeMerchantPublicProjection()`:
  - `badges`
  - `primaryTrustBadge`
  - `sortBoost` derivado backend-only
  - `scheduleSummary`
  - `nextOpenAt`, `nextCloseAt`, `nextTransitionAt`
  - `isOpenNowSnapshot`, `snapshotComputedAt`
- Helper `computeNextScheduleTransition()` en `functions/src/lib/schedules.ts`.
- Trigger de horarios (`triggers/schedules.ts`) ahora persiste snapshot y transición próxima en `merchant_operational_signals`.
- Trigger de turnos (`triggers/duties.ts`) ahora persiste `pharmacyDutyStatus` para habilitar badge `duty_loaded` sin consultas extra.
- Trigger de señales (`triggers/signals.ts`) ajustado para no saltear sync cuando cambian campos de transición/schedule (mantiene no-op write avoidance).

### Jobs y costo

- `nightlyRefreshOpenStatuses` dejó de escanear ventanas globales por cursor.
- Nuevo patrón: query scoped por `nextTransitionAt <= now`, `visibilityStatus == visible`, `orderBy(nextTransitionAt)`, `limit 300`.
- Se agregó índice compuesto para este patrón en `firestore.indexes.json`.

### Flutter (Mobile/Web pública)

- Nuevos componentes reutilizables:
  - `TrustBadgeChip`
  - `TrustBadgeRow`
- Nuevos modelos parseados desde `merchant_public`:
  - `badges`
  - `primaryTrustBadge`
  - `scheduleSummary`
  - `nextOpenAt`, `nextCloseAt`, `nextTransitionAt`
  - `isOpenNowSnapshot`, `snapshotComputedAt`
- Nuevo helper puro:
  - `resolveOperationalStatus({ now, merchant })`
  - sin lecturas ni escrituras Firestore
  - respeta prioridad de señales manuales (`vacation`, `temporary_closure`, `delay`)
- Integración UI con límites:
  - Search card: máximo 1 trust badge
  - Detail header: máximo 3 trust badges
  - Map bottom sheet: máximo 1 trust badge
- Feature flags Remote Config agregados:
  - `trust_badges_enabled` (default `false`)
  - `trust_badges_detail_enabled` (default `false`)
  - `trust_badges_search_enabled` (default `false`)
  - `client_open_status_resolution_enabled` (default `true`)

## Seguridad

- Se mantiene la regla canónica: `merchant_public` es read-only para cliente (`allow write: if false`).
- Por diseño, cliente no puede escribir `badges`, `sortBoost`, `verificationStatus`, `sourceType`, `visibilityStatus` en `merchant_public`.

## Validación y tests

### Functions

- Agregados tests para:
  - `verified_merchant`
  - `validated_info`
  - `claimed_by_owner`
  - `community_info`
  - `schedule_updated` reciente / viejo
  - `schedule_verified`
  - `duty_loaded`
  - prioridad de `primaryTrustBadge`
  - orden y tope de `sortBoost`
- No-op write avoidance: cubierto por `publicProjectionSync.test.ts` (sin regressions).

### Flutter

- Agregados tests para:
  - label correcto de `TrustBadgeChip`
  - límite visible de `TrustBadgeRow`
  - badge desconocido no crashea
  - `resolveOperationalStatus` en escenarios open/closed/manual override/delay

## Impacto explícito de costo Firestore

- 0 listeners nuevos en listados.
- 0 queries extra por card para mostrar trust badges.
- 0 colecciones nuevas para badges.
- 0 writes por paso natural del reloj en cliente.
- Job de refresco operativo acotado por `nextTransitionAt` + `limit`, sin escaneo full de `merchant_public`.
- Proyección pública mantiene no-op write avoidance para reducir write amplification.

## Deuda residual (fuera de alcance de 0013)

- `client_open_status_resolution_enabled` quedó disponible en Remote Config, pero aún no se usa como switch global único para todas las superficies de UI.
- El cálculo de transición horaria asume operación en zona horaria Argentina (`UTC-3`) según alcance MVP actual.
- No se implementó cron global nuevo ni recompute masivo; solo se endureció el job existente.
