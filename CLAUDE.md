# CLAUDE.md — Memoria persistente del proyecto TuM2

## Reglas de idioma

- **Descripciones, comentarios y documentación**: siempre en **español**
- **Código fuente**: siempre en **inglés** (variables, funciones, clases, archivos, etc.)

## Regla anti-mocks (obligatoria)

- Para cualquier tarjeta marcada como implementada/completada, la solución debe estar **100% funcional** sin datos mock.
- En revisiones y QA de cierre: **no se aceptan** `mock`, `fake`, `stub`, datos hardcodeados de demo ni flujos simulados como sustituto de integración real.
- Si existe una pantalla con mock temporal, la tarjeta se considera **incompleta** hasta conectar backend real y persistencia real.

## Fuente de verdad de estado (obligatoria)

- El único documento fuente de verdad para estado de tarjetas es **este `CLAUDE.md`**.
- OpenSpec queda **discontinuado** en este repositorio para planificación/estado.
- No usar artefactos de `openspec/` para decidir progreso ni para reportes ejecutivos.
- Si hay diferencias entre `openspec/` y `CLAUDE.md`, **prevalece `CLAUDE.md`**.

---

## Convención de nombres de conversación y PR

Cada conversación de Claude Code para este proyecto debe identificarse con el patrón:

```
tum2-XXXX — PR#YY — descripción corta
```

- `XXXX` = número de tarjeta del backlog (ej: `0061`, `0045`)
- Si no hay tarjeta asignable → usar `xxxx` literal (ej: `tum2-xxxx`)
- `YY` = número del PR de GitHub que se va a generar en esa conversación
- Si todavía no se conoce el número de PR → omitir hasta que se cree

**Ejemplos:**
- `tum2-0061 — PR#22 — implementar pharmacy duty screen`
- `tum2-0045 — PR#18 — configurar firestore base`
- `tum2-xxxx — PR#25 — mejora pharmacy duties schema`

**Reglas operativas:**
- Una conversación = una tarjeta = un PR (siempre que sea posible)
- Si la tarjeta es muy grande → partir en sub-PRs y numerarlos en el título
- PRs chicos y cohesivos, nunca mezclar tarjetas distintas en un mismo PR

---

## Estado del backlog

El backlog maestro de TuM2 está estructurado en 17 épicas (ver sección abajo).
El usuario pasa las tarjetas de a una. Estado actual:

| Definición ✅ | Actividad completada |
|---|---|
| **[0001]** Definir propuesta de valor final ✅ | Dirección del producto — propuesta de valor final definida y documentada |
| **[0003]** Cerrar alcance real del MVP ✅ | Dirección del producto — scope MVP congelado, documentado en docs/MVP-SCOPE.md: IN/OUT, guardrails, decisiones clave, BDD, analytics, roadmap y rollout |
| **[0004]** Cerrar segmentos principales ✅ | Producto / Seguridad — segmentos CUSTOMER, OWNER y ADMIN cerrados con límites de acceso y responsabilidades |
| **[0005]** Mantener actualizado VISION.md ✅ | Documentación maestra — VISION.md actualizado y vigente |
| **[0006]** Mantener actualizado PRD-MVP.md ✅ | Documentación maestra — PRD-MVP.md actualizado y vigente |
| **[0007]** Mantener actualizado ARCHITECTURE.md ✅ | Documentación maestra — ARCHITECTURE.md actualizado y vigente |
| **[0010]** Definir identidad visual base ✅ | Branding — paleta y tokens base definidos (color system inicial TuM2) |
| **[0014]** Definir tono de microcopy ✅ | Branding / UX/UI — guía de microcopy MVP Fase 3 documentada en docs/TuM2-0014-MICROCOPY.md |
| **[0019]** Diseñar modelo de usuarios ✅ | Modelo de datos — modelo de usuarios definido con roles y atributos |
| **[0020]** Diseñar modelo de comercios ✅ | Modelo de datos — modelo de comercios definido con campos públicos y operativos |
| **[0021]** Diseñar modelo de productos ✅ | Modelo de datos — modelo de productos definido con variantes y disponibilidad |
| **[0022]** Diseñar modelo de horarios ✅ | Modelo de datos — modelo de horarios definido con franjas y excepciones |
| **[0023]** Diseñar modelo de señales operativas ✅ | Modelo de datos — modelo de señales operativas definido por rubro |
| **[0024]** Diseñar modelo de turnos/guardias ✅ | Modelo de datos — modelo de turnos de farmacia definido con rotación y vigencia |
| **[0042]** Crear proyecto base Firebase ✅ | Backend / Firebase — proyecto Firebase creado y configurado |
| **[0043]** Configurar ambientes dev/staging/prod ✅ | Backend / Firebase — tres ambientes configurados con variables separadas |
| **[0044]** Configurar Authentication ✅ | Backend / Firebase — autenticación configurada con proveedores y roles |
| **[0045]** Configurar Firestore base ✅ | Backend / Firebase — Firestore configurado con colecciones base |
| **[0046]** Definir Firestore Rules iniciales ✅ | Backend / Firebase — reglas de seguridad iniciales definidas por rol |
| **[0047]** Configurar Storage ✅ | Backend / Firebase — Storage rules y configuración base de storage integradas |
| **[0048]** Implementar Cloud Functions base ✅ | Backend / Firebase — funciones base implementadas y desplegadas |
| **[0049]** Implementar campos derivados operativos ✅ | Backend / Firebase — isOpenNow, isOnDutyToday y otros campos derivados implementados |
| **[0050]** Implementar agregados públicos ✅ | Backend / Firebase — agregados públicos implementados para consumo mobile y web |
| **[0052]** Crear proyecto base mobile ✅ | Mobile app — proyecto mobile base creado con estructura y dependencias |
| **[0121]** Estrategia cobertura inicial y bootstrap ✅ | Cobertura / Data — estrategia de cobertura y bootstrap con Google Places definida |
| **[0027]** Definir mapa completo de pantallas ✅ | UX / arquitectura — mapa de pantallas completo definido para todos los roles |
| **[0028]** Diseñar navegación principal ✅ | UX / arquitectura — navegación principal diseñada con estructura de tabs y flujos |
| **[0029]** Diseñar onboarding CUSTOMER ✅ | UX/UI — AUTH stack completo diseñado: splash, onboarding 3 slides, login/registro (5 estados), verificación email (4 estados) |
| **[0030]** Diseñar onboarding OWNER ✅ | UX/UI — flujo completo implementado: draft entry, step1 tipo+nombre, step2 dirección, step3 horarios, step4 confirmación |
| **[0033]** Diseñar ficha pública de comercio ✅ | UX/UI — HOME-01 Detail diseñado por Stitches: hero imagen, badge ABIERTO, info rows, mapa, acciones, historia y galería |
| **[0037]** Diseñar panel Mi comercio ✅ | UX/UI — OWNER-01 diseñado por Stitches: estado actual, acciones rápidas 2×2, banner advertencia, banner promocional |
| **[0053]** Implementar shell de app ✅ | Mobile app — shell implementado: tabs, guards por rol, pantallas HOME-01/SEARCH-01/PROFILE-01/OWNER-01/DETAIL-01 con UI real, bugs de code review corregidos |
| **[0054]** Implementar login / registro ✅ | Mobile app — AUTH MVP completo: magic link email (same/cross-device con app_links), Google Sign-In, guards/redirects por rol consistentes, pending route post-auth, signOut hardened y tests de auth/router actualizados |
| **[0056]** Implementar búsqueda de comercios ✅ | Mobile app — búsqueda MVP cerrada: corpus por zona con filtros/ranking, pantallas lista/mapa/empty integradas según mockups, tests de SearchNotifier en verde y documentación actualizada |
| **[0057]** Implementar mapa ✅ | Mobile app — SEARCH-03 migrado a Google Maps con sistema de markers por estado, selección visual, z-index por prioridad y clustering por grilla desacoplado |
| **[0058]** Implementar ficha de comercio ✅ | Mobile app — DETAIL-01 implementado con navegación real desde search/home/deep links |
| **[0060]** Implementar vista Abierto ahora ✅ | Mobile app — HOME-02 implementado con filtros por rubro MVP y navegación al mapa |
| **[0066]** Implementar carga de horarios ✅ | Mobile app — OWNER-06 implementado con UI Stitch completa, validaciones, excepciones/cierres, persistencia en subcolecciones, triggers backend de recompute, feature flag Remote Config y analytics de módulo |
| **[0067]** Implementar carga de señales operativas ✅ | Mobile app / Backend — OWNER-08 migrado a señal operativa manual (`vacation`, `temporary_closure`, `delay`) con mensaje opcional (80), persistencia en `merchant_operational_signals`, precedencia server-side (`manual override > horario`) y proyección pública sincronizada por trigger con no-op write avoidance |
| **[0068]** Implementar carga de turnos farmacia ✅ | Mobile app / Backend — OWNER-09/10/11 implementado con calendario mensual, alta/edición/borrado, publicación batch costo-optimizada, validaciones server-side y proyección pública vía Cloud Functions |
| **[0077]** Diseñar panel admin mínimo ✅ | Admin / Web — portal web admin creado en Flutter Web: AdminShell con sidebar oscuro, topbar de búsqueda, sistema de rutas go_router y módulo de importación de datasets completo |
| **[0122]** Implementar módulo de importación de datasets (admin web) ✅ | Admin / Web — 7 estados de UI implementados: empty state, lista con tabla y KPIs, wizard 3 pasos (archivo + preview + config), pantalla de resultado del batch, modal de reversión destructivo; schema import_batches extendido con FieldMapping, RowError, visibilidad y contadores UI |
| **[0123]** Enforce de capacidad de catálogo por comercio ✅ | Backend / Mobile / Admin Web — límites globales/categoría/override en `admin_configs/catalog_limits`, creación de productos vía callable con validación transaccional y hard-block por cupo, telemetría de warning/bloqueo y gestión admin de límites |
| **[0124]** Mitigación operativa de guardias de farmacia ✅ | Backend / Mobile — confirmación preventiva, incidente operativo, candidatas por zona+distancia con límite, ronda de reasignación (primera aceptación gana), expiración automática de solicitudes y degradación pública por confianza |
| **[0031]** Diseñar pantalla Buscar ✅ | UX/UI — Stack de búsqueda completo según mockups: SEARCH-01 (3 estados: initial/focused/typing), SEARCH-02 (6 estados: loading/results/openNow/verified/empty/error), pantalla especialidad farmacias, location fallback, zone selector sheet, filtros avanzados. 8 archivos implementados |
| **[0036]** Diseñar vista Abierto ahora ✅ | UX/UI — HOME-02 implementado: header con zona activa + indicador en vivo, filtro por categoría (6 rubros), lista de comercios con horario de cierre y action buttons, barra "Ver en el mapa" |
| **[0035]** Diseñar vista Farmacias de turno ✅ | UX/UI — HOME-03 implementado: hero farmacia activa con CTAs (Cómo llegar / Llamar), lista "Resto del día", disclaimer de actualización de turnos |
| **[0035]** Diseñar vista Farmacias de turno ✅ | UX/UI — HOME-03 diseñado por Stitches e implementado: listado con badges de turno y confianza, 4 estados (sin ubicación, cargando, resultados, vacío), detalle con verificación, mapa, CTAs y reporte |
| **[0061]** Implementar vista Farmacias de turno ✅ | Mobile app — PharmacyDutyScreen y PharmacyDutyDetailScreen integrados con datos reales, estados operativos y deep links de detalle |

