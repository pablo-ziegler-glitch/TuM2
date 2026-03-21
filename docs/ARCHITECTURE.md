# TuM2 — Arquitectura del producto
### Tarjeta: TuM2-0007

**Producto:** TuM2
**Lectura de marca:** Tu metro cuadrado
**Estudio desarrollador:** Floki

---

## 1. Objetivo arquitectónico

Construir una plataforma mobile + web para TuM2 que soporte desde el MVP:

- Directorio de comercios
- Catálogo público
- Señales operativas
- Farmacias de turno
- Comunidad segmentada
- Una capa de branding clara y desacoplada del core UX
- Un fuerte componente de cercanía geográfica

La arquitectura debe preservar:

| Principio | Descripción |
|-----------|-------------|
| Claridad | Estructura de código y datos legible y navegable |
| Rapidez de desarrollo | Bajo tiempo de setup, iteración fluida |
| Bajo costo inicial | Firebase como BaaS, sin infra propia en MVP |
| Seguridad | Firestore Rules + App Check + roles por claims |
| Escalabilidad progresiva | Agnóstico a la carga; Cloud Functions + agregados |
| Consistencia de proximidad | La geolocalización es componente central, no accesorio |

---

## 2. Principio UX-arquitectónico

**La identidad de marca no debe estar hardcodeada en navegación crítica.**

Debe desacoplarse en módulos versionables:

- Catálogo de microcopies
- Templates de notificación
- Onboarding content
- Badges y sellos
- Mensajes de estado
- Sistema de rangos

Esto permite:
- Iterar tono sin romper flows
- Mantener claridad funcional
- Probar variantes de copy (A/B)

---

## 3. Stack propuesto

### Frontend

| Plataforma | Tecnología |
|------------|-----------|
| Mobile (iOS + Android) | Flutter |
| Web pública | Flutter Web o web dedicada |
| Panel admin | Web restringida (Flutter Web o lightweight framework) |

### Backend

| Servicio | Uso |
|----------|-----|
| Firebase Auth | Autenticación, roles via custom claims |
| Firestore | Base de datos principal (NoSQL, tiempo real) |
| Cloud Functions | Lógica server-side, derivaciones, TTL, triggers |
| Storage | Imágenes de comercios y productos |
| Firebase Hosting / App Hosting | Deploy web pública y panel admin |
| FCM | Push notifications |
| Analytics | Eventos de uso y activación |
| Crashlytics | Monitoreo de errores en producción |
| Remote Config | Feature flags y variantes de copy |
| App Check | Protección de endpoints contra tráfico no autorizado |

---

## 4. Dominios principales

### User
```
id
email
displayName
roleType           // customer | owner | admin
currentRank        // opcional
xpPoints           // opcional
status
createdAt
```

### Store
```
id
ownerId
name
slug
category
description
imageUrl
address
geo                // lat, lng, geohash
neighborhood       // opcional
locality           // opcional
visibilityStatus   // hidden | review_pending | visible | suppressed
createdAt
updatedAt
```

### Product
```
id
storeId
name
description
price
stockStatus
imageUrls
isVisible
updatedAt
```

### StoreSchedule
```
storeId
timezone
weeklySchedule     // { lun: { open, close }, ... }
updatedAt
```

### OperationalSignal
```
id
storeId
signalType
status
notes
sourceType
confidenceLevel
updatedAt
```

### DutySchedule
```
id
storeId
date
startTime
endTime
status
notes
sourceType
updatedAt
```

### Proposal
```
id
segment
createdBy
title
description
status
voteCount
shareSlug
moderationStatus
createdAt
```

### Vote
```
proposalId
userId
segment
voteType
createdAt
```

### BrandingSnippet
```
id
contextType
segment
tone
text
active
version
```

### BadgeDefinition
```
id
key
label
description
visualStyle
active
```

---

## 5. Arquitectura del módulo geográfico

TuM2 trata la geolocalización como componente central, no accesorio.

**Requisitos:**
- Ubicación del comercio
- Zona / localidad
- Consultas por cercanía
- Filtros "cerca mío"
- Segmentación por radio o área
- Posibilidad futura de vista barrial o por cuadrícula/zona

**Campos mínimos en Store:**
```
lat
lng
locality
neighborhood    // opcional
geohash         // estructura equivalente para queries rápidas
```

