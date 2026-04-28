# TuM2 — Inventario anti-mock de pantallas y funcionalidades

Estado: ACTIVO  
Owner operativo: Producto + UX + Tech Lead  
Uso principal: evitar cierre falso de tarjetas con pantallas mock, datos hardcodeados o flujos simulados.  
Relación con agentes: este archivo debe ser consultado por Codex, Claude Code y cualquier agente antes de implementar, cerrar o generar pantallas con Stitch.

---

## 1. Objetivo

Mantener un inventario vivo de pantallas, módulos y funcionalidades de TuM2 que permita saber:

- qué pantallas existen o faltan por diseñar;
- qué pantallas están implementadas con datos reales;
- qué pantallas todavía dependen de backend, reglas, Cloud Functions, índices o datos productivos;
- qué pantallas no deben considerarse DONE si usan mocks, fakes, stubs, seeds de demo o listas hardcodeadas;
- qué funcionalidades están listas para pedir pantallas a Stitch;
- qué funcionalidades están listas para implementación con Codex.

Este archivo complementa la regla anti-mock del proyecto. Una pantalla visualmente terminada no se considera completa si no está conectada al modelo real correspondiente.

---

## 2. Regla anti-mock aplicable

Para cualquier tarjeta marcada como DONE o implementada:

- no se aceptan mocks como sustituto de integración real;
- no se aceptan fakes ni stubs en código productivo;
- no se aceptan datos hardcodeados de demo;
- no se aceptan listados locales cuando exista colección real;
- no se aceptan pantallas cerradas sin estados de loading, empty, error y permission denied cuando aplique;
- no se acepta marcar como DONE una funcionalidad que todavía requiere backend real, reglas Firestore, índice, Cloud Function o data contract pendiente.

Excepción válida:

- Los tests unitarios, widget tests o tests de integración pueden usar mocks controlados, siempre que no formen parte de la implementación productiva.

---

## 3. Estados canónicos del inventario

| Estado | Significado | Puede cerrarse tarjeta |
|---|---|---|
| `not_started` | No diseñado ni implementado | No |
| `needs_stitch` | Requiere diseño visual/pantallas en Stitch | No |
| `stitch_ready` | Tiene suficiente contexto para pedir pantallas a Stitch | No |
| `designed` | Diseño validado, pero no implementado | No |
| `implementation_ready` | Diseño + contrato técnico definidos | No |
| `in_progress` | Implementación en curso | No |
| `real_data_partial` | Integrado parcialmente con backend real; quedan mocks/fallbacks no productivos | No |
| `blocked_backend` | UI depende de backend/reglas/functions/index/data pendiente | No |
| `blocked_product` | Falta definición funcional o legal | No |
| `qa_required` | Implementado, requiere validación QA/security/cost | No |
| `done_real_data` | Implementado con datos reales, sin mocks productivos, con QA mínimo | Sí |
| `post_mvp` | Fuera de MVP | No aplica |

---

## 4. Campos obligatorios por pantalla o funcionalidad

Cada entrada debe mantener este formato:

```md
### SCREEN-ID — Nombre funcional

- Tarjeta vinculada: TuM2-XXXX
- Plataforma: Mobile / Web pública / Admin Web / Cross-platform
- Estado inventario: `needs_stitch | implementation_ready | done_real_data | ...`
- Descripción: ...
- Usuario objetivo: CUSTOMER / OWNER / ADMIN / Anónimo
- Datos reales requeridos:
  - colección/documento/callable/API
- Prohibido simular con mock:
  - ...
- Estados UX obligatorios:
  - loading
  - empty
  - error
  - permission denied
  - offline/fallback si aplica
- Dependencias técnicas:
  - Firestore Rules
  - Cloud Functions
  - índices
  - Remote Config
  - Analytics
- Riesgo anti-mock:
  - bajo / medio / alto / crítico
- Listo para Stitch: sí/no
- Listo para Codex: sí/no
- Prompt Stitch requerido: sí/no
- Notas:
  - ...
```

---

## 5. Rubros MVP canónicos

Rubros incluidos en MVP:

- Farmacias
- Kioscos
- Almacenes
- Veterinarias
- Tiendas de comida al paso
- Casas de comida / Rotiserías
- Gomerías
- Panaderías
- Confiterías

Los agentes deben usar esta lista como fuente operativa para pantallas, prompts Stitch, seeds, filtros, tests, documentación, assets y analytics.

---

## 6. Inventario inicial — Mobile público / CUSTOMER

### AUTH-01 — Splash / Loading