---

## Indicador de avance MVP (snapshot 2026-04-08)

- Método A (prioridad P0/P1 con tags `MVP` o `Fundacional`, excluyendo `Post-MVP` y `MVP+`): **44 / 89 = 49.44%**
- Método B (todas las prioridades con tags `MVP` o `Fundacional`, excluyendo `Post-MVP` y `MVP+`): **44 / 97 = 45.36%**
- Este indicador mide cierre de tarjetas del backlog maestro; no reemplaza criterios de release (QA/legal/datos piloto).

---

## Backlog Maestro TuM2

### ÉPICA 1: Dirección del producto
- [0001] **Definir propuesta de valor final de TuM2** — P0 — `Producto, Fundacional` ✅
- [0002] **Definir claim principal de marca** — P1 — `Branding, Producto, Fundacional`
  - Opciones: "Lo que necesitás, en tu zona" / "Todo lo que pasa en tu metro cuadrado" / "Comercios reales, cerca tuyo"
- [0003] **Cerrar alcance real del MVP** — P0 — `Producto, Fundacional` ✅
- [0004] **Cerrar segmentos principales** — P0 — `Producto, Seguridad, Fundacional` ✅
  - OWNER, CUSTOMER y ADMIN con sus objetivos

### ÉPICA 2: Documentación maestra
- [0005] **Mantener actualizado VISION.md** — P0 — `Producto, Fundacional` ✅
- [0006] **Mantener actualizado PRD-MVP.md** — P0 — `Producto, Fundacional` ✅
- [0007] **Mantener actualizado ARCHITECTURE.md** — P0 — `Backend, Mobile, Web, Data, Fundacional` ✅
- [0008] **Mantener actualizado ROADMAP.md** — P1 — `Producto, Operaciones, Fundacional`
- [0009] **Mantener actualizado PROMPT-PLAYBOOK.md** — P1 — `Producto, Operaciones, Fundacional`

### ÉPICA 3: Branding de TuM2
- [0010] **Definir identidad visual base** — P0 — `Branding, UX/UI, Fundacional` ✅
- [0011] **Diseñar logo principal** — P0 — `Branding, Fundacional`
- [0012] **Diseñar app icon** — P0 — `Branding, Mobile, Web, Fundacional`
- [0013] **Definir sistema de sellos** — P1 — `Branding, Producto, MVP`
- [0014] **Definir tono de microcopy** — P1 — `Branding, UX/UI, MVP` ✅

### ÉPICA 4: Research funcional y operativo
- [0015] **Relevar rubros prioritarios** — P0 — `Producto, Operaciones, Fundacional`
  - Base sugerida: farmacias, kioscos, almacenes, veterinarias
- [0016] **Relevar caso farmacias de turno** — P0 — `Producto, Operaciones, Data, Fundacional`
- [0017] **Relevar señales operativas por rubro** — P0 — `Producto, Data, Operaciones, Fundacional`
- [0018] **Relevar flujo real del dueño** — P1 — `Producto, UX/UI, Operaciones, Fundacional`

### ÉPICA 5: Modelo de datos
- [0019] **Diseñar modelo de usuarios** — P0 — `Data, Backend, Seguridad, Fundacional` ✅
- [0020] **Diseñar modelo de comercios** — P0 — `Data, Backend, Fundacional` ✅
- [0021] **Diseñar modelo de productos** — P0 — `Data, Backend, Fundacional` ✅
- [0022] **Diseñar modelo de horarios** — P0 — `Data, Backend, Fundacional` ✅
- [0023] **Diseñar modelo de señales operativas** — P0 — `Data, Backend, Fundacional` ✅
- [0024] **Diseñar modelo de turnos/guardias** — P0 — `Data, Backend, Operaciones, Fundacional` ✅
- [0025] **Diseñar modelo de propuestas y votos** — P1 — `Data, Backend, Growth, Admin, MVP`
- [0026] **Diseñar modelo de badges y branding snippets** — P2 — `Data, Branding, Post-MVP`

