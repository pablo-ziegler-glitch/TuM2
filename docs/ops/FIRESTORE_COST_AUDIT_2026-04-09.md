# Auditoría de consumo Firestore y arquitectura de lecturas — TuM2

## Resumen ejecutivo

Hipótesis principal confirmada: el gasto de lecturas está dominado por una combinación de consultas amplias (incluyendo fallback legacy por `zone`), ciclos de refetch por lifecycle de providers/pantallas y jobs/triggers backend con barridos completos.

Evidencia más fuerte:

- En facturación: `merchant_public WHERE zone = ?` con **4,768,872 lecturas** y ~**1,100 docs por ejecución**.
- En código: fallback activo `zone` en búsqueda pública ([mobile/lib/modules/search/repositories/merchant_search_repository.dart:41](../../mobile/lib/modules/search/repositories/merchant_search_repository.dart#L41)).
- Archivo crítico roto en búsqueda ([mobile/lib/modules/search/providers/search_notifier.dart:34](../../mobile/lib/modules/search/providers/search_notifier.dart#L34), [mobile/lib/modules/search/providers/search_notifier.dart:42](../../mobile/lib/modules/search/providers/search_notifier.dart#L42), [mobile/lib/modules/search/providers/search_notifier.dart:988](../../mobile/lib/modules/search/providers/search_notifier.dart#L988)) con duplicación de lógica/estado y 266 errores de análisis.

Cambios ya aplicados con impacto directo:

- Se eliminaron escrituras duplicadas nocturnas en `merchant_public` y se dejó sincronización vía `merchant_operational_signals` + trigger ([functions/src/jobs/refreshOpenStatuses.ts:83](../../functions/src/jobs/refreshOpenStatuses.ts#L83), [functions/src/jobs/refreshDuties.ts:84](../../functions/src/jobs/refreshDuties.ts#L84)).
- Se agregaron guards de recomputación para evitar proyecciones/escrituras redundantes en triggers (`merchants`, `signals`, `products`, `duties`, `schedules`).
- Se redujo N+1 en import admin web.
- Se dejó regla persistente de arquitectura de costo en proyecto ([AGENTS.md:1](../../AGENTS.md#L1), [docs/ARCHITECTURE.md:7](../ARCHITECTURE.md#L7)).

## Hallazgos críticos

### CRIT-01 — Módulo de búsqueda corrupto (riesgo funcional + costo impredecible)
- Evidencia: [mobile/lib/modules/search/providers/search_notifier.dart:34](../../mobile/lib/modules/search/providers/search_notifier.dart#L34), [mobile/lib/modules/search/providers/search_notifier.dart:42](../../mobile/lib/modules/search/providers/search_notifier.dart#L42), [mobile/lib/modules/search/providers/search_notifier.dart:988](../../mobile/lib/modules/search/providers/search_notifier.dart#L988).
- Validación: `dart analyze lib/modules/search/providers/search_notifier.dart` => 266 issues.
- Impacto costo: crítico (imposible garantizar deduplicación de lecturas, debounce y cache por zona).
- Causa raíz: merge accidental de dos implementaciones incompatibles en el mismo archivo.
- Solución: reconstruir archivo con una única versión canónica, tests de lifecycle + no-regresión de consultas.

### CRIT-02 — Query legacy por `zone` sigue activa en búsqueda pública
- Evidencia: [mobile/lib/modules/search/repositories/merchant_search_repository.dart:41](../../mobile/lib/modules/search/repositories/merchant_search_repository.dart#L41).
- Impacto costo: crítico; alinea con el patrón de facturación observado (`WHERE zone = ?` con alto fan-out de lecturas).
- Causa raíz: compatibilidad legacy sin plan de sunset y sin telemetría de uso residual.
- Solución: migrar 100% a `zoneId`, cortar fallback `zone` detrás de flag y desactivarlo por etapas.

### CRIT-03 — App Check desactivado en callables sensibles/admin
- Evidencia: [functions/src/callables/onboardingOwnerSubmit.ts:31](../../functions/src/callables/onboardingOwnerSubmit.ts#L31), [functions/src/callables/checkMerchantDuplicates.ts:86](../../functions/src/callables/checkMerchantDuplicates.ts#L86), [functions/src/callables/assignOwnerRole.ts:25](../../functions/src/callables/assignOwnerRole.ts#L25), [functions/src/jobs/bootstrap.ts:31](../../functions/src/jobs/bootstrap.ts#L31), [functions/src/admin/rebuildPublic.ts:23](../../functions/src/admin/rebuildPublic.ts#L23), [functions/src/admin/backfillKeywords.ts:130](../../functions/src/admin/backfillKeywords.ts#L130).
- Impacto costo: crítico por riesgo de abuso automatizado y picos artificiales.
- Solución: `enforceAppCheck: true` en callables no-internos + allowlist para tareas admin internas.

### CRIT-04 — Lecturas completas de `zones` sin filtros ni límite en varios módulos
- Evidencia: [mobile/lib/modules/search/repositories/zone_search_repository.dart:96](../../mobile/lib/modules/search/repositories/zone_search_repository.dart#L96), [mobile/lib/modules/home/repositories/open_now_repository.dart:50](../../mobile/lib/modules/home/repositories/open_now_repository.dart#L50), [mobile/lib/modules/pharmacy/repositories/zones_repository.dart:43](../../mobile/lib/modules/pharmacy/repositories/zones_repository.dart#L43), [mobile/lib/modules/brand/onboarding_owner/services/google_places_service.dart:202](../../mobile/lib/modules/brand/onboarding_owner/services/google_places_service.dart#L202), [web/lib/modules/import_data/data/import_data_repository.dart:166](../../web/lib/modules/import_data/data/import_data_repository.dart#L166).
- Impacto costo: crítico al escalar zonas/países; hoy parece barato, pero es patrón de crecimiento no acotado.
- Solución: query por `status in ['pilot_enabled','public_enabled']` + `limit` + cache local con TTL.

## Hallazgos altos

### HIGH-01 — AutoDispose en pantallas de alto tráfico fuerza refetch completo al reingresar
- Evidencia: [mobile/lib/modules/home/providers/open_now_notifier.dart:402](../../mobile/lib/modules/home/providers/open_now_notifier.dart#L402), [mobile/lib/modules/pharmacy/providers/pharmacy_duty_notifier.dart:374](../../mobile/lib/modules/pharmacy/providers/pharmacy_duty_notifier.dart#L374).
- Impacto costo: alto (cada navegación de ida/vuelta reconstruye estado y reconsulta Firestore).
- Solución: `keepAlive` controlado + TTL en repositorio por `zoneId|date`.

### HIGH-02 — Reglas aún pueden disparar read de `merchants` en writes owner
- Evidencia: [firestore.rules:33](../../firestore.rules#L33), [firestore.rules:39](../../firestore.rules#L39).
- Estado: mitigado con claims-first, pero fallback sigue leyendo doc cuando falta claim.
- Impacto costo: alto en operaciones owner frecuentes.
- Solución: garantizar claim `merchantId` obligatorio en owners + eliminar fallback.

### HIGH-03 — `import_batches` en tiempo real sin límite en admin web
- Evidencia: [web/lib/modules/import_data/data/import_data_repository.dart:125](../../web/lib/modules/import_data/data/import_data_repository.dart#L125), [web/lib/modules/import_data/screens/import_list_screen.dart:45](../../web/lib/modules/import_data/screens/import_list_screen.dart#L45), [web/lib/modules/import_data/screens/import_batch_history_screen.dart:51](../../web/lib/modules/import_data/screens/import_batch_history_screen.dart#L51).
- Impacto costo: alto en cuentas con histórico grande.
- Solución: limitar stream a últimas N entradas y cargar histórico por paginación on-demand.

### HIGH-04 — `adminRebuildMerchantPublic` mantiene patrón N+1 de lecturas de señales
- Evidencia: [functions/src/admin/rebuildPublic.ts:69](../../functions/src/admin/rebuildPublic.ts#L69), [functions/src/admin/rebuildPublic.ts:85](../../functions/src/admin/rebuildPublic.ts#L85).
- Impacto costo: alto en backfills globales.
- Solución: leer señales en lotes por `whereIn(documentId)` o prescindir de señales si no cambian campos operativos.

### HIGH-05 — Trigger de reportes lee documentos completos para contar
- Evidencia: [functions/src/triggers/reports.ts:39](../../functions/src/triggers/reports.ts#L39).
- Impacto costo: alto si aumenta volumen de reportes.
- Solución: `count()` aggregate o contador incremental por `merchantId`.

### HIGH-06 — Dedupe de `external_places` consulta hasta 600 merchants por alta
- Evidencia: [functions/src/triggers/externalPlaces.ts:33](../../functions/src/triggers/externalPlaces.ts#L33).
- Impacto costo: alto en importaciones masivas.
- Solución: limitar por hash geográfico/nombre normalizado y/o preíndice de dedupe.

## Hallazgos medios

### MED-01 — Doble refresh forzado de token en auth
- Evidencia: [mobile/lib/core/auth/auth_notifier.dart:41](../../mobile/lib/core/auth/auth_notifier.dart#L41), [mobile/lib/core/providers/auth_providers.dart:504](../../mobile/lib/core/providers/auth_providers.dart#L504), [mobile/lib/core/auth/auth_role_provider.dart:21](../../mobile/lib/core/auth/auth_role_provider.dart#L21).
- Impacto: medio (latencia/red; puede inducir fallback innecesario a Firestore en algunos flujos).

### MED-02 — `cleanupExpiredDrafts` hace barrido horario potencialmente amplio
- Evidencia: [functions/src/jobs/cleanupExpiredDrafts.ts:32](../../functions/src/jobs/cleanupExpiredDrafts.ts#L32).
- Impacto: medio, depende de volumen de `users`.
- Solución: índice auxiliar por estado + paginación por lote.

### MED-03 — Inconsistencia de naming canónico persiste en tipos/backend
- Evidencia: [functions/src/lib/types.ts:60](../../functions/src/lib/types.ts#L60), [functions/src/lib/types.ts:151](../../functions/src/lib/types.ts#L151), [functions/src/lib/projection.ts:203](../../functions/src/lib/projection.ts#L203).
- Impacto: medio (mantiene deuda y bifurca queries).

### MED-04 — Fallback de búsqueda por `zone` todavía habilitado
- Evidencia: [mobile/lib/modules/search/repositories/merchant_search_repository.dart:43](../../mobile/lib/modules/search/repositories/merchant_search_repository.dart#L43).
- Impacto: medio/alto según porcentaje de documentos legacy.

## Hallazgos bajos

### LOW-01 — Timers locales no Firestore, pero sumarizan ruido operativo
- Evidencia: [mobile/lib/modules/auth/screens/verify_email_screen.dart:81](../../mobile/lib/modules/auth/screens/verify_email_screen.dart#L81), [mobile/lib/modules/brand/onboarding_owner/services/duplicate_check_service.dart:40](../../mobile/lib/modules/brand/onboarding_owner/services/duplicate_check_service.dart#L40).

### LOW-02 — Stream `watchDraft()` existe pero no se usa en flujo actual
- Evidencia: [mobile/lib/modules/brand/onboarding_owner/repositories/onboarding_owner_repository.dart:38](../../mobile/lib/modules/brand/onboarding_owner/repositories/onboarding_owner_repository.dart#L38).

## Mapa de queries encontradas

> Esta tabla cumple el formato requerido de inventario de accesos/queries.

| archivo | función/clase/provider | colección | operación | filtros aplicados | usa `zone` o `zoneId` | usa `limit` | riesgo de costo | problema detectado | fix recomendado |
|---|---|---|---|---|---|---|---|---|---|
| mobile/lib/modules/search/repositories/merchant_search_repository.dart:27 | `fetchZoneCorpus` | `merchant_public` | `get` | `zoneId == ?`, `visibilityStatus in (...)` | `zoneId` | sí (200) | medio | correcto, pero depende de fallback legacy | mantener y agregar métrica de uso |
| mobile/lib/modules/search/repositories/merchant_search_repository.dart:41 | `fetchZoneCorpus` fallback | `merchant_public` | `get` | `zone == ?`, `visibilityStatus in (...)` | `zone` | sí (200) | **crítico** | path legacy alinea con gasto detectado | apagar fallback por flag + migración |
| mobile/lib/modules/home/repositories/open_now_repository.dart:107 | `fetchOpenNow` | `merchant_public` | `get` | `zoneId`, `visibilityStatus=visible`, `isOpenNow=true` | `zoneId` | sí | medio | OK, pero se dispara por reentrada de pantalla | keepAlive+TTL |
| mobile/lib/modules/home/repositories/open_now_repository.dart:127 | `fetchFallback` | `merchant_public` | `get` | `zoneId`, `visibilityStatus=visible`, `isOpenNow=false` | `zoneId` | sí | medio | segunda query por flujo sin openNow | cache local por zona |
| mobile/lib/modules/pharmacy/repositories/pharmacy_duty_repository.dart:53 | `fetchPublishedDuties` | `pharmacy_duties` | `get` | `zoneId`, `date`, `status=published` | `zoneId` | no | medio | sin límite explícito | agregar `limit` por máximo operativo |
| mobile/lib/modules/pharmacy/repositories/pharmacy_duty_repository.dart:78 | `fetchMerchantsByIds` | `merchant_public` | `get` | `documentId in chunk` | n/a | implícito por chunk | bajo | correcto | mantener |
| mobile/lib/modules/merchant_detail/data/merchant_detail_repository.dart:35 | `fetchMerchantPublic` | `merchant_public` | `get` | doc por id | n/a | n/a | bajo | correcto | mantener |
| mobile/lib/modules/merchant_detail/data/merchant_detail_repository.dart:55 | `fetchActivePharmacyDuty` | `pharmacy_duties` | `get` | `merchantId`, `status`, `date` | n/a | sí (3) | bajo | correcto | mantener |
| mobile/lib/modules/merchant_detail/data/merchant_detail_repository.dart:128 | `fetchFeaturedProducts` | `merchant_products` | `get` | `merchantId`, `status`, `visibilityStatus`, `orderBy updatedAt` | n/a | sí | bajo | correcto | mantener |
| mobile/lib/core/providers/auth_providers.dart:552 | `ownerMerchantIdProvider` fallback | `merchants` | `get` | `ownerUserId == uid` | n/a | sí (1) | bajo | mitigado por claims-first | mantener fallback controlado |
| mobile/lib/modules/owner/repositories/owner_repository.dart:18 | `resolveOwnerMerchant` | `merchants` | `get` | `ownerUserId == uid` | n/a | sí (10) | bajo | correcto | mantener |
| mobile/lib/modules/search/repositories/zone_search_repository.dart:96 | `_fetchActiveZoneDocs` | `zones` | `get` | ninguno | n/a | no | **crítico** | lectura completa de colección | query por estado + límite + cache |
| mobile/lib/modules/pharmacy/repositories/zones_repository.dart:43 | `_fetchActiveZoneDocs` | `zones` | `get` | ninguno | n/a | no | **crítico** | mismo patrón | unificar repo cacheado |
| mobile/lib/modules/home/repositories/open_now_repository.dart:50 | `_fetchActiveZoneDocs` | `zones` | `get` | ninguno | n/a | no | **crítico** | mismo patrón | unificar repo cacheado |
| mobile/lib/modules/brand/onboarding_owner/services/google_places_service.dart:202 | `resolveZone` | `zones` | `get` | ninguno | n/a | no | alto | se ejecuta en onboarding dirección | índice geohash + query acotada |
| web/lib/modules/import_data/data/import_data_repository.dart:125 | `watchBatches` | `import_batches` | `snapshots` | `orderBy createdAt desc` | n/a | no | alto | listener sin límite | limitar a últimas N + paginado |
| web/lib/modules/import_data/data/import_data_repository.dart:132 | `watchBatch` | `import_batches/{id}` | `snapshots` | doc id | n/a | n/a | bajo | correcto | mantener |
| web/lib/modules/import_data/data/import_data_repository.dart:166 | `_fetchActiveZoneDocs` | `zones` | `get` | ninguno | n/a | no | alto | lectura completa en admin import wizard | cache compartida |
| web/lib/modules/import_data/data/import_data_repository.dart:216 | `publishBatch` | `external_places` | `get` | `importBatchId == batch.id` | n/a | no | medio | depende tamaño batch | paginación server-side |
| web/lib/modules/import_data/data/import_data_repository.dart:895 | `_fetchExistingDedupeKeys` | `external_places` | `get` | `dedupeKey in chunk` | n/a | chunk | medio | correcto tras refactor N+1 | mantener |
| functions/src/jobs/refreshOpenStatuses.ts:33 | `nightlyRefreshOpenStatuses` | `merchant_public` | `get` | `visibilityStatus=visible` | n/a | no | alto | barrido diario completo | migrar a actualización selectiva |
| functions/src/jobs/refreshOpenStatuses.ts:53 | `nightlyRefreshOpenStatuses` | `merchant_schedules/{id}` | `get` | doc por id en chunks | n/a | chunk | medio | puede escalar, pero mejorado | evaluar materialized nextChangeAt |
| functions/src/jobs/refreshDuties.ts:31 | `nightlyRefreshPharmacyDutyFlags` | `merchant_public` | `get` | `isPharmacy=true`, `visibilityStatus=visible` | n/a | no | alto | barrido completo diario | selectivo por cambios del día |
| functions/src/jobs/refreshDuties.ts:42 | `nightlyRefreshPharmacyDutyFlags` | `pharmacy_duties` | `get` | `date`, `status=published` | n/a | no | medio | depende cardinalidad diaria | mantener con límites por zona |
| functions/src/admin/backfillKeywords.ts:64 | `runBackfillSearchKeywords` | `merchant_public` | `get` | ninguno | n/a | no | alto | full scan total | ejecutar solo por ventanas/cursores |
| functions/src/admin/rebuildPublic.ts:69 | `rebuildAll` | `merchants` | `get` | `visibilityStatus in (...)` | n/a | no | alto | full scan + N+1 de señales | procesar por páginas + batch read |
| functions/src/admin/rebuildPublic.ts:85 | `rebuildAll` | `merchant_operational_signals/{id}` | `get` | doc por merchant | n/a | n/a | alto | N+1 | `whereIn` por lotes |
| functions/src/coverage/zoneCoverage.ts:115 | `refreshZoneCoverage` | `merchant_public` | `get` | `zoneId==?` y fallback `zone==?` | ambos | no | alto | doble scan por zona | retirar fallback `zone` |
| functions/src/coverage/zoneCoverage.ts:236 | `scheduledRefreshZoneCoverage` | `zones` | `get` | ninguno | n/a | no | medio | barrido completo diario | limitar a zonas activas |
| functions/src/triggers/externalPlaces.ts:33 | `onExternalPlaceCreateNormalize` | `merchants` | `get` | `zoneId==?` fallback `zone==?` | ambos | sí (600) | alto | costo lineal por alta | dedupe indexado |
| functions/src/triggers/duties.ts:67 | `onPharmacyDutyWriteSyncMerchant` | `pharmacy_duties` | `get` | `merchantId`,`date=today`,`status=published` | n/a | sí (1) | bajo | correcto y acotado | mantener |
| functions/src/triggers/products.ts:119 | `merchantHasActiveVisibleProducts` | `merchant_products` | `get` | `merchantId`,`status`,`visibilityStatus` | n/a | sí (1) | bajo | correcto | mantener |
| functions/src/callables/checkMerchantDuplicates.ts:117 | `checkMerchantDuplicates` | `merchants` | `get` | `zoneId==?` fallback `zone==?` | ambos | sí (250) | alto | potencialmente amplio + fallback | eliminar `zone` + normalizar |
| firestore.rules:33 | `merchantBelongsToUserByDoc` | `merchants/{id}` | `rule-read` | `get()` por ownership | n/a | n/a | alto | lectura extra en reglas cuando falta claim | claim obligatorio owner |

## Patrones de listeners y polling

### Listeners Firestore/Auth detectados

- `authStateChanges` mobile global: [mobile/lib/core/auth/auth_notifier.dart:27](../../mobile/lib/core/auth/auth_notifier.dart#L27).  
  Inicio: arranque app. Fin: `dispose()` ([mobile/lib/core/auth/auth_notifier.dart:117](../../mobile/lib/core/auth/auth_notifier.dart#L117)).  
  TTL: vive toda la sesión.

- `authStateChanges` web router: [web/lib/core/router/app_router.dart:126](../../web/lib/core/router/app_router.dart#L126).  
  Inicio: creación router. Fin: `dispose()` ([web/lib/core/router/app_router.dart:134](../../web/lib/core/router/app_router.dart#L134)).

- `merchant_products` owner list: [mobile/lib/modules/owner/repositories/firebase_product_repository.dart:28](../../mobile/lib/modules/owner/repositories/firebase_product_repository.dart#L28) via `StreamProvider.autoDispose` ([mobile/lib/modules/owner/providers/product_providers.dart:17](../../mobile/lib/modules/owner/providers/product_providers.dart#L17)).  
  Inicio: pantalla productos owner. Fin: auto dispose al salir.

- `merchant_products/{id}` owner form/detail: [mobile/lib/modules/owner/repositories/firebase_product_repository.dart:44](../../mobile/lib/modules/owner/repositories/firebase_product_repository.dart#L44) via `StreamProvider.autoDispose` ([mobile/lib/modules/owner/providers/product_providers.dart:25](../../mobile/lib/modules/owner/providers/product_providers.dart#L25)).

- `import_batches` admin list/history: [web/lib/modules/import_data/data/import_data_repository.dart:125](../../web/lib/modules/import_data/data/import_data_repository.dart#L125), usado en [import_list_screen.dart:45](../../web/lib/modules/import_data/screens/import_list_screen.dart#L45) y [import_batch_history_screen.dart:51](../../web/lib/modules/import_data/screens/import_batch_history_screen.dart#L51).  
  Riesgo: listener sin `limit`.

- `import_batches/{id}` admin detail: [web/lib/modules/import_data/data/import_data_repository.dart:132](../../web/lib/modules/import_data/data/import_data_repository.dart#L132), usado en [import_result_screen.dart:46](../../web/lib/modules/import_data/screens/import_result_screen.dart#L46).

### Subscriptions no Firestore (lifecycle correcto)

- Duplicados onboarding (`DuplicateCheckService`): cancelado en `dispose` ([step1_tipo_nombre_screen.dart:115](../../mobile/lib/modules/brand/onboarding_owner/screens/step1_tipo_nombre_screen.dart#L115)).
- Submit onboarding: cancelado en `dispose` ([step4_confirmacion_screen.dart:80](../../mobile/lib/modules/brand/onboarding_owner/screens/step4_confirmacion_screen.dart#L80)).

### Polling/timers/frecuencia real

- `VerifyEmailScreen`: `Timer.periodic(1s)` ([mobile/lib/modules/auth/screens/verify_email_screen.dart:81](../../mobile/lib/modules/auth/screens/verify_email_screen.dart#L81)); no toca Firestore.
- Duplicados onboarding: debounce 800ms ([mobile/lib/modules/brand/onboarding_owner/services/duplicate_check_service.dart:40](../../mobile/lib/modules/brand/onboarding_owner/services/duplicate_check_service.dart#L40)).
- Search notifier (archivo roto): debounce 250ms ([mobile/lib/modules/search/providers/search_notifier.dart:302](../../mobile/lib/modules/search/providers/search_notifier.dart#L302)).
- Schedulers backend:
  - `nightlyRefreshOpenStatuses` diario 03:05 ART ([functions/src/jobs/refreshOpenStatuses.ts:25](../../functions/src/jobs/refreshOpenStatuses.ts#L25)).
  - `nightlyRefreshPharmacyDutyFlags` diario 03:10 ART ([functions/src/jobs/refreshDuties.ts:21](../../functions/src/jobs/refreshDuties.ts#L21)).
  - `nightlyCleanupExpiredDrafts` cada hora ([functions/src/jobs/cleanupExpiredDrafts.ts:20](../../functions/src/jobs/cleanupExpiredDrafts.ts#L20)).
  - `scheduledRefreshZoneCoverage` diario 04:00 ART ([functions/src/coverage/zoneCoverage.ts:228](../../functions/src/coverage/zoneCoverage.ts#L228)).

### TTL detectados (distinción requerida)

- TTL lifecycle listener/subscription: no TTL de negocio automático; vive hasta `dispose`/desuscripción.
- TTL caché local:
  - Borrador onboarding local + expiración lógica de 72h ([mobile/lib/modules/brand/onboarding_owner/repositories/onboarding_owner_repository.dart:24](../../mobile/lib/modules/brand/onboarding_owner/repositories/onboarding_owner_repository.dart#L24), [mobile/lib/modules/brand/onboarding_owner/repositories/onboarding_owner_repository.dart:247](../../mobile/lib/modules/brand/onboarding_owner/repositories/onboarding_owner_repository.dart#L247)).
- TTL sesión/auth: token Firebase estándar; en app se fuerza refresh manual en varios puntos.
- TTL documentos/jobs:
  - Cleanup drafts horario (expiración lógica de onboarding) ([functions/src/jobs/cleanupExpiredDrafts.ts:6](../../functions/src/jobs/cleanupExpiredDrafts.ts#L6)).
- Refresh interval de configuración:
  - Remote Config `minimumFetchInterval = 30 min` ([mobile/lib/core/providers/feature_flags_provider.dart:14](../../mobile/lib/core/providers/feature_flags_provider.dart#L14)).

## Riesgos de seguridad asociados

- Callables con App Check desactivado exponen vectores de abuso de costo y scraping.
- Lecturas públicas amplias en `merchant_public` sin disciplina de scope/límite pueden ser explotadas por clientes automatizados.
- Reglas con fallback `get(merchants/{id})` elevan superficie de costo y latencia en rutas owner.

## Riesgos de UX/performance

- Refetch al navegar por `autoDispose` en flujos de alto tráfico (Abierto ahora/Farmacias).
- Módulo Search inestable por archivo corrupto (riesgo de pantallas bloqueadas y resultados inconsistentes).
- Streams admin sin límite degradan dashboards con histórico grande.

## Impacto económico estimado

| Acción | Estado | Ahorro esperado |
|---|---|---|
| Apagar fallback `zone` en búsqueda pública | pendiente | **muy alto** |
| Corregir `search_notifier.dart` y garantizar una sola ruta de carga por zona | pendiente | **alto** |
| `keepAlive+TTL` en providers de Home/Pharmacy | pendiente | **alto** |
| Cachear zonas con TTL y eliminar lecturas completas repetidas | pendiente | **alto** |
| Activar App Check en callables críticos | pendiente | **alto** (por prevención de abuso) |
| Evitar escrituras duplicadas nocturnas en `merchant_public` | **implementado** | **medio-alto** |
| Guards de diffs en triggers (`merchants/signals/products/duties/schedules`) | **implementado** | **alto** |
| Refactor N+1 en import admin (`external_places`/`merchants`) | **implementado** | **medio-alto** |
| Claims-first en ownership rules/provider | **implementado** | **medio** |

## Plan de remediación priorizado (24h / 72h / 2 semanas)

### 24h (P0)

1. Reparar y testear `search_notifier.dart` (bloqueante).
2. Instrumentar métrica de uso de fallback `zone` y cortar fallback por flag en staging.
3. Activar App Check en callables expuestos (`onboardingOwnerSubmit`, `checkMerchantDuplicates`, `assignOwnerRole`).
4. Limitar listeners de `import_batches` a últimas N filas.

### 72h (P1)

1. Introducir repositorio único de `zones` con cache local + TTL.
2. Cambiar `openNowNotifierProvider` y `pharmacyDutyProvider` a lifecycle híbrido (`keepAlive` + invalidación por TTL/manual refresh).
3. Reemplazar contador de reportes por aggregate/count o contador incremental.
4. Quitar fallback `zone` en funciones internas que ya tengan cobertura `zoneId`.

### 2 semanas (P2)

1. Migración completa de schema: deprecación de `zone/category` legacy.
2. `adminRebuildMerchantPublic` paginado con lecturas en lote de señales.
3. `cleanupExpiredDrafts` y `zoneCoverage` con procesamiento paginado/segmentado.
4. Suite de no-regresión de costo en emuladores (reads/writes por caso de uso).

## Quick wins

- ✅ Se eliminaron writes redundantes nocturnos a `merchant_public` en jobs de open status y duty flags.
- ✅ Se agregaron diff-guards para evitar recomputación y escrituras iguales en triggers.
- ✅ Se redujo N+1 en import admin web.
- ✅ Se movió ownership a claims-first en rules/provider.
- ✅ Se documentó restricción de costo como política de primer nivel ([AGENTS.md](../../AGENTS.md), [docs/ARCHITECTURE.md](../ARCHITECTURE.md)).
- ✅ Se implementó gate automático de regresión de costo basado en Cloud Monitoring ([functions/scripts/firestore_cost_guard.js](../../functions/scripts/firestore_cost_guard.js), [docs/ops/firestore_cost_thresholds.json](./firestore_cost_thresholds.json)).
- ✅ Se documentó playbook operativo de dashboard + alertas + release gate ([docs/ops/FIRESTORE_COST_GUARDRAILS.md](./FIRESTORE_COST_GUARDRAILS.md)).

## Deuda técnica relacionada

- `search_notifier.dart` corrupto (P0 inmediato).
- Naming mixto `zone/zoneId` y `category/categoryId` en backend/tipos.
- Schedulers con barrido completo sin segmentación.
- App Check desactivado en callables sensibles.

## Checklist de validación post-fix

- [ ] Query de búsqueda pública en prod usa solo `zoneId` (0% fallback `zone`).
- [ ] Todas las queries públicas masivas tienen `limit`/paginación.
- [ ] Callables públicos con `enforceAppCheck: true`.
- [ ] `search_notifier.dart` sin errores de análisis.
- [ ] Home/Pharmacy no reconsultan Firestore al back/forward dentro de TTL.
- [ ] Dashboards admin con listeners limitados/paginados.
- [ ] Reglas owner sin read fallback en ruta normal (claim presente).
- [ ] Alarmas de presupuesto configuradas por proyecto (dev/staging/prod) en GCP.
- [ ] Dashboard de Firestore por colección con alertas de picos en GCP.
- [ ] Test de no-regresión de costo ejecutado en emuladores antes de release.