- Tarjeta vinculada: TuM2-0054
- Plataforma: Mobile
- Estado inventario: `done_real_data`
- Descripción: pantalla inicial de carga, resolución de sesión, rol efectivo, claims y navegación guest-first.
- Usuario objetivo: Anónimo / CUSTOMER / OWNER / ADMIN
- Datos reales requeridos:
  - Firebase Auth
  - custom claims
  - estado local de sesión
  - Remote Config cuando aplique
- Prohibido simular con mock:
  - rol de usuario
  - estado `owner_pending`
  - token refresh
- Estados UX obligatorios:
  - loading
  - error recuperable
  - fallback guest
- Dependencias técnicas:
  - Firebase Auth
  - Riverpod invalidation
  - go_router guards
- Riesgo anti-mock: medio
- Listo para Stitch: no
- Listo para Codex: no
- Prompt Stitch requerido: no
- Notas:
  - Debe preservar estrategia guest-first.

### AUTH-02 — Onboarding CUSTOMER

- Tarjeta vinculada: TuM2-0029
- Plataforma: Mobile
- Estado inventario: `done_real_data`
- Descripción: onboarding inicial de tres slides, salteable desde el primer slide.
- Usuario objetivo: Anónimo / CUSTOMER
- Datos reales requeridos:
  - estado local de onboarding visto
- Prohibido simular con mock:
  - datos backend inexistentes o copy no aprobado.
- Estados UX obligatorios:
  - primera apertura
  - omitido
  - completado
- Dependencias técnicas:
  - SharedPreferences o storage local equivalente
  - navegación post-onboarding
- Riesgo anti-mock: bajo
- Listo para Stitch: no
- Listo para Codex: no
- Prompt Stitch requerido: no
- Notas:
  - No debe bloquear tiempo al primer resultado útil.

### AUTH-03 — Login / Registro unificado

- Tarjeta vinculada: TuM2-0054
- Plataforma: Mobile
- Estado inventario: `done_real_data`
- Descripción: login y registro con magic link/email y Google Sign-In.
- Usuario objetivo: CUSTOMER / OWNER potencial
- Datos reales requeridos:
  - Firebase Auth
  - deep links / app links
  - custom claims post-login
- Prohibido simular con mock:
  - sesión autenticada
  - provider de login
  - claim/rol efectivo
- Estados UX obligatorios:
  - idle
  - enviando link
  - link enviado
  - error
  - usuario autenticado
- Dependencias técnicas:
  - Firebase Auth
  - go_router
  - Riverpod
- Riesgo anti-mock: alto
- Listo para Stitch: no
- Listo para Codex: no
- Prompt Stitch requerido: no
- Notas:
  - Claim email debe derivar del email autenticado.

### HOME-01 — Home CUSTOMER

- Tarjeta vinculada: TuM2-0055
- Plataforma: Mobile
- Estado inventario: `implementation_ready`
- Descripción: home pública orientada a resultado útil rápido: comercios cercanos, abiertos ahora y accesos a farmacias de turno.
- Usuario objetivo: Anónimo / CUSTOMER
- Datos reales requeridos:
  - `merchant_public`
  - `zones`
  - `pharmacy_duties`
  - ubicación del usuario si autoriza
- Prohibido simular con mock:
  - comercios destacados
  - farmacias de turno
  - señales operativas
  - zona activa
- Estados UX obligatorios:
  - loading inicial
  - sin zona
  - sin ubicación
  - resultados
  - vacío por zona
  - error de red
- Dependencias técnicas:
  - queries por `zoneId` + `visibilityStatus`
  - limits obligatorios
  - cache TTL de zona
  - analytics de acción útil
- Riesgo anti-mock: alto
- Listo para Stitch: sí
- Listo para Codex: sí
- Prompt Stitch requerido: opcional
- Notas:
  - Prioridad UX: acceso a búsqueda, abierto ahora y farmacias de turno.

### SEARCH-01 — Buscar / Estado inicial

- Tarjeta vinculada: TuM2-0031 / TuM2-0056
- Plataforma: Mobile
- Estado inventario: `done_real_data`
- Descripción: entrada principal de búsqueda de comercios por zona.
- Usuario objetivo: Anónimo / CUSTOMER
- Datos reales requeridos:
  - `merchant_public`
  - `zones`
  - `searchKeywords`
- Prohibido simular con mock:
  - resultados
  - barrios hardcodeados
  - categorías fuera de configuración MVP vigente
- Estados UX obligatorios:
  - inicial
  - focus
  - typing
  - resultados
  - vacío
  - error