### ÉPICA 6: UX / arquitectura de pantallas
- [0027] **Definir mapa completo de pantallas** — P0 — `UX/UI, Producto, Fundacional` ✅
- [0028] **Diseñar navegación principal** — P0 — `UX/UI, Mobile, Fundacional` ✅
- [0029] **Diseñar onboarding CUSTOMER** — P1 — `UX/UI, MVP` ✅
- [0030] **Diseñar onboarding OWNER** — P0 — `UX/UI, Operaciones, MVP` ✅
- [0031] **Diseñar pantalla Buscar** — P0 — `UX/UI, MVP` ✅
- [0032] **Diseñar pantalla Mapa** — P1 — `UX/UI, MVP`
- [0033] **Diseñar ficha pública de comercio** — P0 — `UX/UI, Producto, MVP` ✅
- [0034] **Diseñar ficha de producto** — P1 — `UX/UI, MVP`
- [0035] **Diseñar vista Farmacias de turno** — P0 — `UX/UI, Operaciones, MVP` ✅
- [0036] **Diseñar vista Abierto ahora** — P0 — `UX/UI, MVP` ✅
- [0037] **Diseñar panel Mi comercio** — P0 — `UX/UI, Operaciones, MVP` ✅
- [0038] **Diseñar flujo carga de productos** — P0 — `UX/UI, Operaciones, MVP`
- [0039] **Diseñar flujo carga de horarios y señales** — P0 — `UX/UI, Operaciones, MVP`
- [0040] **Diseñar flujo carga de turnos de farmacia** — P0 — `UX/UI, Operaciones, MVP`
- [0041] **Diseñar board de propuestas y votos** — P1 — `UX/UI, Growth, Admin, MVP`

### ÉPICA 7: Backend / Firebase / Infraestructura
- [0042] **Crear proyecto base Firebase** — P0 — `Backend, Fundacional` ✅
- [0043] **Configurar ambientes dev / staging / prod** — P0 — `Backend, Seguridad, Operaciones, Fundacional` ✅
- [0044] **Configurar Authentication** — P0 — `Backend, Seguridad, Fundacional` ✅
- [0045] **Configurar Firestore base** — P0 — `Backend, Data, Fundacional` ✅
- [0046] **Definir Firestore Rules iniciales** — P0 — `Seguridad, Backend, Fundacional` ✅
- [0047] **Configurar Storage** — P1 — `Backend, Seguridad, MVP` ✅
- [0048] **Implementar Cloud Functions base** — P1 — `Backend, MVP` ✅
- [0049] **Implementar campos derivados operativos** — P0 — `Backend, Data, Operaciones, MVP` ✅
  - isOpenNow, isOnDutyToday, etc.
- [0050] **Implementar agregados públicos** — P1 — `Backend, Data, Web, Mobile, MVP` ✅
- [0051] **Configurar CI/CD técnico mínimo** — P1 — `Backend, Mobile, Web, Operaciones, Lanzamiento`

### ÉPICA 8: Mobile app
- [0052] **Crear proyecto mobile base** — P0 — `Mobile, Fundacional` ✅
- [0053] **Implementar shell de app** — P0 — `Mobile, UX/UI, MVP` ✅
- [0054] **Implementar login / registro** — P0 — `Mobile, Seguridad, MVP` ✅
- [0055] **Implementar home CUSTOMER** — P1 — `Mobile, Producto, MVP`
- [0056] **Implementar búsqueda de comercios** — P0 — `Mobile, MVP` ✅
- [0057] **Implementar mapa** — P1 — `Mobile, MVP` ✅
- [0058] **Implementar ficha de comercio** — P0 — `Mobile, Producto, MVP` ✅
- [0059] **Implementar ficha de producto** — P2 — `Mobile, MVP`
- [0060] **Implementar vista Abierto ahora** — P0 — `Mobile, MVP` ✅
- [0061] **Implementar vista Farmacias de turno** — P0 — `Mobile, MVP` ✅
- [0062] **Implementar favoritos** — P2 — `Mobile, MVP`
- [0063] **Implementar seguir comercio** — P2 — `Mobile, MVP`
- [0064] **Implementar módulo OWNER** — P0 — `Mobile, Operaciones, MVP` `IN_PROGRESS`
- [0065] **Implementar alta/edición de productos** — P0 — `Mobile, Owner, MVP`
- [0066] **Implementar carga de horarios** — P0 — `Mobile, Owner, MVP` ✅
- [0067] **Implementar carga de señales operativas** — P0 — `Mobile, Owner, MVP` ✅
- [0068] **Implementar carga de turnos farmacia** — P0 — `Mobile, Owner, MVP` ✅
- [0069] **Implementar módulo de propuestas y votos** — P1 — `Mobile, Growth, MVP`

### ÉPICA 9: Web pública
- [0070] **Crear web pública base** — P1 — `Web, Fundacional`
- [0071] **Implementar landing principal** — P1 — `Web, Branding, MVP`
- [0072] **Implementar ficha pública de comercio web** — P0 — `Web, MVP`
- [0073] **Implementar ficha pública de producto web** — P2 — `Web, MVP`
- [0074] **Implementar landing Farmacias de turno web** — P0 — `Web, Operaciones, MVP`
- [0075] **Implementar landing Abierto ahora web** — P0 — `Web, MVP`
- [0076] **Implementar links compartibles** — P1 — `Web, Growth, MVP`

### ÉPICA 10: Admin / Moderación
- [0077] **Diseñar panel admin mínimo** — P1 — `Admin, Producto, MVP` ✅
  - Flutter Web portal: AdminShell (sidebar + topbar), go_router, tokens compartidos con mobile
