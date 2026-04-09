# TuM2 — Arquitectura del sistema v1

Documento técnico de referencia para el equipo. Describe las decisiones de arquitectura, el stack, la estructura de datos y los patrones de integración.

---

## 0. Guardrail de costo Firestore (primer nivel)

Toda evolución del sistema debe cumplir explícitamente:

- minimización de lecturas Firestore
- eliminación de listeners innecesarios
- uso obligatorio de `limit` y/o paginación real
- evitar queries amplias sin scope (`zoneId`, `visibilityStatus`)
- preferir cache + TTL/control de invalidez frente a realtime permanente
- evitar polling/refetch agresivo
- reducir writes redundantes en Cloud Functions
- diseñar con costo como constraint desde el inicio

Incumplir este bloque es un error crítico de arquitectura (impacto económico).

---

## 1. Visión general

TuM2 es una plataforma de información de comercios locales compuesta por:

```
┌─────────────────────────────────────────────────────────────────┐
│                         CLIENTES                                │
│  App Mobile (Flutter)              │  Web pública (Flutter Web) │
└───────────────────────┬─────────────────────────────────────────┘
                        │ Firestore SDK / REST
┌───────────────────────▼─────────────────────────────────────────┐
│                     FIREBASE                                    │
│  Authentication  │  Firestore  │  Cloud Functions  │  Storage   │
└───────────────────────┬─────────────────────────────────────────┘
                        │ Admin SDK
┌───────────────────────▼─────────────────────────────────────────┐
│               DATOS EXTERNOS (solo admin)                       │
│  Google Places API (fuente semilla)  │  Futuras fuentes         │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. Stack técnico

| Capa | Tecnología | Versión | Notas |
|------|-----------|---------|-------|
| Mobile | Flutter | — | iOS + Android |
| Navegación | Flutter Navigator 2 / go_router | — | Bottom tabs + Stack + Modal |
| Web | Flutter Web | — | Web pública / panel admin |
| Backend | Firebase | — | Serverless exclusivo |
| Base de datos | Cloud Firestore | — | NoSQL documental |
| Autenticación | Firebase Auth | — | Email magic link + Google |
| Funciones | Cloud Functions for Firebase | Node 20 + TS | Triggers + Scheduled jobs |
| Storage | Firebase Storage | — | Fotos de comercios y productos |
| Analytics | Firebase Analytics + Crashlytics | — | Base MVP |
| Mapas mobile | google_maps_flutter | — | Google Maps SDK |
| Mapas web | Google Maps Embed API | — | Solo embed en MVP |
| Tipos compartidos | TypeScript `/schema/types/` | TS 5.4 | Modelo canónico |

---

## 3. Ambientes

| Alias | Proyecto Firebase | Uso |
|-------|------------------|-----|
| `dev` | tum2-dev-6283d | Desarrollo local con emuladores |
| `staging` | tum2-staging-45c83 | QA y validación pre-lanzamiento |
| `prod` | tum2-prod-bc9b4 | Producción |

El proyecto soporta switching con `firebase use <alias>`.

`tum2-dev` (sin sufijo) se considera proyecto huérfano y no debe usarse.

Los emuladores locales cubren: Auth (9099), Firestore (8080), Storage (9199), Functions (5001), UI (4000).

---

## 4. Modelo de datos — Colecciones Firestore

### Colecciones principales

| Colección | Propósito | Acceso público |
|-----------|-----------|---------------|
| `users/{userId}` | Documento de usuario con rol y estado | Solo propio |
| `zones/{zoneId}` | Barrios/zonas con métricas de cobertura | ✅ |
| `merchants/{merchantId}` | Entidad canónica de comercio (source of truth) | Solo visible+active |
| `merchant_public/{merchantId}` | Proyección read-optimized (escrita por Cloud Functions) | ✅ |
| `merchant_schedules/{merchantId}` | Horarios operativos por día | ✅ |
| `merchant_operational_signals/{merchantId}` | Estado operativo en tiempo real | ✅ |
| `merchant_products/{productId}` | Productos del comercio | Solo visibles |
| `pharmacy_duties/{dutyId}` | Turnos de guardia de farmacias | Solo publicados |
| `merchant_claims/{claimId}` | Solicitudes de claim de comercio | Solo propio |
| `reports/{reportId}` | Reportes de usuarios | Solo admin |
| `external_places/{externalPlaceDocId}` | Datos crudos de Google Places | Solo admin |
| `import_batches/{batchId}` | Auditoría de importaciones | Solo admin |
| `admin_configs/global` | Configuración global y feature flags | Solo admin |

### Patrón de doble colección (merchants / merchant_public)

La decisión arquitectural más importante del sistema es la separación entre `merchants` (fuente de verdad, normalizada) y `merchant_public` (proyección denormalizada, optimizada para lectura pública).

```
merchants/{id}          →  Cloud Function trigger  →  merchant_public/{id}
(escribe: owner/admin)                                (lee: todos)
```

**Por qué:** Las queries de descubrimiento (home feed, búsqueda, abierto ahora) necesitan campos derivados (`isOpenNow`, `sortBoost`, `badges`) que no pueden calcularse en cliente sin múltiples colecciones. La proyección pública los tiene pre-calculados y es de solo lectura para clientes.

**Importante:** `merchant_public` nunca se escribe directamente desde cliente. Solo Cloud Functions tienen permiso.

---

## 5. Modelo de estados de comercio (3 ejes)

Cada documento `merchants/{id}` tiene tres ejes de estado independientes:

```
status               visibilityStatus        verificationStatus
─────────────────    ────────────────────    ──────────────────────────
draft                hidden                  unverified
active               review_pending          referential
inactive             visible                 community_submitted
archived             suppressed              claimed
                                             validated
                                             verified