- Dependencias técnicas:
  - `search_real_data_enabled`
  - corpus por `zoneId` máximo 200 docs
  - filtrado local normalizado
- Riesgo anti-mock: medio
- Listo para Stitch: no
- Listo para Codex: no
- Prompt Stitch requerido: no
- Notas:
  - Mantener rubros alineados con la lista canónica vigente.

### SEARCH-03 — Mapa con pins

- Tarjeta vinculada: TuM2-0057
- Plataforma: Mobile
- Estado inventario: `done_real_data`
- Descripción: vista de mapa con markers por comercio, clustering y selección visual.
- Usuario objetivo: Anónimo / CUSTOMER
- Datos reales requeridos:
  - `merchant_public`
  - ubicación del usuario
  - coordenadas de comercios
- Prohibido simular con mock:
  - markers fake
  - lat/lng hardcodeadas
  - comercios demo
- Estados UX obligatorios:
  - loading map
  - sin permisos ubicación
  - sin resultados
  - error mapa
  - resultados clusterizados
- Dependencias técnicas:
  - Google Maps
  - cache de marker bitmaps
  - clustering por grilla
- Riesgo anti-mock: medio
- Listo para Stitch: no
- Listo para Codex: no
- Prompt Stitch requerido: no
- Notas:
  - Clusters raster PNG quedan fuera del sistema semántico de iconografía base.

### DETAIL-01 — Ficha pública de comercio

- Tarjeta vinculada: TuM2-0058
- Plataforma: Mobile
- Estado inventario: `done_real_data`
- Descripción: detalle de comercio con datos públicos, señales, contacto, mapa y badges.
- Usuario objetivo: Anónimo / CUSTOMER
- Datos reales requeridos:
  - `merchant_public/{merchantId}`
  - datos públicos derivados
- Prohibido simular con mock:
  - horarios
  - señal operativa
  - badge de verificación
  - guardia activa
- Estados UX obligatorios:
  - loading
  - comercio no encontrado
  - comercio oculto/suprimido
  - error
- Dependencias técnicas:
  - dual collection
  - proyección pública server-side
  - deep links
- Riesgo anti-mock: alto
- Listo para Stitch: no
- Listo para Codex: no
- Prompt Stitch requerido: no
- Notas:
  - No leer `merchants` privado desde vista pública.

### HOME-02 — Abierto ahora

- Tarjeta vinculada: TuM2-0060
- Plataforma: Mobile
- Estado inventario: `done_real_data`
- Descripción: vista pública de comercios abiertos ahora por zona y rubro MVP.
- Usuario objetivo: Anónimo / CUSTOMER
- Datos reales requeridos:
  - `merchant_public`
  - `isOpenNow`
  - `zoneId`
  - `visibilityStatus`
- Prohibido simular con mock:
  - estado abierto/cerrado
  - rubros fuera de configuración MVP vigente
- Estados UX obligatorios:
  - loading
  - vacío
  - sin zona
  - error
- Dependencias técnicas:
  - índice `zoneId + visibilityStatus + isOpenNow`
  - cálculo server-side de `isOpenNow`
- Riesgo anti-mock: alto
- Listo para Stitch: no
- Listo para Codex: no
- Prompt Stitch requerido: no
- Notas:
  - No recalcular estado canónico en cliente como fuente de verdad.

### HOME-03 — Farmacias de turno

- Tarjeta vinculada: TuM2-0061
- Plataforma: Mobile
- Estado inventario: `done_real_data`
- Descripción: vista pública de farmacias de turno con detalle, distancia y disclaimers.
- Usuario objetivo: Anónimo / CUSTOMER
- Datos reales requeridos:
  - `pharmacy_duties`
  - `merchant_public`
  - `zoneId + date + status`
- Prohibido simular con mock:
  - guardias activas
  - horarios de turno
  - farmacias demo
- Estados UX obligatorios:
  - loading
  - sin ubicación
  - sin turnos publicados
  - error
  - detalle
- Dependencias técnicas:
  - índice `zoneId + date + status`
  - batch hydration
  - UTC-3 operativo
- Riesgo anti-mock: crítico
- Listo para Stitch: no
- Listo para Codex: no
- Prompt Stitch requerido: no
- Notas:
  - Información sensible por confianza pública; debe incluir disclaimer.

### PRODUCT-01 — Ficha pública de producto