- [0078] **Implementar listado de comercios** — P2 — `Admin, MVP`
- [0122] **Implementar módulo de importación de datasets (admin web)** — P1 — `Admin, Web, Data, Operaciones, MVP` ✅
  - 7 estados de UI: empty state, lista con tabla/KPIs/paginación, wizard Archivo→Preview→Configuración, resultado del batch, modal de reversión
  - Schema import_batches extendido: ImportFieldMapping, ImportRowError, ImportVisibility, batchNumber, datasetType, fieldMappings, deduplicationEnabled, visibilityAfterImport, errors, contadores UI
- [0079] **Implementar listado de propuestas** — P2 — `Admin, MVP`
- [0080] **Implementar moderación de contenido** — P1 — `Admin, Seguridad, MVP`
- [0081] **Implementar revisión de señales operativas reportadas** — P1 — `Admin, Operaciones, MVP`

### ÉPICA 11: Analytics
- [0082] **Definir eventos analytics** — P0 — `Analytics, Producto, MVP`
- [0083] **Implementar tracking base** — P0 — `Analytics, Mobile, Web, MVP`
- [0084] **Crear dashboard MVP** — P1 — `Analytics, MVP`
- [0085] **Medir activación OWNER** — P1 — `Analytics, Operaciones, MVP`
- [0086] **Medir activación CUSTOMER** — P1 — `Analytics, MVP`
- [0087] **Medir uso de señales operativas** — P0 — `Analytics, Producto, MVP`

### ÉPICA 12: Seguridad / calidad / release readiness
- [0088] **Configurar App Check** — P1 — `Seguridad, MVP`
- [0089] **Configurar Crashlytics** — P1 — `Seguridad, Analytics, MVP`
- [0090] **Crear checklist QA MVP** — P0 — `QA, MVP`
- [0091] **Testear permisos por rol** — P0 — `QA, Seguridad, MVP`
- [0092] **Testear edge cases operativos** — P0 — `QA, Operaciones, MVP`
- [0093] **Configurar alertas técnicas mínimas** — P1 — `Seguridad, Operaciones, Lanzamiento`

### ÉPICA 13: Lanzamiento / piloto
- [0094] **Definir piloto geográfico** — P0 — `Lanzamiento, Producto, MVP`
- [0095] **Definir rubros iniciales de salida** — P0 — `Lanzamiento, Producto, MVP`
- [0096] **Armar material de onboarding para comercios** — P1 — `Growth, Operaciones, Lanzamiento`
- [0097] **Armar material para captar primeras farmacias** — P0 — `Growth, Operaciones, Lanzamiento`
- [0098] **Preparar publicación beta** — P1 — `Lanzamiento, Mobile, Web`
- [0099] **Preparar metadata de stores y canales** — P1 — `Lanzamiento, Branding, Mobile, Web`

### ÉPICA 14: Legal / compliance
- [0100] **Redactar política de privacidad** — P0 — `Legal, Seguridad, Lanzamiento`
- [0101] **Redactar términos y condiciones** — P0 — `Legal, Lanzamiento`
- [0102] **Definir consentimiento y tratamiento de evidencia documental (claims)** — P0 — `Legal, Seguridad, Lanzamiento`
- [0103] **Definir derechos de rectificación/eliminación/revisión de datos de claim** — P0 — `Legal, Seguridad, Lanzamiento`
- [0104] **Definir política de retención, acceso interno y resguardo de datos sensibles** — P0 — `Legal, Admin, Seguridad, Lanzamiento`

### ÉPICA 15: Growth / comunidad
- [0105] **Diseñar sistema de propuestas y votos usable** — P1 — `Growth, Producto, MVP`
- [0106] **Implementar links compartibles de propuestas** — P2 — `Growth, MVP`
- [0107] **Definir loop de invitación** — P2 — `Growth, MVP`
- [0108] **Diseñar badges comunitarios** — P3 — `Branding, Growth, Post-MVP`

### ÉPICA 16: Monetización / modelo de negocio
- [0109] **Definir hipótesis de monetización no invasiva** — P2 — `Monetización, Producto, Post-MVP`
- [0110] **Definir criterios para promociones patrocinadas** — P2 — `Monetización, Growth, Post-MVP`
- [0111] **Diseñar medición base para monetización futura** — P2 — `Monetización, Analytics, Post-MVP`

### ÉPICA 17: Post-MVP / escalamiento
- [0112] **Carga masiva de productos** — P2 — `Operaciones, Data, Post-MVP`
- [0113] **Carga masiva de calendarios** — P3 — `Operaciones, Data, Post-MVP`
- [0114] **Mejor discover geográfico** — P2 — `Producto, Growth, Post-MVP`
- [0115] **Verificación avanzada** — P2 — `Seguridad, Admin, Post-MVP`
- [0116] **Promociones patrocinadas** — P3 — `Monetización, Growth, Post-MVP`
- [0117] **Monetización no invasiva** — P3 — `Monetización, Post-MVP`
- [0118] **Rankings por zona** — P3 — `Producto, Growth, Post-MVP`
- [0119] **Reputación de comercios** — P2 — `Producto, Growth, Post-MVP`
- [0120] **Más automatización operativa** — P2 — `Operaciones, Backend, Post-MVP`

### ÉPICA TRANSVERSAL: Cobertura y bootstrap de datos
- [0121] **Diseñar estrategia de cobertura inicial de comercios por zona y bootstrap con fuentes externas** — P0 — `Producto, Data, Backend, Operaciones, Fundacional` ✅
  - TUM-138 / Parent: TuM2-9004 / TUM-18
  - Dependencias: TuM2-0001, TuM2-0003, TuM2-0015, TuM2-0017, TuM2-0020
  - Fuente semilla: Google Places (controlada, con guardrails de costo y atribución)