**Estrategia de consulta:**
Las queries de proximidad en Firestore se resuelven con geohash (Geohash range query). Los campos `lat`/`lng` se usan para cálculo preciso de distancia en el cliente o en Cloud Functions.

---

## 6. Arquitectura del módulo operativo

La capa operativa se resuelve con tres niveles:

| Nivel | Qué contiene | Modelo |
|-------|-------------|--------|
| **1 — Horario base** | Días de apertura, bloques horarios, timezone, horarios estándar | `StoreSchedule` |
| **2 — Señales operativas explícitas** | 24 hs, hasta tarde, horario especial, servicio especial, delivery nocturno, otras señales no derivables automáticamente | `OperationalSignal` |
| **3 — Calendario operativo programado** | Turnos, guardias, calendario mensual, farmacias de turno, estados `programado / confirmado / modificado` | `DutySchedule` |

---

## 7. Derivaciones automáticas

El backend calcula campos derivados para consulta rápida. Se materializan en documentos agregados para acelerar listados.

| Campo derivado | Descripción |
|----------------|-------------|
| `isOpenNow` | Calculado desde `StoreSchedule` + timezone actual |
| `isLateNightNow` | Señal de horario extendido activa en este momento |
| `isOnDutyToday` | `DutySchedule` activo para la fecha de hoy |
| `hasActiveSpecialSignal` | Al menos una `OperationalSignal` activa |
| `operationalFreshnessHours` | Horas desde la última actualización operativa |
| `operationalDataCompletenessScore` | Score 0–100 de completitud del perfil operativo |
| `distanceBucket` | `< 200m / 200-500m / 500m-1km / > 1km` (opcional, futuro) |
| `nearUserZone` | Bandera booleana derivada de zona del usuario (opcional, futuro) |

---

## 8. Módulos frontend

### Core (todos los usuarios)
- Navegación estándar
- Sesión (auth)
- Theming (`AppColors`, `AppTextStyles`)
- Analytics
- Remote Config

### Owner module
- Gestión de comercio (nombre, categoría, dirección, imágenes)
- Productos (alta, edición, stock)
- Horarios semanales
- Señales operativas
- Calendario de turnos

### Customer module
- Buscar (texto + filtros)
- Mapa
- Categorías
- Perfil + favoritos
- Abierto ahora
- Farmacias de turno
- Detalle de comercio
- Detalle de producto
- Cerca mío

### Brand layer (desacoplado del UX core)
- Onboarding TuM2
- Badges y sellos
- Loading copy
- Notificaciones
- Estados narrativos (mensajes de éxito, error, vacío)

---

## 9. Reglas de arquitectura narrativa

1. Toda pantalla crítica debe tener copy claro y directo.
2. La marca debe sentirse cercana y útil — nunca invasiva en tareas críticas.
3. Mensajes de error severos deben priorizar claridad sobre tono.
4. La navegación principal debe seguir naming estándar (sin naming de marca en rutas).
5. Los templates de copy deben poder versionarse (`BrandingSnippet.version`).
6. La filosofía de cercanía debe aparecer en momentos de descubrimiento, no en flows de gestión.

---

## 10. Principio rector

> **TuM2 debe sentirse cercana en marca y precisa en uso.**
>
> La arquitectura debe sostener la idea de "tu entorno comercial inmediato" como núcleo del producto — tanto en la experiencia del vecino que busca un comercio, como en la del dueño que lo gestiona.

---

## 11. Documentos relacionados

| Documento | Contenido |
|-----------|-----------|
| `docs/NAVIGATION.md` | Estructura de navegación Flutter, stacks, guards |
| `docs/SCREENS-MAP.md` | Mapa completo de pantallas por segmento |
| `docs/QUERY-ARCHITECTURE.md` | Estrategia de consultas Firestore y agregados |
| `schema/README.md` | Esquemas Firestore detallados |
| `design/tokens.json` | Tokens de color del sistema de diseño |
| `docs/ONBOARDING-OWNER-FSM.md` | FSM del flujo de registro de comercio |
| `docs/ONBOARDING-OWNER-EXCEPTIONS.md` | Estados de excepción del onboarding OWNER |

---

*Documento mantenido bajo TuM2-0007. Actualizar ante cambios de stack, incorporación de nuevos dominios o cambios en principios arquitectónicos.*