- Tarjeta vinculada: TuM2-0034 / TuM2-0059
- Plataforma: Mobile
- Estado inventario: `needs_stitch`
- Descripción: ficha pública de producto simple dentro del comercio, orientada a disponibilidad y contacto, no compra transaccional.
- Usuario objetivo: Anónimo / CUSTOMER
- Datos reales requeridos:
  - `merchant_products`
  - `merchant_public/{merchantId}`
- Prohibido simular con mock:
  - productos demo
  - precios ficticios
  - stock no persistido
- Estados UX obligatorios:
  - loading
  - producto no disponible
  - comercio no visible
  - error
- Dependencias técnicas:
  - reglas de lectura pública para productos visibles
  - límites de catálogo por comercio
  - Storage para imágenes si aplica
- Riesgo anti-mock: alto
- Listo para Stitch: sí
- Listo para Codex: no
- Prompt Stitch requerido: sí
- Notas:
  - No implementar checkout ni marketplace en MVP.

---

## 7. Inventario inicial — OWNER Mobile

### OWNER-01 — Mi comercio / Home operativo

- Tarjeta vinculada: TuM2-0064
- Plataforma: Mobile
- Estado inventario: `in_progress`
- Descripción: pantalla principal del dueño para ver estado operativo, visibilidad, claim/rol efectivo y accesos rápidos a horarios, avisos, productos y turnos si corresponde.
- Usuario objetivo: OWNER / owner_pending
- Datos reales requeridos:
  - Firebase Auth custom claims
  - estado resumido de rol/claim
  - `merchants/{merchantId}` privado
  - `merchant_public/{merchantId}` público derivado
  - `merchant_claims` acotado por usuario/merchant si aplica
- Prohibido simular con mock:
  - estado OWNER
  - `owner_pending`
  - visibilidad pública
  - estado de claim
  - merchant principal
  - accesos habilitados
- Estados UX obligatorios:
  - loading
  - OWNER aprobado
  - owner_pending
  - claim needs_more_info
  - claim rejected
  - conflict_detected
  - sin comercio vinculado
  - permission denied
  - error de red
- Dependencias técnicas:
  - TuM2-0004 roles
  - TuM2-0053 shell
  - TuM2-0054 auth
  - TuM2-0126 claims
  - TuM2-0131 integración roles
  - cache TTL para estado de rol/claim
- Riesgo anti-mock: crítico
- Listo para Stitch: sí
- Listo para Codex: sí
- Prompt Stitch requerido: sí
- Notas:
  - Enviar claim no habilita OWNER pleno.
  - Si hay conflicto o duplicado, priorizar estado del claim sobre acciones operativas.

### OWNER-02 — Perfil básico del comercio

- Tarjeta vinculada: TuM2-0064 / TuM2-0081
- Plataforma: Mobile
- Estado inventario: `needs_stitch`
- Descripción: visualización/edición acotada de datos básicos del comercio según rol efectivo y estado de revisión.
- Usuario objetivo: OWNER / owner_pending
- Datos reales requeridos:
  - `merchants/{merchantId}`
  - `merchant_public/{merchantId}` derivado
  - estado de claim si aplica
- Prohibido simular con mock:
  - campos editables según rol
  - estado de revisión
  - datos privados del comercio
- Estados UX obligatorios:
  - loading
  - editable OWNER
  - solo lectura owner_pending
  - review_pending
  - suppressed
  - permission denied
  - error
- Dependencias técnicas:
  - Firestore Rules
  - Cloud Functions para proyección pública
  - whitelist de campos editables
- Riesgo anti-mock: alto
- Listo para Stitch: sí
- Listo para Codex: no
- Prompt Stitch requerido: sí
- Notas:
  - No permitir edición cliente de `verificationStatus`, `visibilityStatus`, `sourceType` ni derivados.

### OWNER-06 — Horarios

- Tarjeta vinculada: TuM2-0066
- Plataforma: Mobile
- Estado inventario: `done_real_data`
- Descripción: carga de horarios semanales, excepciones por fecha y cierres temporales por rango.
- Usuario objetivo: OWNER
- Datos reales requeridos:
  - `schedule_config/weekly`
  - `schedule_exceptions`
  - `schedule_exceptions_ranges`
  - triggers de recompute
- Prohibido simular con mock:
  - horarios activos
  - excepciones
  - preview derivado si no coincide con datos reales
- Estados UX obligatorios:
  - loading
  - sin horarios
  - editando
  - guardando
  - error validación
  - permission denied
  - error backend
- Dependencias técnicas:
  - feature flag `owner_schedule_editor_enabled`
  - triggers de recompute
  - analytics `owner_schedule_*`