- [0123] **Aplicar límites de capacidad de catálogo por comercio/categoría** — P0 — `Backend, Mobile, Admin, Operaciones, MVP` ✅
  - PR #58: callables con `enforceAppCheck`, límites globales/categoría/override y creación de producto transaccional con bloqueo por cuota.
  - Costo: búsqueda admin acotada con `limit` (máx. 30) y capacidad owner con cache TTL en provider.
- [0124] **Mitigar guardias de farmacia con reasignación operativa** — P0 — `Backend, Mobile, Operaciones, MVP` ✅
  - PR #59: incidente → candidatas por `zoneId` + distancia + `limit` → ronda abierta con requests paralelos y cierre por primera aceptación.
  - Costo: scans programados incrementales (`limit` fijo) para recordatorios/expiraciones, sin listeners globales.

### ÉPICA 18: Reclamo de titularidad de comercio
- [0125] **Épica: Reclamo de titularidad de comercio** — P0 — `Producto, Backend, Mobile, Admin, Seguridad, Legal, MVP` `IN_PROGRESS`
- [0126] **Flujo de claim del comercio (usuario/owner)** — P0 — `Mobile, UX/UI, MVP` `IN_PROGRESS`
- [0127] **Validación automática inicial de claims** — P0 — `Backend, Seguridad, MVP` `IN_PROGRESS`
- [0128] **Revisión manual de claims en Admin Web** — P0 — `Admin, Web, Seguridad, MVP` `IN_PROGRESS`
- [0129] **Evidencia y documentación por categoría de comercio** — P0 — `Producto, Operaciones, Legal, MVP`
- [0130] **Seguridad y protección de datos sensibles en claims** — P0 — `Seguridad, Backend, Admin, MVP` `IN_PROGRESS`
- [0131] **Integración de claim con roles OWNER / owner_pending / aprobación** — P0 — `Producto, Seguridad, Mobile, Backend, MVP` `IN_PROGRESS`
- [0132] **Verificación de teléfono del usuario para fase 2** — P1 — `Auth, Seguridad, Post-MVP`
- [0133] **Conflictos, duplicados y disputa de titularidad** — P0 — `Admin, Backend, Seguridad, MVP` `IN_PROGRESS`

### ÉPICA 19: Estacionalidad y campañas contextuales
- [0134] **Modo Selección Argentina + tarjeta pineada de próximo partido** — P1 — `Producto, Branding, Mobile, Web, Admin, Backend, Analytics, MVP+`

---

## Orden real de ejecución recomendado

### Fase A — Fundacional real
- TuM2-0001 propuesta de valor
- TuM2-0003 alcance MVP
- TuM2-0004 segmentos
- TuM2-0005 / 0006 / 0007 documentación maestra
- TuM2-0015 / 0016 / 0017 research funcional
- TuM2-0019 a 0024 modelo de datos núcleo
- TuM2-0027 / 0028 arquitectura de pantallas
- TuM2-0042 / 0043 / 0044 / 0045 / 0046 backend base
- TuM2-0052 proyecto mobile base
- TuM2-0070 web pública base
- TuM2-0010 / 0011 / 0012 branding base
- **TuM2-0121 estrategia de cobertura inicial y bootstrap**

### Fase B — Núcleo MVP
- TuM2-0030 onboarding owner
- TuM2-0031 / 0033 / 0035 / 0036 / 0037 / 0038 / 0039 / 0040 UX de núcleo
- TuM2-0048 / 0049 / 0050 lógica pública y derivada
- TuM2-0123 límites de capacidad de catálogo (owner/admin)
- TuM2-0053 / 0054 shell + auth mobile
- TuM2-0056 / 0058 / 0060 / 0061 descubrimiento y valor público
- TuM2-0064 / 0065 / 0066 / 0067 / 0068 módulo owner
- TuM2-0124 mitigación operativa de guardias (reasignación + confianza pública)
- TuM2-0071 / 0072 / 0074 / 0075 web pública útil
- TuM2-0082 / 0083 / 0087 analytics base
- TuM2-0090 / 0091 / 0092 QA y seguridad operativa

### Fase C — Claims de titularidad (MVP inmediato)
- TuM2-0125 épica madre
- TuM2-0126 flujo de claim
- TuM2-0127 validación automática inicial
- TuM2-0128 revisión manual en Admin
- TuM2-0129 evidencia por categoría
- TuM2-0130 seguridad de datos sensibles
- TuM2-0131 integración con OWNER / owner_pending
- Actualización obligatoria: TuM2-0004, 0053, 0054, 0064
- Actualización legal obligatoria: TuM2-0100, 0101, 0102, 0103, 0104

### Fase D — Lanzamiento controlado
- TuM2-0094 / 0095 piloto y rubros
- TuM2-0097 material para farmacias
- TuM2-0100 / 0101 / 0102 / 0103 / 0104 legal mínimo
- TuM2-0089 / 0093 observabilidad
- TuM2-0098 / 0099 beta y metadata
- TuM2-0051 CI/CD mínimo

### Fase E — Expansión MVP+
- TuM2-0029 / 0032 / 0034 / 0041
- TuM2-0122 ✅ (completado adelantado)
- TuM2-0055 / 0059 / 0062 / 0063 / 0069 (TuM2-0057 ✅ completado adelantado)
- TuM2-0076
- TuM2-0077 a 0081
- TuM2-0084 / 0085 / 0086
- TuM2-0105 / 0106 / 0107
- TuM2-0132 verificación de teléfono (fase 2)
- TuM2-0133 automatización avanzada de disputas (si aplica)