```

**Regla de visibilidad pública:** un comercio aparece en `merchant_public` solo si:
- `status = 'active'`
- `visibilityStatus = 'visible'`
- Tiene nombre, categoría, zona y ubicación

**sortBoost por nivel de verificación:**
| Nivel | Boost |
|-------|-------|
| verified | 100 |
| validated | 90 |
| claimed | 80 |
| referential | 70 |
| community_submitted | 40 |
| unverified | 20 |

---

## 6. Cloud Functions

### Arquitectura de funciones

```
functions/src/
├── index.ts              — Exports centralizados
├── callables/            — Mutaciones sensibles por HTTPS callable
│   ├── pharmacyDuties.ts        — upsert/status con ownership + conflicto + App Check
│   ├── onboardingOwnerSubmit.ts
│   ├── checkMerchantDuplicates.ts
│   └── assignOwnerRole.ts
├── triggers/             — Reaccionan a escrituras en Firestore
│   ├── merchants.ts      — Sync merchants → merchant_public
│   ├── schedules.ts      — Recalcular isOpenNow en cambio de horario
│   ├── signals.ts        — Sync señales operativas a merchant_public
│   ├── duties.ts         — Sync turno de farmacia → hasPharmacyDutyToday
│   ├── claims.ts         — Promover a 'claimed' al aprobar claim
│   ├── reports.ts        — Suprimir comercio si supera umbral de reportes
│   └── externalPlaces.ts — Normalizar datos de Google Places al ingestar
├── jobs/                 — Tareas programadas y callables admin
│   ├── refreshOpenStatuses.ts  — Nightly: recalcula isOpenNow en todos
│   ├── refreshDuties.ts        — Nightly: actualiza hasPharmacyDutyToday
│   └── bootstrap.ts            — Callable admin: seed de zona desde Google Places
├── coverage/             — Métricas de cobertura por zona
│   └── zoneCoverage.ts
├── admin/                — Callables de administración
│   └── rebuildPublic.ts  — Reconstruir todas las proyecciones merchant_public
└── lib/                  — Utilidades internas
    ├── projection.ts     — computeSortBoost(), computeMerchantPublicProjection()
    ├── schedules.ts      — Parsing de horarios, isOpenNow
    ├── normalizeCategory.ts
    ├── dedupe.ts         — Detección de duplicados en seeds externos
    ├── scoring.ts        — Confidence scoring para datos externos
    └── types.ts          — Type aliases internos