- Riesgo anti-mock: alto
- Listo para Stitch: no
- Listo para Codex: no
- Prompt Stitch requerido: no
- Notas:
  - `isOpenNow` final no lo decide el cliente.

### OWNER-08 — Avisos de hoy / Señales operativas

- Tarjeta vinculada: TuM2-0067
- Plataforma: Mobile
- Estado inventario: `done_real_data`
- Descripción: carga y desactivación de señales operativas manuales: vacaciones, cierre temporal o demora.
- Usuario objetivo: OWNER
- Datos reales requeridos:
  - `merchant_operational_signals/{merchantId}`
  - trigger hacia `merchant_public/{merchantId}`
- Prohibido simular con mock:
  - señal activa
  - estado público derivado
  - override manual
- Estados UX obligatorios:
  - loading
  - sin señal activa
  - señal activa
  - guardando
  - success
  - permission denied
  - error
- Dependencias técnicas:
  - Firestore Rules owner/admin
  - Cloud Function `merchant_operational_signals -> merchant_public`
  - no-op write avoidance
- Riesgo anti-mock: alto
- Listo para Stitch: no
- Listo para Codex: no
- Prompt Stitch requerido: no
- Notas:
  - Cliente escribe solo `merchant_operational_signals`, nunca `merchant_public`.

### OWNER-09 — Calendario mensual de turnos farmacia

- Tarjeta vinculada: TuM2-0068
- Plataforma: Mobile
- Estado inventario: `done_real_data`
- Descripción: vista mensual para cargar, editar, borrar y publicar turnos de farmacia.
- Usuario objetivo: OWNER de farmacia
- Datos reales requeridos:
  - `pharmacy_duties`
  - `merchant_public` derivado
  - validaciones server-side
- Prohibido simular con mock:
  - turnos publicados
  - calendario de guardias
  - estado de publicación
- Estados UX obligatorios:
  - loading
  - calendario vacío
  - turnos cargados
  - publicación en curso
  - error validación
  - permission denied
- Dependencias técnicas:
  - callable o flujo server-side validado
  - índice `zoneId + date + status`
  - proyección pública por Cloud Functions
- Riesgo anti-mock: crítico
- Listo para Stitch: no
- Listo para Codex: no
- Prompt Stitch requerido: no
- Notas:
  - Solo aplica a farmacias habilitadas.

### OWNER-PRODUCTS-01 — Listado de productos

- Tarjeta vinculada: TuM2-0065
- Plataforma: Mobile
- Estado inventario: `needs_stitch`
- Descripción: listado de productos del comercio con estado visible/oculto, disponibilidad y capacidad usada.
- Usuario objetivo: OWNER
- Datos reales requeridos:
  - `merchant_products`
  - `admin_configs/catalog_limits`
  - callable de creación/edición si aplica
- Prohibido simular con mock:
  - productos
  - límites de catálogo
  - capacidad usada
  - estado de stock
- Estados UX obligatorios:
  - loading
  - empty
  - lista
  - límite alcanzado
  - permission denied
  - error
- Dependencias técnicas:
  - límites globales/categoría/override
  - cache TTL de capacidad
  - paginación si crece
- Riesgo anti-mock: alto
- Listo para Stitch: sí
- Listo para Codex: sí
- Prompt Stitch requerido: sí
- Notas:
  - No implementar marketplace ni compra online.

### OWNER-PRODUCTS-02 — Alta/edición de producto

- Tarjeta vinculada: TuM2-0065
- Plataforma: Mobile
- Estado inventario: `needs_stitch`
- Descripción: formulario simple para crear o editar producto visible en catálogo público.
- Usuario objetivo: OWNER
- Datos reales requeridos:
  - `merchant_products`
  - Storage para imagen si aplica
  - callable transaccional para capacidad
- Prohibido simular con mock:
  - guardado de producto
  - imagen persistida
  - límite de capacidad
- Estados UX obligatorios:
  - creando
  - editando
  - guardando
  - validación inline
  - límite alcanzado
  - error upload
  - permission denied
- Dependencias técnicas:
  - Storage Rules
  - Firestore Rules
  - callable de validación
  - analytics de bloqueo/cupo
- Riesgo anti-mock: alto
- Listo para Stitch: sí
- Listo para Codex: sí
- Prompt Stitch requerido: sí
- Notas:
  - Precio puede ser label simple; no checkout.

---

## 8. Inventario inicial — Claims de titularidad

### CLAIM-01 — Inicio de reclamo de comercio