---

## Bloqueantes estructurales

- TuM2-0001, 0003, 0004, 0006, 0007
- TuM2-0015, 0016, 0017
- TuM2-0019 a TuM2-0024
- TuM2-0027, 0028
- TuM2-0042 a TuM2-0046
- TuM2-0052
- **TuM2-0121**

## Bloqueantes del MVP núcleo

- TuM2-0030, 0031, 0033, 0035, 0036, 0037, 0038, 0039, 0040
- TuM2-0049, 0053, 0054, 0056, 0058, 0060, 0061
- TuM2-0064, 0065, 0066, 0067, 0068
- TuM2-0125, 0126, 0127, 0128, 0129, 0130, 0131, 0133
- TuM2-0072, 0074, 0075
- TuM2-0082, 0083, 0087
- TuM2-0090, 0091, 0092
- TuM2-0094, 0095, 0097
- TuM2-0100, 0101, 0102, 0103, 0104
- TuM2-0077 ✅, TuM2-0078, 0079, 0080, 0081, TuM2-0122 ✅, TuM2-0123 ✅, TuM2-0124 ✅

---

## Quick wins

Estos dan mucha claridad o valor con relativamente poco costo:
- TuM2-0003 — Cerrar alcance MVP
- TuM2-0004 — Cerrar segmentos
- TuM2-0010 — Identidad visual base
- TuM2-0014 — Tono de microcopy
- TuM2-0015 — Rubros prioritarios
- TuM2-0017 — Taxonomía de señales
- TuM2-0082 — Definir eventos analytics
- TuM2-0094 — Definir piloto geográfico
- TuM2-0095 — Definir rubros iniciales de salida
- TuM2-0102 — Consentimiento de evidencia documental para claims
- TuM2-0104 — Retención y acceso interno de datos sensibles
- TuM2-0099 — Metadata de stores y canales

---

## Qué debe ir sí o sí en MVP

**Producto y arquitectura:** TuM2-0001, 0003, 0004, 0006, 0007, 0015, 0016, 0017, 0019 a 0024, 0027, 0028, 0030, 0031, 0033, 0035, 0036, 0037, 0038, 0039, 0040

**Backend:** TuM2-0042, 0043, 0044, 0045, 0046, 0048, 0049, 0050, 0123 ✅, 0124 ✅

**Mobile:** TuM2-0052, 0053, 0054, 0056, 0057, 0058, 0060, 0061, 0064, 0065, 0066, 0067, 0068, 0124 ✅, 0126, 0131

**Web:** TuM2-0070, 0071, 0072, 0074, 0075

**Admin / Web portal:** TuM2-0077 ✅, TuM2-0122 ✅, TuM2-0123 ✅, TuM2-0078, 0079, 0080, 0081, 0128, 0130, 0133

**Analytics / QA / Seguridad:** TuM2-0082, 0083, 0087, 0089, 0090, 0091, 0092, 0127, 0130

**Lanzamiento:** TuM2-0094, 0095, 0097, 0098, 0099

**Legal:** TuM2-0100, 0101, 0102, 0103, 0104, 0125

---

## Qué debe ir a Post-MVP

**Claramente Post-MVP:** TuM2-0026, 0108, 0109, 0110, 0111, 0112, 0113, 0114, 0115, 0116, 0117, 0118, 0119, 0120

**MVP+ / opcionales si entra tiempo:** TuM2-0029, 0032, 0034, 0041, 0055, 0059, 0062, 0063, 0069, 0073, 0076, 0077 a 0081, 0084, 0085, 0086, 0105, 0106, 0107, 0134 (TuM2-0047 ✅ y TuM2-0057 ✅ cerradas)

---

## Impacto cruzado: dominio de claim de titularidad (2026-04-14)

Se incorpora la épica TuM2-0125 y tarjetas hijas 0126–0133 como backlog activo de MVP.

Actualizaciones obligatorias sincronizadas por impacto:
- TuM2-0004 — Role / Segment Architecture
- TuM2-0054 — Auth completa
- TuM2-0053 — Shell mobile
- TuM2-0064 — Módulo OWNER
- TuM2-0081 — Revisión/edición de perfil vinculada a estado de claim
- TuM2-0100 a TuM2-0104 — Legal y consentimientos del flujo claim

Reglas canónicas transversales del dominio claim:
- El email del claim es siempre el email autenticado del usuario.
- Teléfono en MVP: opcional y sin verificación.
- Verificación de teléfono: fuera de MVP (TuM2-0132).
- Todo claim pasa por validación automática antes de revisión humana.
- Casos dudosos/conflictivos pasan a revisión manual en Admin.
- Datos sensibles en Admin: masking por defecto, reveal temporal y auditoría.
- Si un dato requiere revisión humana, debe existir cifrado reversible con control de acceso.
- Privacidad/Términos/consentimientos deben cubrir explícitamente el flujo de claims.

Sincronización documental aplicada (storycards, 2026-04-15):
- Arquitectura y acceso: 0004, 0053, 0054, 0064, 0131.
- Claim core: 0127, 0128, 0129, 0130, 0132, 0133.
- Legal claims: 0100, 0101, 0102, 0103, 0104.