```

### Campos derivados clave

| Campo | Colección | Quién lo calcula | Cuándo |
|-------|-----------|-----------------|--------|
| `isOpenNow` | merchant_public | schedules.ts trigger + nightly job | Cambio de horario / señal / cada noche |
| `hasPharmacyDutyToday` | merchant_public | duties.ts trigger + nightly job | Cambio de turno / cada noche |
| `sortBoost` | merchant_public | projection.ts | Cambio de verificación |
| `badges` | merchant_public | projection.ts | Cambio de datos del comercio |
| `searchKeywords` | merchant_public | projection.ts | Cambio de nombre/categoría |

---

## 7. Seguridad — Firestore Rules

Las reglas siguen el principio de **mínimo privilegio**:

| Colección | Lectura pública | Owner escribe | Admin escribe |
|-----------|----------------|--------------|--------------|
| `users` | Solo propio | Solo propio (no cambia rol) | ✅ |
| `zones` | ✅ | — | ✅ |
| `merchants` | Solo visible+active | Solo su comercio | ✅ |
| `merchant_public` | ✅ | ❌ (solo CF) | ❌ (solo CF) |
| `merchant_schedules` | ✅ | Solo su comercio | ✅ |
| `merchant_operational_signals` | ✅ | Solo su comercio | ✅ |
| `merchant_products` | Solo visibles | Solo su comercio | ✅ |
| `pharmacy_duties` | Solo publicados | ❌ (vía callable) | ✅ |
| `external_places` | ❌ | ❌ | ✅ |
| `import_batches` | ❌ | ❌ | ✅ |
| `merchant_claims` | Solo propio | Crear (propio) | ✅ |
| `reports` | ❌ | Crear | ✅ |
| `admin_configs` | Solo admin | ❌ | Solo super_admin |

**Custom claims de Firebase Auth:**
- `role: 'customer' | 'owner_pending' | 'owner' | 'admin' | 'super_admin'`
- Los claims se validan en reglas y en el backend. Nunca se confía solo en el cliente.
- `owner_pending` tiene los mismos permisos que `owner` en Firestore Rules, pero el comercio asociado tiene `visibilityStatus = review_pending` (no visible al público).

---

## 8. Autenticación y roles

> Especificación completa en `docs/SEGMENTS.md` (TuM2-0004).

```
Firebase Auth (idToken)
└── custom claim: role
    ├── customer       → AppNavigator + CustomerTabs
    ├── owner_pending  → AppNavigator + CustomerTabs + OwnerStack modal (modo revisión)
    ├── owner          → AppNavigator + CustomerTabs + OwnerStack modal (operativo)
    ├── admin          → AppNavigator + CustomerTabs + AdminStack modal
    └── super_admin    → Admin + acceso R+W a admin_configs/global
```

### Ciclo de vida de custom claims

```
Registro
  └─→ role = "customer"
        │
        ├─ Submit onboarding de comercio
        │     └─→ role = "owner_pending"
        │               │
        │     ADMIN aprueba ──→ role = "owner"
        │               │
        │     ADMIN rechaza ──→ role = "customer" (revertido)
        │
        └─ Asignación manual (Firebase Console / CF restringida)
              └─→ role = "admin" | "super_admin"
```

### Reglas de seguridad críticas

- **Custom claims solo modificables desde Admin SDK en Cloud Functions.** El cliente nunca puede escribir su propio claim.
- **El cliente decodifica el `idToken` solo para routing de navegación.** La autorización real se valida en Firestore Rules y en el cuerpo de cada Cloud Function.
- **Token refresh obligatorio antes de llamadas sensibles.** Implementar middleware de refresh del `idToken` en el repositorio de auth del mobile para evitar claims expirados durante sesión activa.
- **`owner_pending`** es un estado transitorio. El comercio tiene `visibilityStatus = review_pending` y no es visible al público hasta aprobación del ADMIN.

### Guard de navegación por rol

| Rol | Acceso |
|-----|--------|
| Sin sesión | AuthStack únicamente |
| `customer` | CustomerTabs · botón "Ir a mi comercio" oculto |
| `owner_pending` | CustomerTabs + OwnerStack modal (modo revisión) |
| `owner` | CustomerTabs + OwnerStack modal (operativo) |
| `admin` / `super_admin` | CustomerTabs + AdminStack modal + ruta `/admin` |

---

## 9. Bootstrap de datos — Google Places

La estrategia de cobertura inicial usa Google Places como fuente semilla controlada:

```
Admin dispara runZoneBootstrapBatch(zoneId, maxResults)
  ↓
Google Places API (búsqueda por zona + tipo de negocio)
  ↓
external_places/{id}  (datos crudos, solo admin)
  ↓
onExternalPlaceCreateNormalize (Cloud Function trigger)
  ↓
normalización + scoring de confianza + detección de duplicados
  ↓