- Tarjeta vinculada: TuM2-0126
- Plataforma: Mobile / Web pública
- Estado inventario: `needs_stitch`
- Descripción: entrada para que usuario autenticado reclame un comercio existente o identificable.
- Usuario objetivo: CUSTOMER
- Datos reales requeridos:
  - Firebase Auth
  - `merchant_public`
  - `merchant_claims`
- Prohibido simular con mock:
  - usuario autenticado
  - email del claim
  - comercio reclamado
- Estados UX obligatorios:
  - requiere login
  - comercio seleccionable
  - claim existente
  - error
- Dependencias técnicas:
  - auth real
  - claim email = email autenticado
  - reglas de duplicado
- Riesgo anti-mock: crítico
- Listo para Stitch: sí
- Listo para Codex: sí
- Prompt Stitch requerido: sí
- Notas:
  - No crear campo alternativo de email en MVP.

### CLAIM-02 — Formulario de evidencia

- Tarjeta vinculada: TuM2-0126 / TuM2-0129 / TuM2-0102
- Plataforma: Mobile / Web pública
- Estado inventario: `needs_stitch`
- Descripción: carga guiada de datos mínimos y evidencia según categoría.
- Usuario objetivo: CUSTOMER / owner claimant
- Datos reales requeridos:
  - `merchant_claims`
  - Storage seguro
  - reglas por categoría
  - consentimiento versionado
- Prohibido simular con mock:
  - evidencia
  - consentimiento
  - categoría regulada
- Estados UX obligatorios:
  - step incompleto
  - carga adjunto
  - error adjunto
  - consentimiento pendiente
  - listo para enviar
- Dependencias técnicas:
  - Storage Rules
  - cifrado/hash/fingerprint
  - consentimiento versionado
- Riesgo anti-mock: crítico
- Listo para Stitch: sí
- Listo para Codex: sí
- Prompt Stitch requerido: sí
- Notas:
  - Teléfono opcional en MVP, sin verificación.

### CLAIM-03 — Estado del claim

- Tarjeta vinculada: TuM2-0126 / TuM2-0131
- Plataforma: Mobile
- Estado inventario: `needs_stitch`
- Descripción: pantalla de seguimiento para `submitted`, `under_review`, `needs_more_info`, `approved`, `rejected`, `conflict_detected`, `duplicate_claim`.
- Usuario objetivo: owner_pending / CUSTOMER
- Datos reales requeridos:
  - `merchant_claims`
  - custom claims
  - estado resumido de rol/claim
- Prohibido simular con mock:
  - estado del claim
  - transición a OWNER
  - necesidades de información
- Estados UX obligatorios:
  - submitted
  - under_review
  - needs_more_info
  - approved
  - rejected
  - conflict_detected
  - duplicate_claim
  - error
- Dependencias técnicas:
  - cache TTL
  - refresh por foco/acción
  - sin polling corto
- Riesgo anti-mock: crítico
- Listo para Stitch: sí
- Listo para Codex: sí
- Prompt Stitch requerido: sí
- Notas:
  - Enviar claim no habilita OWNER completo.

---

## 9. Inventario inicial — Admin Web

### ADMIN-CLAIMS-01 — Listado de claims para revisión

- Tarjeta vinculada: TuM2-0128
- Plataforma: Admin Web
- Estado inventario: `needs_stitch`
- Descripción: tabla paginada de claims con filtros por estado, categoría, zona, riesgo y conflicto.
- Usuario objetivo: ADMIN
- Datos reales requeridos:
  - `merchant_claims`
  - índices por `status + zoneId`
  - metadata mínima de usuario/comercio
- Prohibido simular con mock:
  - claims
  - estado de riesgo
  - filtros
  - paginación
- Estados UX obligatorios:
  - loading
  - empty
  - resultados
  - error
  - permission denied
- Dependencias técnicas:
  - Firestore Rules admin
  - paginación por cursor
  - `limit`
  - no evidencia en listado
- Riesgo anti-mock: crítico
- Listo para Stitch: sí
- Listo para Codex: sí
- Prompt Stitch requerido: sí
- Notas:
  - Sensibles nunca completos en listado.

### ADMIN-CLAIMS-02 — Detalle y resolución de claim

- Tarjeta vinculada: TuM2-0128 / TuM2-0130 / TuM2-0133
- Plataforma: Admin Web
- Estado inventario: `needs_stitch`
- Descripción: vista detalle para comparar evidencia, comercio, timeline y resolver aprobar/rechazar/pedir info/marcar conflicto.
- Usuario objetivo: ADMIN
- Datos reales requeridos:
  - `merchant_claims/{claimId}`
  - Storage seguro
  - reveal auditado
  - callable de resolución
