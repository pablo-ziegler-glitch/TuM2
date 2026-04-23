# TuM2 — ÉPICA 20: Optimización estructural de costo, lecturas y serving

## Qué incluye este paquete

Este paquete contiene la expansión completa en Markdown de la nueva épica transversal de costo para TuM2 y sus tarjetas hijas:

- TuM2-0135 — Épica transversal de costo/performance del MVP
- TuM2-0136 — Catálogos estáticos versionados y serving barato
- TuM2-0137 — Framework de cache y `CachePolicy` canónica en Flutter
- TuM2-0138 — Optimización de corpus público de búsqueda por zona
- TuM2-0139 — Optimización de datasets diarios y semi-estáticos
- TuM2-0140 — Hardening de Auth/Rules con JWT claims y eliminación de reads extra
- TuM2-0141 — Hardening de queries admin: paginación, filtros obligatorios y refresh manual
- TuM2-0142 — Reducción de write amplification en triggers y proyecciones públicas
- TuM2-0143 — Escalado de jobs programados y recomputes operativos
- TuM2-0144 — App Check, rate limiting y protección anti-abuso orientada a costo
- TuM2-0145 — Observabilidad, budgets y telemetría de consumo por feature
- TuM2-0146 — Performance contract y QA de costo del MVP

## Decisiones cerradas usadas para esta expansión

- Presupuesto objetivo MVP: **USD 50/mes**, con tolerancia de estiramiento hasta **USD 70/mes**.
- Estrategia prioritaria: **ahorro extremo primero**, sin romper UX crítica ni seguridad.
- `zones` se resuelve con modelo **versionado/publicado**, no editable hot-path desde cliente.
- Se acepta una política de **datos parcialmente frescos** cuando el beneficio en costo sea alto y el impacto de negocio sea bajo o moderado.
- El stack se mantiene dentro del ecosistema canónico TuM2:
  - Flutter Mobile
  - Flutter Web pública
  - Flutter Web Admin
  - Firebase Auth
  - Firestore
  - Cloud Functions TypeScript
  - Firebase Hosting
  - Remote Config
  - App Check
  - Analytics / Crashlytics

## Explicación simple de "dato stale"

"Dato stale" significa: **dato que no es en vivo, sino que puede tener algunos minutos de antigüedad**.

Ejemplos simples:

- `zones`: puede estar desactualizado días o semanas sin problema grave.
- búsqueda pública por zona: puede tener 10 minutos de antigüedad sin romper el MVP.
- "abierto ahora": tolera menos; se recomienda unos 3 minutos o refresh manual.
- rol/permisos/claims: no toleran cache vieja larga; ahí se necesita refresh controlado y token refresh.

## Política recomendada de frescura por dominio

- `zones`, taxonomías, catálogos: **por versión**, sin realtime.
- search corpus por `zoneId`: **TTL 10 min**.
- "Abierto ahora": **TTL 3 min**.
- farmacias de turno del día: **TTL 10 min**.
- admin listados: **refresh manual** y opcional auto-refresh **60 s** solo cuando la vista está activa.
- claim del usuario: **refresh por foco/acción**, no listener continuo por defecto.
- permisos/roles: **JWT claims + forceRefresh** en hitos críticos.

## Principio rector

**No usar snapshots como patrón por defecto.**  
Se reservan solo para documentos o queries muy chicas donde el valor del tiempo real supere claramente el costo operativo y la complejidad.

## Orden recomendado de ejecución

### Ola 1 — ahorro inmediato
1. TuM2-0136
2. TuM2-0140
3. TuM2-0137
4. TuM2-0141

### Ola 2 — impacto directo en tráfico real
5. TuM2-0138
6. TuM2-0139
7. TuM2-0142

### Ola 3 — blindaje de escala
8. TuM2-0143
9. TuM2-0144
10. TuM2-0145
11. TuM2-0146