Si confianza >= umbral → merchants/{id} con status='active', verificationStatus='referential'
Si confianza < umbral → external_places queda en review_pending para revisión admin
```

**Guardrails:**
- `maxResults` ≤ 50 por batch.
- Cada batch se registra en `import_batches` con trazabilidad completa.
- Los comercios creados desde Google Places tienen `sourceType: 'external_seed'` y son `isClaimable: true`.
- No se crean registros duplicados (deduplicación por nombre normalizado + geohash).

---

## 10. Navegación mobile (arquitectura)

Ver `docs/NAVIGATION.md` para el detalle completo.

Resumen:
```
Root Navigator
├── AuthStack (sin sesión) — Splash, Onboarding, Login, EmailVerification
└── AppNavigator (con sesión)
    ├── CustomerTabs (tab bar) — Inicio, Buscar, Perfil
    ├── OwnerStack (modal) — Panel, Perfil, Productos, Horarios, Turnos
    ├── AdminStack (modal) — Panel, Comercios, Detalle, Señales
    └── SharedScreens — FichaComercio (push), FichaProducto (bottom sheet)
```

---

## 11. Índices Firestore

Los índices compuestos más críticos para el MVP:

| Query | Índice |
|-------|--------|
| Home feed por zona | `merchant_public: zoneId ASC + visibilityStatus ASC + sortBoost DESC` |
| Abierto ahora | `merchant_public: zoneId ASC + visibilityStatus ASC + isOpenNow ASC` |
| Por categoría | `merchant_public: zoneId ASC + visibilityStatus ASC + categoryId ASC` |
| Farmacias de turno | `merchant_public: zoneId ASC + hasPharmacyDutyToday ASC + visibilityStatus ASC` |
| Turnos por zona/fecha | `pharmacy_duties: zoneId ASC + date ASC + status ASC` |
| Productos de comercio | `merchant_products: merchantId ASC + visibilityStatus ASC` |

Ver `firestore.indexes.json` para la definición completa (18 índices compuestos).

---

## 12. Tipos compartidos

El directorio `/schema/types/` define los contratos de datos en TypeScript, compartidos entre funciones, app mobile y web:

```
schema/types/
├── index.ts                        — Barrel export
├── user.ts                         — UserDocument, UserRole, UserStatus
├── zone.ts                         — ZoneDocument, ZoneCoverageMetrics
├── merchant.ts                     — MerchantDocument y tipos de estado
├── merchant_public.ts              — MerchantPublicDocument, MerchantBadge
├── merchant_schedules.ts           — WeeklySchedule, ScheduleSlot, ScheduleException
├── merchant_operational_signals.ts — OperationalSignals, DerivedSignals
├── merchant_products.ts            — ProductDocument y tipos de estado
├── pharmacy_duties.ts              — PharmacyDutyDocument y tipos
├── external_places.ts              — ExternalPlaceDocument (solo admin)
├── import_batches.ts               — ImportBatchDocument
├── merchant_claims.ts              — MerchantClaimDocument
├── reports.ts                      — ReportDocument, ReportType
└── admin_configs.ts                — AdminConfigDocument, FeatureFlags
```

---

## 13. Decisiones de arquitectura tomadas

| Decisión | Alternativas consideradas | Razón |
|----------|--------------------------|-------|
| Firebase como backend único | Self-hosted backend (NestJS + PostgreSQL) | Velocidad de desarrollo, realtime out-of-the-box, sin infraestructura que mantener |
| merchant_public como proyección separada | Leer desde merchants directamente | Performance: queries de descubrimiento con campos derivados sin joins client-side |
| Expo (managed workflow) | Bare RN | Velocidad de setup, OTA updates, EAS Build |
| Client-side text search en MVP | Algolia / Typesense | Costo cero en MVP; se puede migrar cuando el volumen lo justifique |
| No hay ratings / reviews | Sistema de reputación | Complejidad de moderación vs. valor en MVP; se evalúa para Post-MVP (0119) |
| sortBoost por verificación | Algoritmo de ranking complejo | Transparencia, predictibilidad, fácil de ajustar |
| Separación 3 ejes de estado (status/visibility/verification) | Estado único | Permite combinaciones que reflejan estados reales del negocio sin ambigüedad |

---

*Documento para TuM2-0007. Ver PRD-MVP.md para el alcance funcional y SCREENS-MAP.md para el diseño de pantallas.*
