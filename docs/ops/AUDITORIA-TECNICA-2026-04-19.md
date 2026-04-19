# Auditoría técnica extensa — TuM2 (2026-04-19)

## Contexto y criterio de auditoría

Esta auditoría prioriza costo Firestore, escalabilidad operativa y cumplimiento de reglas de arquitectura del repo:

- minimizar lecturas y listeners
- evitar queries sin límites/paginación
- mantener scope por `zoneId`/`visibilityStatus` cuando aplica
- reducir writes redundantes
- preservar dual-collection (`merchants` + `merchant_public`) y claims vía Functions

---

## Resumen ejecutivo

Se detectaron **8 problemas relevantes** (3 críticos de costo, 3 altos, 2 medios) que conviene resolver antes de crecimiento de tráfico.

### Top 3 de mayor impacto

1. **Backfill admin con lectura completa de `merchant_public` sin paginación.**
2. **Lecturas no acotadas en flujos de reasignación de guardias (mobile + functions).**
3. **Carga completa de subcolecciones de horarios sin ventana temporal ni límite.**

---

## Hallazgos detallados

## 1) [CRÍTICO] Backfill de keywords escanea toda `merchant_public` de una vez

**Evidencia:** `functions/src/admin/backfillKeywords.ts` hace `collection("merchant_public").get()` sobre toda la colección.

**Riesgo:**
- costo de lectura lineal al total de comercios
- presión de memoria/tiempo en invocaciones grandes
- riesgo de timeout/reintentos y sobrecostos

**Recomendación:**
- paginar por `orderBy(documentId)` + `startAfter` + `limit`
- permitir ejecución por `zoneId` o por rango de IDs
- checkpoint persistente de cursor para reanudar

---

## 2) [CRÍTICO] Query sin límite para requests de ronda en mobile

**Evidencia:** `mobile/lib/modules/owner/pharmacy/data/pharmacy_duty_flow_repository.dart` consulta `pharmacy_duty_reassignment_requests` por `roundId` con `.get()` sin `.limit()`.

**Riesgo:**
- lectura no acotada si una ronda crece
- latencia y costo variable en pantallas operativas

**Recomendación:**
- agregar paginación real (`orderBy(createdAt)` + `limit` + cursor)
- usar filtros de estado (`pending`, `accepted`, etc.) según vista

---

## 3) [CRÍTICO] Query sin límite para requests pendientes dentro de transacción

**Evidencia:** `functions/src/callables/pharmacyDuties.ts` lee requests pendientes por `roundId` + `status` sin `limit` en una transacción.

**Riesgo:**
- mayor costo en mutaciones críticas
- transacciones más pesadas y propensas a retry

**Recomendación:**
- mantener contador/índice agregado por ronda (pendingCount)
- reemplazar escaneo total por lectura puntual del contador
- si es imprescindible leer docs, paginar y limitar por necesidad de negocio

---

## 4) [ALTO] Lectura completa de excepciones/cierres en horarios (backend)

**Evidencia:** `functions/src/lib/ownerSchedules.ts` consulta completas las subcolecciones `schedule_exceptions` y `schedule_exceptions_ranges`.

**Riesgo:**
- costo crece con historial acumulado
- recomputaciones periódicas más caras por comercio

**Recomendación:**
- consultar solo ventana necesaria (ej. hoy ± N días)
- usar TTL/archivo histórico fuera de la ruta caliente
- añadir límites por consulta y partición temporal

---

## 5) [ALTO] Lectura completa de excepciones/cierres en horarios (mobile)

**Evidencia:** `mobile/lib/modules/owner/schedules/owner_schedule_repository.dart` hace `exceptionsRef.get()` y `closuresRef.get()` sin límites ni rango temporal.

**Riesgo:**
- costo por apertura de pantalla crece indefinidamente
- posible degradación de UX en comercios con mucha historia

**Recomendación:**
- esquema de “activos + próximos N días” para UI
- paginación histórica separada en pantalla secundaria

---

## 6) [ALTO] Operaciones de importación masiva sin paginación de lectura base

**Evidencia:** `web/lib/modules/import_data/data/import_data_repository.dart` en `publishBatch` y `revertBatch` hace `.where('importBatchId', ...).get()` sin page loop.

**Riesgo:**
- lotes grandes leen todo en memoria de una vez
- costo pico y latencia alta en operaciones admin

**Recomendación:**
- paginar por `documentId`/`createdAt`
- procesar en jobs o etapas con checkpoints
- exponer progreso incremental en UI admin

---

## 7) [MEDIO] Carga de zonas truncada a 300 sin paginación

**Evidencia:** `mobile/lib/core/cache/zones_cache_service.dart` usa `limit(300)` sin loop de paginación.

**Riesgo:**
- inconsistencia funcional si zonas >300
- sesgo geográfico/operativo por dataset incompleto

**Recomendación:**
- paginar igual que otras capas (`startAfterDocument`)
- mantener cache TTL pero sobre dataset completo

---

## 8) [MEDIO] Carga de categorías sin limit ni paginación

**Evidencia:** `mobile/lib/modules/brand/onboarding_owner/repositories/categories_repository.dart` ejecuta `collection('categories').get()` completo.

**Riesgo:**
- acoplamiento a que `categories` permanezca pequeña
- costo innecesario en cold start del flujo

**Recomendación:**
- aplicar `limit` defensivo y orden estable
- cache local con versión (`admin_configs/catalog_limits` o doc de versión)

---

## Riesgos transversales detectados

- Hay listeners válidos por UX, pero conviene revisar si cada stream necesita realtime permanente (especialmente onboarding).
- Existen pruebas de integración marcadas como `skip` (dependencia de emulador), lo que reduce cobertura real en puntos sensibles de costo y consistencia.
- Se mantiene compatibilidad legacy de campos (`category`/`zone`) en varios modelos; conviene un plan de retiro controlado hacia canónicos (`categoryId`/`zoneId`).

---

## Plan de remediación propuesto

## Fase 1 (rápida, 1-2 días)
- Agregar `limit` + paginación en:
  - `fetchRequestsForRound` (mobile)
  - queries de import batch (web)
  - categorías (mobile)
- Instrumentar logs de tamaño de resultado por query crítica.

## Fase 2 (costo estructural, 3-5 días)
- Refactor de `backfillSearchKeywords` a procesamiento paginado + checkpoint.
- Refactor de `ownerSchedules` (backend y mobile) a ventana temporal + histórico paginado.
- Introducir contadores agregados en rondas de reasignación para eliminar scans de pendientes.

## Fase 3 (gobernanza continua)
- Añadir “lint de costo Firestore” en CI para bloquear `.get()` sin `limit` en rutas críticas.
- Presupuesto de lecturas por feature y alertas por regresión.

---

## KPI sugeridos para validar mejora

- **Lecturas promedio por sesión** en Owner Onboarding, Owner Schedules y Pharmacy Reassignment.
- **P95 de latencia** en pantallas Owner/Pharmacy.
- **Costo diario Firestore** por feature (antes/después).
- **Writes evitadas** por optimizaciones de batch/checkpoint.

---

## Conclusión

La base respeta decisiones arquitectónicas importantes (dual-collection, proyección pública server-side), pero aún hay rutas con lecturas no acotadas que pueden escalar mal en costo. Resolver los 3 hallazgos críticos debería ser prioridad inmediata para mantener sostenibilidad económica al crecer tráfico y volumen de datos.