- Prohibido simular con mock:
  - evidencia
  - reveal de sensibles
  - resolución admin
  - transición de rol
- Estados UX obligatorios:
  - loading
  - detalle
  - reveal masked
  - reveal temporal activo
  - evidencia no disponible
  - aprobación en curso
  - conflicto
  - error
- Dependencias técnicas:
  - masking por defecto
  - reveal con TTL + reason
  - audit logs append-only
  - Admin SDK para claims
- Riesgo anti-mock: crítico
- Listo para Stitch: sí
- Listo para Codex: sí
- Prompt Stitch requerido: sí
- Notas:
  - No prometer imposible copiar; minimizar exposición y auditar.

### ADMIN-MERCHANTS-01 — Listado de comercios

- Tarjeta vinculada: TuM2-0078
- Plataforma: Admin Web
- Estado inventario: `needs_stitch`
- Descripción: listado administrativo paginado de comercios, con estado, visibilidad, verificación, fuente y zona.
- Usuario objetivo: ADMIN
- Datos reales requeridos:
  - `merchants`
  - `merchant_public` opcional para comparación
  - filtros por zona/estado
- Prohibido simular con mock:
  - comercios
  - estado de verificación
  - visibilidad
- Estados UX obligatorios:
  - loading
  - empty
  - resultados
  - filtros sin resultados
  - error
  - permission denied
- Dependencias técnicas:
  - queries paginadas
  - filtros obligatorios
  - reglas admin
- Riesgo anti-mock: alto
- Listo para Stitch: sí
- Listo para Codex: no
- Prompt Stitch requerido: sí
- Notas:
  - No hacer full scan de `merchants`.

### ADMIN-ZONES-01 — Gestión/consulta de zonas

- Tarjeta vinculada: TuM2-0045 / deuda ZoneSelectorSheet
- Plataforma: Admin Web / Mobile shared data
- Estado inventario: `blocked_backend`
- Descripción: administración o consulta de zonas reales desde colección `zones`, eliminando listas hardcodeadas.
- Usuario objetivo: ADMIN / sistema
- Datos reales requeridos:
  - `zones`
- Prohibido simular con mock:
  - barrios hardcodeados
  - provincias/departamentos/localidades en listas locales
- Estados UX obligatorios:
  - loading
  - empty
  - error
- Dependencias técnicas:
  - colección `zones`
  - cache TTL
  - paginación si aplica
- Riesgo anti-mock: alto
- Listo para Stitch: no
- Listo para Codex: sí
- Prompt Stitch requerido: no
- Notas:
  - Prioridad técnica por deuda conocida.

---

## 10. Inventario inicial — Web pública

### WEB-01 — Landing principal

- Tarjeta vinculada: TuM2-0071
- Plataforma: Web pública
- Estado inventario: `needs_stitch`
- Descripción: landing pública de TuM2 con propuesta de valor, acceso al catálogo, farmacias de turno y abierto ahora.
- Usuario objetivo: Anónimo / CUSTOMER
- Datos reales requeridos:
  - opcional `merchant_public` para preview controlada
  - `zones` si hay selector
- Prohibido simular con mock:
  - comercios preview si se muestran como reales
  - zona activa
- Estados UX obligatorios:
  - landing estática
  - preview loading
  - preview empty
  - error preview
- Dependencias técnicas:
  - Firebase Hosting
  - Flutter Web
  - queries limitadas si hay preview
- Riesgo anti-mock: medio
- Listo para Stitch: sí
- Listo para Codex: sí
- Prompt Stitch requerido: sí
- Notas:
  - No convertir en marketplace.

### WEB-02 — Catálogo público web

- Tarjeta vinculada: TuM2-0072 / TuM2-0075
- Plataforma: Web pública
- Estado inventario: `needs_stitch`
- Descripción: catálogo web navegable con filtros por zona, rubro MVP, abierto ahora y señales públicas.
- Usuario objetivo: Anónimo / CUSTOMER
- Datos reales requeridos:
  - `merchant_public`
  - `zones`
- Prohibido simular con mock:
  - resultados
  - zona hardcodeada
  - rubros fuera de configuración MVP vigente
- Estados UX obligatorios:
  - loading
  - empty
  - filtros sin resultados
  - error
- Dependencias técnicas:
  - queries scoped
  - paginación/limit
  - SEO/deep links cuando aplique
- Riesgo anti-mock: alto
- Listo para Stitch: sí
- Listo para Codex: sí
- Prompt Stitch requerido: sí
- Notas:
  - Web pública debe consumir proyección pública, nunca `merchants` privado.