---

## Reglas operativas
- Máximo 1-3 tareas grandes activas simultáneamente
- Máximo 3-5 tareas chicas activas simultáneamente
- Pasar a "Listo para hacer" solo lo que corresponde a la fase actual
- En cada avance de tarjeta, actualizar siempre `docs/storyscards/<tarjeta>.md` y `CLAUDE.md` con estado real.

## Registro operativo reciente
- [0056] Implementar búsqueda de comercios: estado final DONE (cerrada el 2026-04-07).
- [0056] Mobile quedó recompuesto y compilable: modelos/repositorios de búsqueda, notifier con ranking y filtros MVP, exclusión de panadería/confitería, rutas de búsqueda activas y analytics safe.
- [0056] Se agregó cobertura unitaria en Flutter para SearchNotifier (inicialización, normalización, filtros open-now, ranking, y consistencia lista/mapa).
- [0056] Se aplicó integración visual de pantallas search según `stitch_tum2.zip` (inicio, loading, lista, mapa y vacío enriquecido).
- [0056] Validación local: analyze focalizado en search/router/auth PASS; tests auth/router/search PASS.
- [0056] Deuda no bloqueante diferida: QA visual completa con set final de capturas y validación web/cross-plataforma.
- [0057] SEARCH-03 actualizado a Google Maps con arquitectura separada de `marker/` y `cluster/`, cache de bitmaps por visualType+pixelRatio y fallback web.
- [0057] Implementado clustering por grilla (activación >20 visibles), prioridad por estado operativo y tap en cluster con zoom in automático.
- [0057] Review fixes aplicados: recuperación de analytics `search_result_opened` en apertura desde mapa + fingerprint de recomputación incluyendo lat/lng para evitar posiciones stale.
- [0058] DETAIL-01 consolidado con navegación desde mapa/lista/home y deep links `/commerce/:id`.
- [0060] HOME-02 consolidado en flujo productivo con navegación a SEARCH-03.
- [0061] Farmacias de turno consolidado con flujo público y deep links de detalle.
- [0066] OWNER-06 consolidado con pantalla completa de horarios (corrido/cortado/cerrado), preview y validaciones inline.
- [0066] Implementadas excepciones por fecha y cierres temporales por rango con alta/edición/eliminación.
- [0066] Integración Firestore sobre `schedule_config/weekly`, `schedule_exceptions` y `schedule_exceptions_ranges`, con reglas y triggers backend para recompute de proyección pública.
- [0066] Integrado feature flag `owner_schedule_editor_enabled` vía Firebase Remote Config + eventos analytics `owner_schedule_*` para seguimiento de adopción y errores.
- [0067] OWNER-08 implementado con flujo de señal manual activa/inactiva (sin listeners permanentes), tipos MVP (`vacation`, `temporary_closure`, `delay`), validación de mensaje (80 chars) y desactivación explícita.
- [0067] Backend unificado en trigger `merchant_operational_signals -> merchant_public` con función canónica de precedencia: `vacation/temporary_closure` fuerzan cerrado, `delay` es informativa y preserva `isOpenNow` automático.
- [0067] Reglas Firestore endurecidas: `merchant_public` client write deny, `merchant_operational_signals` restringido a owner/admin con validaciones de enum/tipos/ownership/path consistency y bloqueo de campos derivados en writes owner.
- [0123] Límites de catálogo cerrados (PR #58, 2026-04-09): configuración global/categoría/override en `admin_configs/catalog_limits`, alta de producto vía callable transaccional y bloqueo duro por cupo.
- [0123] UI OWNER/ADMIN integrada con capacidad (`used/limit/source`), eventos analytics de warning/bloqueo y controles de costo (`limit` en búsquedas admin + cache TTL de config).
- [0124] Mitigación de guardias cerrada (PR #59, 2026-04-09): confirmación de guardia, reporte de incidente, selección de candidatas por zona/distancia y ronda de reasignación con primera aceptación ganadora.
- [0124] Nuevas colecciones operativas (`pharmacy_duty_incidents`, `pharmacy_duty_reassignment_rounds`, `pharmacy_duty_reassignment_requests`) y jobs incrementales para recordatorios/expiraciones con límites de scan por ciclo.
- [0126] Flujo claim en progreso (2026-04-14): implementado flujo mobile CLAIM-01..07 con Firebase real (draft, evidencia, consentimiento, submit, estado), sin listeners permanentes y con refresh por acción.
- [0126] Backend inicial implementado: callables `upsertMerchantClaimDraft`, `submitMerchantClaim`, `evaluateMerchantClaim`, `resolveMerchantClaim`, `revealMerchantClaimSensitiveData`, `getMyMerchantClaimStatus`, `listMerchantClaimsForReview`, `listMyMerchantClaims`, `searchClaimableMerchants`; reglas Firestore/Storage endurecidas e índices `merchant_claims` actualizados a `claimStatus`.
- [Claims docs] Actualización integral de storycards del dominio claim (2026-04-15): 0004, 0053, 0054, 0064, 0100, 0101, 0102, 0103, 0104, 0127, 0128, 0129, 0130, 0131, 0132, 0133.
- [0134] Alta documental inicial (2026-04-17): creadas `docs/storyscards/0134-modo-seleccion-argentina.md` y `docs/storyscards/0134-modo-seleccion-argentina.prompt.md`; estado canónico `TODO` (sin implementación).