### WEB-03 — Ficha pública de comercio web

- Tarjeta vinculada: TuM2-0072
- Plataforma: Web pública
- Estado inventario: `needs_stitch`
- Descripción: detalle público compartible de comercio.
- Usuario objetivo: Anónimo / CUSTOMER
- Datos reales requeridos:
  - `merchant_public/{merchantId}`
- Prohibido simular con mock:
  - horarios
  - estado operativo
  - datos de contacto
- Estados UX obligatorios:
  - loading
  - no encontrado
  - oculto/suprimido
  - error
- Dependencias técnicas:
  - Hosting
  - deep links
  - lectura pública segura
- Riesgo anti-mock: alto
- Listo para Stitch: sí
- Listo para Codex: sí
- Prompt Stitch requerido: sí
- Notas:
  - No exponer datos privados del owner.

---

## 11. Cómo usar este archivo para pedir pantallas a Stitch

Cuando una entrada tenga:

- `Listo para Stitch: sí`
- `Prompt Stitch requerido: sí`
- estado `needs_stitch`, `stitch_ready` o `designed` con rediseño pendiente

se puede solicitar un prompt con este formato:

```txt
Generá el prompt Stitch para [SCREEN-ID] — [Nombre funcional], usando como fuente el archivo docs/ops/ANTI_MOCK_SCREEN_INVENTORY.md y respetando:
- descripción funcional
- datos reales requeridos
- estados UX obligatorios
- restricciones anti-mock
- reglas de arquitectura TuM2
- sistema visual TuM2
- rubros MVP vigentes
```

El prompt resultante debe pedir pantallas realistas, con estados completos y sin datos inventados que puedan confundirse con integración productiva.

---

## 12. Cómo usar este archivo para pedir implementación a Codex

Cuando una entrada tenga:

- `Listo para Codex: sí`
- diseño disponible o no requerido
- backend/data contract definido

se puede solicitar implementación con este formato:

```txt
Implementá [SCREEN-ID] — [Nombre funcional] respetando docs/ops/ANTI_MOCK_SCREEN_INVENTORY.md.
No uses mocks productivos.
Conectá datos reales, reglas reales y estados reales.
Si falta backend o contrato, no marques la tarjeta como DONE: documentá bloqueo y dejá estado real.
```

---

## 13. Checklist anti-mock antes de cerrar una pantalla

Antes de marcar una pantalla como DONE:

- [ ] No usa mocks productivos.
- [ ] No usa fakes/stubs en implementación real.
- [ ] No usa datos hardcodeados como sustituto de backend.
- [ ] No usa rubros fuera de la configuración MVP vigente.
- [ ] No lee colecciones privadas desde UI pública.
- [ ] No escribe `merchant_public` desde cliente.
- [ ] Toda query tiene scope y `limit` cuando aplica.
- [ ] Tiene loading, empty, error y permission denied si aplica.
- [ ] Maneja falta de ubicación si depende de ubicación.
- [ ] Maneja offline/red inestable si aplica.
- [ ] Tiene tests mínimos o checklist QA documentado.
- [ ] Actualizó storycard correspondiente.
- [ ] Actualizó `CLAUDE.md` si cambió estado real.
- [ ] Documentó deuda restante si no puede cerrarse.

---

## 14. Deuda inicial detectada para seguimiento

| ID | Deuda | Impacto | Acción esperada |
|---|---|---|---|
| `DEBT-ZONES-001` | `ZoneSelectorSheet` usa barrios hardcodeados | Costo/calidad/datos reales | Migrar a colección `zones` con cache TTL |
| `DEBT-SEARCH-001` | `buildSearchKeywords()` declarado pero no implementado en proyección | Búsqueda real | Implementar en `computeMerchantPublicProjection()` |
| `DEBT-RULES-001` | `getUserRole()` en rules lee Firestore por request | Costo/latencia | Migrar a JWT custom claims |
| `DEBT-OPEN-STATUS-001` | `nightlyRefreshOpenStatuses` usa N sequential reads | Escalabilidad | Batch/cursor/checkpoint/no-op writes |
| `DEBT-APPCHECK-001` | callables admin con `enforceAppCheck=false` | Seguridad/costo | Activar en staging/prod |
| `DEBT-INDEXES-001` | comentarios JSON en `firestore.indexes.json` | Deploy | Remover comentarios |
| `DEBT-TYPES-001` | `functions/src/lib/types.ts` usa `zone/category` legacy | Consistencia | Migrar a `zoneId/categoryId` |
