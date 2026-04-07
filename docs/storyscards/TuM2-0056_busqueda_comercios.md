TuM2 — Tu metro cuadrado

**TuM2-0056**

**Implementar búsqueda de comercios**

Épica: Descubrimiento · Fase: MVP · Prioridad: P0 — Bloqueante

*Roles involucrados: Product Ops Manager + Product Manager + Tech Lead*

Estudio Floki · 2025

# 1. Objetivo

Implementar la funcionalidad de búsqueda de comercios locales dentro de
TuM2, cubriendo: búsqueda por texto libre con sugerencias en tiempo
real, filtrado por categoría (rubro), estado operativo (abierto ahora),
nivel de verificación mínimo y orden por distancia. La búsqueda consume
exclusivamente la colección merchant_public, soporta cambio de zona
activa desde el buscador, y entrega resultados en SEARCH-02 con toggle
lista/mapa. El campo searchKeywords en la proyección pública se
implementa en esta tarjeta como parte de la capa backend (Cloud
Functions).

# 2. Contexto

### Problema que resuelve

Actualmente SEARCH-01 y SEARCH-02 existen como pantallas con UI visual
completa pero con datos hardcodeados y sin lógica de negocio real. El
usuario no puede buscar comercios reales de su zona, lo que hace que el
tab Buscar no cumpla ninguna función de valor. Esta tarjeta convierte
esos stubs en funcionalidad productiva.

### Posición en la arquitectura

La búsqueda de TuM2 se apoya en el patrón de doble colección: merchants
(fuente canónica, solo escribe owner/admin/CF) y merchant_public
(proyección denormalizada, read-only pública). El cliente nunca consulta
merchants directamente para discovery. Toda query de búsqueda va contra
merchant_public con índices compuestos ya definidos en
firestore.indexes.json.

### Estado actual del repo (auditado)

| **Artefacto**                   | **Estado**                                                   | **Acción en esta tarjeta**              |
|---------------------------------|--------------------------------------------------------------|-----------------------------------------|
| SearchScreen (SEARCH-01)        | UI completa, datos mock, sin lógica                          | Conectar a provider y corpus real       |
| SearchResultsScreen (SEARCH-02) | UI completa, 6 estados visuales, datos mock                  | Conectar a SearchNotifier/provider      |
| SearchFiltersSheet              | Widget UI completo, sin estado funcional                     | Conectar filtros reales al provider     |
| ZoneSelectorSheet               | UI completa, lista hardcodeada de zonas                      | Conectar a colección zones de Firestore |
| projection.ts (CF)              | computeMerchantPublicProjection() no genera searchKeywords   | Implementar buildSearchKeywords()       |
| Índices Firestore               | Índices por zoneId+categoryId+visibilityStatus ya declarados | Solo consumir, no modificar             |

# 3. User Stories

### US-01 — Búsqueda por texto

"Como vecino quiero escribir el nombre o tipo de comercio y ver
sugerencias mientras tipeo, para encontrar lo que busco sin saber el
nombre exacto."

### US-02 — Filtrado por categoría

"Como vecino quiero filtrar resultados por rubro (farmacia, kiosco,
almacén, etc.) para acotar rápidamente las opciones relevantes."

### US-03 — Filtrado por estado operativo

"Como vecino quiero ver solo los comercios que están abiertos ahora,
para no perder tiempo yendo a uno cerrado."

### US-04 — Cambio de zona

"Como vecino que trabaja en una zona y vive en otra quiero poder cambiar
la zona de búsqueda desde el buscador, sin tener que ir a
configuración."

### US-05 — Resultados con señales de confianza

"Como vecino quiero ver qué tan confiable es la información de cada
comercio (verificado, referencial, pendiente) para decidir si vale la
pena ir."

### US-06 — Toggle lista/mapa

"Como vecino quiero poder ver los resultados en mapa para entender
geográficamente dónde están los comercios más cercanos."

### US-07 — Historial de búsquedas

"Como vecino frecuente quiero que mis búsquedas anteriores estén
guardadas para no tener que tipear lo mismo cada vez."

# 4. Alcance

## 4.1 IN — Incluido en esta tarjeta

- Backend CF: implementación de buildSearchKeywords() en projection.ts —
  generación del array searchKeywords en merchant_public al sincronizar
  un comercio

- Backend CF: backfill callable para regenerar searchKeywords en todos
  los documentos merchant_public existentes

- Flutter mobile: SearchNotifier (Riverpod) — provider de estado de
  búsqueda con precarga del corpus de zona, debounce 250ms, filtros y
  orden

- Flutter mobile: ZoneSelectorSheet conectado a colección zones de
  Firestore (reemplaza lista hardcodeada)

- Flutter mobile: SEARCH-01 (SearchScreen) conectada al notifier —
  estados initial/focused/typing con sugerencias reales

- Flutter mobile: SEARCH-02 (SearchResultsScreen) conectada al notifier
  — estados loading/results/empty/error/openNow con datos reales

- Flutter mobile: SearchFiltersSheet conectado — filtros funcionales:
  categoryId, isOpenNow, verificationStatus mínimo, orden por distancia

- Flutter mobile: SEARCH-03 (mapa) implementado como vista básica con
  pins por estado (toggle desde SEARCH-02)

- Flutter mobile: historial de búsquedas persistido con
  SharedPreferences (máx 10 términos)

- Flutter mobile: fallback de cold-start — mostrar review_pending con
  badge cuando visible \< 3 comercios en la zona

- Índice Firestore adicional: zoneId + visibilityStatus + categoryId +
  sortBoost (compuesto para filtro categoría ordenado)

## 4.2 OUT — Excluido explícitamente

- Motor de búsqueda externo (Algolia, Typesense, Elasticsearch) —
  migración post-MVP cuando zona supere ~500 comercios

- Búsqueda de productos dentro de comercios — tarjeta futura

- Búsqueda cross-zona automática (ampliar a zonas adyacentes) — post-MVP

- Búsqueda por voz

- Filtros avanzados adicionales: precio, rating, tiene delivery, tiene
  WhatsApp — post-MVP

- SEARCH-03 con navegación completa y clusters — solo pins básicos en
  MVP

- Búsqueda en web app (Flutter Web) — solo mobile en esta tarjeta

- Analítica de búsqueda avanzada (trending queries, query rewriting) —
  post-MVP

# 5. Supuestos

- Los índices compuestos en firestore.indexes.json ya están desplegados
  en todos los ambientes (dev/staging/prod).

- La colección zones existe con documentos reales en Firestore (al menos
  la zona piloto Adrogué).

- La CF trigger onMerchantWriteSyncPublic ya existe y funciona; solo se
  extiende con buildSearchKeywords().

- El corpus por zona piloto no supera 200 documentos en merchant_public
  — filtrado cliente-side es viable.

- flutter_riverpod ^2.5 y shared_preferences ya están en pubspec.yaml.

- geolocator ya está integrado en el proyecto (usado en otras
  pantallas); se reutiliza para calcular distancia.

- Los visibilityStatus "visible" y "review_pending" son los únicos que
  se exponen en búsqueda pública. Hidden/suppressed nunca se muestran al
  cliente.

- isOpenNow: null (sin info de horario) se trata como "no se puede
  afirmar que está abierto" — no aparece en filtro abierto ahora.

- La zona activa del usuario está resuelta previamente (por GPS o
  selección manual en onboarding/home) y disponible en un ZoneProvider
  global.

# 6. Subtareas por capa

## 6.1 Cloud Functions (TypeScript)

| **ID** | **Subtarea**                                                                                                                                                          | **Archivo**                                        | **Prioridad** |
|--------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------|---------------|
| CF-01  | Implementar buildSearchKeywords(merchant): string\[\] en lib/projection.ts — tokeniza name, normalizedName, categoryId, address (sin números), y aliases de categoría | functions/src/lib/projection.ts                    | P0            |
| CF-02  | Integrar buildSearchKeywords() en computeMerchantPublicProjection() — agregar campo searchKeywords al objeto de proyección                                            | functions/src/lib/projection.ts                    | P0            |
| CF-03  | Crear callable admin backfillSearchKeywords — itera todos los docs merchant_public y regenera searchKeywords (para datos existentes)                                  | functions/src/admin/backfillKeywords.ts            | P0            |
| CF-04  | Unit tests para buildSearchKeywords() — casos: nombre con tildes, categoría compuesta, dirección, nombre con Dr./Dra., caracteres especiales                          | functions/src/lib/\_\_tests\_\_/projection.test.ts | P0            |
| CF-05  | Exportar el callable backfillSearchKeywords desde index.ts y desplegar en dev/staging                                                                                 | functions/src/index.ts                             | P1            |

## 6.2 Flutter Mobile — Capa de datos y estado

| **ID** | **Subtarea**                                                                                                                                                                               | **Archivo**                                                 | **Prioridad** |
|--------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------|---------------|
| M-01   | Crear MerchantSearchRepository — método fetchZoneCorpus(zoneId, {visibilityStatuses}) que carga hasta 200 docs de merchant_public por zona y los cachea en el notifier                     | modules/search/repositories/merchant_search_repository.dart | P0            |
| M-02   | Crear SearchFilters (modelo inmutable) — campos: categoryId?, isOpenNow?, minVerificationStatus?, sortBy (distancia\|sortBoost\|nombre)                                                    | modules/search/models/search_filters.dart                   | P0            |
| M-03   | Crear SearchState (Riverpod) — campos: corpus, query, filters, suggestions, results, activeZoneId, isLoading, error                                                                        | modules/search/providers/search_notifier.dart               | P0            |
| M-04   | Implementar SearchNotifier — métodos: loadCorpus(), setQuery(), setFilters(), setZone(), clearHistory(); lógica: debounce 250ms, filtrado cliente sobre searchKeywords, ordenamiento final | modules/search/providers/search_notifier.dart               | P0            |
| M-05   | Implementar lógica de filtrado en cliente — normalización UTF-8 sin tildes, startsWith/contains sobre tokens de searchKeywords, aplicación de filtros en cascada                           | modules/search/providers/search_notifier.dart               | P0            |
| M-06   | Implementar orden de resultados — priority: sortBoost DESC, isOpenNow DESC, distancia ASC (Haversine con posición del usuario), community_submitted al final                               | modules/search/providers/search_notifier.dart               | P0            |
| M-07   | Implementar historial de búsquedas con SharedPreferences — persistir máx 10 términos confirmados; exponer como stream en el notifier                                                       | modules/search/providers/search_history_provider.dart       | P1            |
| M-08   | Crear ZoneSearchRepository — fetchAvailableZones() que lee colección zones donde status in \[pilot_enabled, public_enabled\]                                                               | modules/search/repositories/zone_search_repository.dart     | P0            |

## 6.3 Flutter Mobile — UI

| **ID** | **Subtarea**                                                                                                                                                                                                   | **Archivo**                                       | **Prioridad** |
|--------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------|---------------|
| U-01   | Conectar SearchScreen (SEARCH-01) al SearchNotifier — reemplazar mock por sugerencias reales en estado typing; mostrar historial en estado focused                                                             | modules/search/screens/search_screen.dart         | P0            |
| U-02   | Conectar SearchResultsScreen (SEARCH-02) al SearchNotifier — reemplazar mock por resultados reales; manejar los 6 estados (loading/results/empty/error/openNow/verified)                                       | modules/search/screens/search_results_screen.dart | P0            |
| U-03   | Conectar SearchFiltersSheet al SearchNotifier — los filtros seleccionados mutan SearchFilters; el sheet muestra el estado activo al abrirse                                                                    | modules/search/widgets/search_filters_sheet.dart  | P0            |
| U-04   | Conectar ZoneSelectorSheet a ZoneSearchRepository — reemplazar \_barrios hardcodeados por query real a zones; al confirmar, actualizar zona activa en SearchNotifier y ZoneProvider                            | modules/search/widgets/zone_selector_sheet.dart   | P0            |
| U-05   | Implementar toggle lista/mapa en SEARCH-02 — botón en app bar que conmuta entre ListView y MapView del mismo conjunto de resultados; mapa usa flutter_map o placeholder si no hay key de mapa                  | modules/search/screens/search_results_screen.dart | P0            |
| U-06   | Implementar MerchantSearchCard — tarjeta de resultado con: nombre, badge de verificación (chip coloreado), categoría, distancia, openStatusLabel, isOpenNow indicator, CTA tap → DETAIL-01                     | modules/search/widgets/merchant_search_card.dart  | P0            |
| U-07   | Implementar empty state de búsqueda — dos variantes: (a) sin resultados verified/visible + mostrar review_pending con badge "información no verificada", (b) zona sin datos en absoluto + CTA sugerir comercio | modules/search/widgets/search_empty_state.dart    | P0            |
| U-08   | Implementar chips de categoría en SEARCH-01 y SEARCH-02 — los 7 rubros MVP con ícono y label; selección muta filtro categoryId; "Todos" limpia el filtro                                                       | modules/search/widgets/category_chips_row.dart    | P1            |
| U-09   | Implementar mapa básico SEARCH-03 — pins coloreados por isOpenNow (verde/rojo/gris); tap en pin → bottom sheet con MerchantSearchCard reducida → tap en card → DETAIL-01                                       | modules/search/screens/search_map_screen.dart     | P0            |

# 7. Datos impactados

| **Colección**                  | **Operación**      | **Actor**                      | **Campo/Condición**                                                                         |
|--------------------------------|--------------------|--------------------------------|---------------------------------------------------------------------------------------------|
| merchant_public                | READ (query)       | Flutter cliente                | zoneId + visibilityStatus in \[visible, review_pending\] + (optional) categoryId; limit 200 |
| merchant_public                | UPDATE (batch)     | CF callable admin backfill     | Agrega/actualiza campo searchKeywords en documentos existentes                              |
| zones                          | READ               | Flutter cliente (ZoneSelector) | status in \[pilot_enabled, public_enabled\]; no escribe                                     |
| merchant_public.searchKeywords | WRITE (CF trigger) | onMerchantWriteSyncPublic      | Array de tokens generado por buildSearchKeywords() en cada sync                             |
| SharedPreferences              | READ/WRITE         | Flutter cliente                | Clave: search_history — lista de strings, máx 10 ítems                                      |

### Especificación de buildSearchKeywords()

Para un comercio con name="Farmacia Central Dr. López" y
categoryId="pharmacy":

- Tokens de nombre: \["farmacia", "central", "dr", "lopez"\] —
  lowercase, sin tildes, sin puntuación, tokens ≥ 3 chars

- Bigramas parciales de nombre: \["farmacia central", "central dr", "dr
  lopez"\]

- categoryId canónico: \["pharmacy", "farmacia"\] — incluir alias
  español

- Tokens de dirección: solo calle, sin número — \["espora", "avenida",
  "av"\] filtrado de stopwords

- Array final deduplicado, máx 30 tokens

# 8. APIs y servicios involucrados

| **Servicio**           | **Uso en esta tarjeta**                                                               | **Notas**                                                                                        |
|------------------------|---------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------|
| Cloud Firestore        | Query merchant_public por zona; query zones para selector                             | Índice compuesto: zoneId + visibilityStatus + categoryId + sortBoost DESC — verificar que existe |
| Cloud Functions        | Trigger onMerchantWriteSyncPublic (extender); callable backfillSearchKeywords (nuevo) | El callable requiere token ADMIN; timeout 540s para backfill masivo                              |
| Riverpod ^2.5          | SearchNotifier, ZoneProvider, SearchHistoryProvider                                   | StateNotifier + AsyncNotifier pattern ya en uso en el proyecto                                   |
| shared_preferences     | Persistencia del historial de búsquedas                                               | Ya en pubspec; clave: search_history                                                             |
| geolocator             | Cálculo de distancia Haversine para orden por cercanía                                | Ya integrado; obtener posición actual al cargar corpus                                           |
| flutter_map (opcional) | Vista mapa en SEARCH-03                                                               | Si no hay licencia de Google Maps configurada, usar OpenStreetMap con flutter_map                |
| Firebase Analytics     | Eventos de búsqueda (ver sección Analytics)                                           | logEvent() desde el notifier, no desde la UI                                                     |

# 9. Checklists

## 9.1 Checklist técnico

| **\#** | **Ítem**                                                                                                               | **Capa**  | **Estado** |
|--------|------------------------------------------------------------------------------------------------------------------------|-----------|------------|
| T-01   | buildSearchKeywords() implementada y con tests unitarios (tildes, puntuación, stopwords)                               | CF        | ⬜         |
| T-02   | searchKeywords se escribe en merchant_public en cada sync de onMerchantWriteSyncPublic                                 | CF        | ⬜         |
| T-03   | Callable backfillSearchKeywords protegido con verificación de custom claim ADMIN                                       | CF        | ⬜         |
| T-04   | Índice compuesto zoneId + visibilityStatus + categoryId + sortBoost existe en firestore.indexes.json y está desplegado | Firestore | ⬜         |
| T-05   | MerchantSearchRepository limita a 200 docs por query y maneja el caso de zona vacía                                    | Flutter   | ⬜         |
| T-06   | Filtrado en cliente normaliza el query de búsqueda (lowercase, sin tildes, trim) antes de comparar                     | Flutter   | ⬜         |
| T-07   | Debounce de 250ms implementado en SearchNotifier — no hay llamadas a Firestore por cada keystroke                      | Flutter   | ⬜         |
| T-08   | isOpenNow: null no aparece en resultados cuando filtro "abierto ahora" está activo                                     | Flutter   | ⬜         |
| T-09   | ZoneSelectorSheet carga zonas desde Firestore — no hay lista hardcodeada en producción                                 | Flutter   | ⬜         |
| T-10   | Historial persistido en SharedPreferences con máx 10 ítems; se limpia correctamente al superar el límite               | Flutter   | ⬜         |
| T-11   | Toggle lista/mapa no recarga datos — mismo corpus, solo cambia la vista                                                | Flutter   | ⬜         |
| T-12   | MerchantSearchCard muestra badge correcto según verificationStatus (colores del design system)                         | Flutter   | ⬜         |
| T-13   | Tap en resultado navega correctamente a /detail/:merchantId con GoRouter                                               | Flutter   | ⬜         |
| T-14   | No hay lecturas directas a colección merchants desde el módulo de búsqueda                                             | Flutter   | ⬜         |
| T-15   | En modo sin ubicación disponible, la búsqueda funciona sin orden por distancia (fallback: sortBoost)                   | Flutter   | ⬜         |

## 9.2 Checklist UX

| **\#** | **Ítem**                                                                                                                  | **Pantalla** | **Estado** |
|--------|---------------------------------------------------------------------------------------------------------------------------|--------------|------------|
| UX-01  | Sugerencias aparecen en \< 300ms al escribir (corpus ya precargado en memoria)                                            | SEARCH-01    | ⬜         |
| UX-02  | Máximo 5 sugerencias visibles en el estado typing — no colapsan el teclado                                                | SEARCH-01    | ⬜         |
| UX-03  | Historial de búsquedas muestra máx 5 ítems recientes en estado focused                                                    | SEARCH-01    | ⬜         |
| UX-04  | Chip de zona activa visible en header de SEARCH-01 con tap para cambiar zona                                              | SEARCH-01    | ⬜         |
| UX-05  | Badge "información no verificada" usa color amber — no alarma en exceso pero informa                                      | SEARCH-02    | ⬜         |
| UX-06  | Empty state no dice solo "Sin resultados" — incluye sugerencia accionable (mostrar review_pending o CTA)                  | SEARCH-02    | ⬜         |
| UX-07  | Los filtros activos son visibles en chips resumidos encima de los resultados                                              | SEARCH-02    | ⬜         |
| UX-08  | El toggle lista/mapa está en app bar, no dentro del scroll — siempre accesible                                            | SEARCH-02    | ⬜         |
| UX-09  | Pins del mapa en SEARCH-03 usan el sistema de colores del design system: verde (abierto), rojo (cerrado), gris (sin info) | SEARCH-03    | ⬜         |
| UX-10  | Al cambiar de zona en ZoneSelectorSheet, los resultados se recargan y hay feedback visual de loading                      | SEARCH-01/02 | ⬜         |
| UX-11  | En cold-start el copy de los cards con review_pending explica claramente que "la información no fue verificada"           | SEARCH-02    | ⬜         |
| UX-12  | La distancia se muestra en metros si \< 1000m, en km con un decimal si \> 1000m                                           | SEARCH-02    | ⬜         |

# 10. Criterios de aceptación BDD

### Escenario 1 — Búsqueda por texto con sugerencias

Given el usuario está en SEARCH-01 con corpus de la zona ya cargado

And la zona activa es "Adrogué Centro" con 50 comercios en
merchant_public

When escribe "farm" (3+ caracteres)

Then en menos de 300ms aparecen hasta 5 sugerencias que contengan el
token "farm" en sus searchKeywords

And las sugerencias se ordenan: verified primero, community_submitted
último

### Escenario 2 — Filtro abierto ahora

Given el usuario está en SEARCH-02 con resultados de la zona

When activa el filtro "Abierto ahora" en SearchFiltersSheet

Then los resultados solo muestran comercios donde isOpenNow == true

And los comercios donde isOpenNow == null no aparecen en la lista

And se muestra un chip "Abierto ahora" activo encima de los resultados

### Escenario 3 — Cambio de zona desde el buscador

Given el usuario tiene zona activa "Adrogué Centro"

When toca el chip de zona en SEARCH-01 y selecciona "Burzaco" en
ZoneSelectorSheet

Then el corpus se recarga con los comercios de zoneId correspondiente a
Burzaco

And el header de SEARCH-01 muestra "Burzaco" como zona activa

And la zona activa se actualiza en el ZoneProvider global

### Escenario 4 — Cold-start de zona

Given una zona con 0 comercios con visibilityStatus == visible

But la zona tiene 3 comercios con visibilityStatus == review_pending

When el usuario realiza cualquier búsqueda en esa zona

Then se muestran los comercios review_pending con badge "Información no
verificada"

And debajo aparece CTA "¿Conocés un comercio? Sugerilo" que navega al
flujo de sugerencia

### Escenario 5 — Toggle lista/mapa

Given el usuario está en SEARCH-02 con resultados visibles

When toca el botón de mapa en la app bar

Then se muestra la vista SEARCH-03 con pins posicionados en las
coordenadas de cada comercio

And los pins son verdes para isOpenNow==true, rojos para false, grises
para null

And al volver a tap en el botón de lista regresa a la vista de lista con
el mismo conjunto de resultados sin recargar

### Escenario 6 — buildSearchKeywords() genera tokens correctos

Given un comercio con name="Veterinaria Dr. Fernández" y
categoryId="veterinary"

When se actualiza el documento en merchants y dispara
onMerchantWriteSyncPublic

Then merchant_public/{id}.searchKeywords contiene al menos:
\["veterinaria", "fernandez", "dr", "veterinary"\]

And no contiene stopwords como \["de", "la", "el"\] ni tokens de \< 3
caracteres

### Escenario 7 — Historial de búsquedas

Given el usuario confirmó búsquedas anteriores: "farmacia", "kiosco",
"almacén"

When abre SEARCH-01 y toca la barra de búsqueda (estado focused)

Then ve sus 3 búsquedas recientes como chips de historial

And al tap en uno se ejecuta la búsqueda directamente navegando a
SEARCH-02

And el historial persiste al cerrar y reabrir la app

# 11. Analytics

| **Evento Firebase**        | **Trigger**                                           | **Parámetros**                                                                                 |
|----------------------------|-------------------------------------------------------|------------------------------------------------------------------------------------------------|
| search_query_submitted     | Usuario confirma búsqueda (Enter o tap en sugerencia) | query: string, zone_id: string, filters_active: boolean, result_count: number                  |
| search_suggestion_tapped   | Usuario toca una sugerencia en tiempo real            | suggestion_text: string, position: number, zone_id: string                                     |
| search_filter_applied      | Usuario aplica un filtro desde SearchFiltersSheet     | filter_type: categoryId\|isOpenNow\|verificationStatus\|distance, value: string                |
| search_result_tapped       | Usuario toca un comercio en SEARCH-02                 | merchant_id: string, position: number, verification_status: string, is_open_now: boolean\|null |
| search_map_toggled         | Usuario alterna entre lista y mapa                    | to_mode: list\|map, result_count: number, zone_id: string                                      |
| search_zone_changed        | Usuario confirma cambio de zona en ZoneSelectorSheet  | from_zone_id: string, to_zone_id: string                                                       |
| search_empty_state_shown   | Se muestra el empty state de búsqueda                 | query: string, zone_id: string, reason: no_results\|cold_start\|error                          |
| search_history_item_tapped | Usuario toca un ítem del historial                    | query: string, history_position: number                                                        |

### North Star de esta tarjeta

% de sesiones de búsqueda que terminan con tap en un resultado (tasa de
conversión de búsqueda → ficha). Target MVP: \> 40%.

# 12. Riesgos

| **ID** | **Riesgo**                                                                                                                    | **Probabilidad** | **Impacto** | **Mitigación**                                                                                             |
|--------|-------------------------------------------------------------------------------------------------------------------------------|------------------|-------------|------------------------------------------------------------------------------------------------------------|
| R-01   | searchKeywords vacío en comercios importados por batch (TuM2-0122) — el backfill callable no se ejecuta antes del lanzamiento | Alta             | Alto        | Incluir backfill como paso obligatorio del runbook de lanzamiento; verificar en staging antes de prod      |
| R-02   | Corpus de zona supera 200 docs en zonas densas futuras — filtrado cliente-side se vuelve lento                                | Media            | Medio       | Límite de 200 con warning en logs; migración a motor externo planificada como post-MVP en ROADMAP          |
| R-03   | ZoneSelectorSheet muestra zonas en status "draft" o "paused" por error de filtro                                              | Baja             | Alto        | Query explicita status in \[pilot_enabled, public_enabled\]; test de integración que verifica el filtro    |
| R-04   | isOpenNow desactualizado (nightly refresh) muestra comercio como abierto estando cerrado                                      | Media            | Medio       | Ya mitigado por la arquitectura: openStatusLabel siempre muestra el horario textual como fallback          |
| R-05   | Normalización de tildes inconsistente entre buildSearchKeywords() (CF/Node) y el filtrado cliente (Dart)                      | Media            | Alto        | Documentar la función de normalización como spec compartida; test E2E que busca "farmacia" con y sin tilde |
| R-06   | Mapa SEARCH-03 requiere API key de Google Maps no configurada en CI/CD                                                        | Alta             | Bajo        | Usar flutter_map con OpenStreetMap como provider MVP — sin API key; migrar a Google Maps en post-MVP       |

# 13. Edge Cases

| **ID** | **Escenario**                                                                   | **Comportamiento esperado**                                                                                                |
|--------|---------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------|
| EC-01  | Usuario busca con solo espacios o caracteres especiales ("!!!", " ")            | Normalizar a string vacío; no ejecutar búsqueda; mantener estado focused                                                   |
| EC-02  | Query de 1-2 caracteres                                                         | No filtrar por texto — mostrar todos los resultados de la zona con los filtros activos; no mostrar sugerencias             |
| EC-03  | Zona activa no tiene ningún documento en merchant_public                        | Empty state con mensaje "Aún no hay comercios cargados en esta zona" + CTA sugerir                                         |
| EC-04  | Todos los comercios de la zona tienen isOpenNow == null (sin horarios cargados) | Filtro "Abierto ahora" muestra empty state + mensaje "No hay información de horarios disponible" en lugar de lista vacía   |
| EC-05  | Usuario cambia de zona mientras hay una búsqueda activa                         | Cancelar búsqueda anterior, limpiar corpus, recargar con nueva zona, preservar el texto del query y reaplicar              |
| EC-06  | Firestore offline / sin conexión al cargar corpus                               | Mostrar estado error con mensaje "Sin conexión. Revisá tu red." + botón Reintentar; no mostrar lista vacía sin explicación |
| EC-07  | Comercio con verificationStatus == community_submitted en resultados            | Mostrar con badge amber "No verificado" — siempre visible, nunca invisible; tap navega igual a DETAIL-01                   |
| EC-08  | Historial con 10 ítems lleno y el usuario busca un nuevo término                | Eliminar el más antiguo (FIFO), agregar el nuevo al tope; no mostrar error                                                 |
| EC-09  | Usuario en SEARCH-03 (mapa) sin permiso de ubicación                            | Mapa centrado en el centroid de la zona; pins visibles; sin botón "Mi ubicación" activo                                    |
| EC-10  | searchKeywords es array vacío en un documento merchant_public                   | El comercio no aparece en búsquedas por texto pero sí en filtros de categoría; logging de warning en el notifier           |
| EC-11  | Zona con un solo comercio visible                                               | Mostrar ese comercio sin el mensaje de cold-start; el threshold de cold-start es \< 3                                      |
| EC-12  | Nombre del comercio contiene emojis (ej: "Kiosco 🏪 El Sol")                    | buildSearchKeywords() strippea emojis antes de tokenizar; el nombre se muestra íntegro en la UI                            |

# 14. Plan de QA

## 14.1 Tests unitarios (CF — TypeScript)

- buildSearchKeywords(): nombre con tildes → tokens sin tildes

- buildSearchKeywords(): nombre con Dr./Dra./Prof. → tokens normalizados

- buildSearchKeywords(): categoryId "pharmacy" → incluye alias
  "farmacia"

- buildSearchKeywords(): nombre vacío → array vacío (no lanza)

- buildSearchKeywords(): nombre con caracteres especiales/emojis →
  tokens limpios

- computeMerchantPublicProjection(): searchKeywords presente en el
  objeto resultante

## 14.2 Tests unitarios (Flutter — Dart)

- SearchNotifier.filterResults(): query "farm" matchea \["farmacia
  central", ...\]

- SearchNotifier.filterResults(): query con tilde "farmacía" matchea
  igual que "farmacia"

- SearchNotifier.filterResults(): filtro isOpenNow==true excluye docs
  con isOpenNow==null

- SearchNotifier.filterResults(): query \< 3 chars no aplica filtro de
  texto

- SearchNotifier.sortResults(): verified aparece antes que
  community_submitted con mismo nombre

- SearchHistoryProvider: al agregar ítem 11 se elimina el más antiguo

## 14.3 Tests de integración (emuladores Firebase)

- Query merchant_public con zoneId real: retorna solo docs de esa zona

- Filtro visibilityStatus in \[visible, review_pending\]: no retorna
  hidden ni suppressed

- Índice compuesto zoneId + categoryId + sortBoost: no falla con
  "requires index" en consola

- backfillSearchKeywords callable: requiere ADMIN claim — OWNER y anón
  reciben PermissionDenied

- ZoneSelectorSheet: query zones retorna solo status in \[pilot_enabled,
  public_enabled\]

## 14.4 Tests E2E (staging, dispositivo real)

- Flujo completo: abrir Buscar → escribir "farm" → ver sugerencias → tap
  → DETAIL-01

- Cambio de zona: seleccionar zona diferente → resultados se recargan
  correctamente

- Filtro combinado: categoryId=pharmacy + isOpenNow=true → solo
  farmacias abiertas

- Toggle mapa: resultados en lista → tap mapa → pins visibles → tap pin
  → bottom sheet → DETAIL-01

- Cold-start: zona con 0 visible + 2 review_pending → ambos aparecen con
  badge amber

- Historial: buscar "kiosco" → cerrar app → abrir → historial contiene
  "kiosco"

- Offline: desactivar wifi → abrir Buscar → error state con mensaje
  correcto → activar wifi → reintentar → resultados

# 15. Definición de Done

| **\#** | **Criterio**                                                                                                    | **Verificado por** |
|--------|-----------------------------------------------------------------------------------------------------------------|--------------------|
| D-01   | buildSearchKeywords() implementada, testeada y desplegada en dev/staging                                        | Tech Lead          |
| D-02   | backfillSearchKeywords callable ejecutado en staging — todos los merchant_public tienen searchKeywords no vacío | Tech Lead          |
| D-03   | SearchNotifier con todos los métodos implementados y testeados                                                  | Tech Lead          |
| D-04   | ZoneSelectorSheet conectado a Firestore — cero hardcode en producción                                           | Tech Lead          |
| D-05   | SEARCH-01 muestra sugerencias reales en \< 300ms con corpus precargado                                          | QA / PM            |
| D-06   | SEARCH-02 muestra los 6 estados sin datos mock                                                                  | QA / PM            |
| D-07   | Toggle lista/mapa funcional en dispositivo real                                                                 | QA / PM            |
| D-08   | Historial persiste entre sesiones                                                                               | QA                 |
| D-09   | Todos los edge cases EC-01 a EC-12 verificados en staging                                                       | QA                 |
| D-10   | Eventos de analytics disparando correctamente en DebugView de Firebase                                          | PM                 |
| D-11   | Code review aprobado por al menos 1 reviewer — sin referencias a colección merchants en el módulo search        | Tech Lead          |
| D-12   | No hay lista hardcodeada de zonas ni categorías en ningún archivo del módulo search en producción               | Tech Lead          |

# 16. Plan de Rollout

| **Fase**                           | **Acciones**                                                                                                                                              | **Gate de avance**                                                      |
|------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------|
| Fase 1 — Backend CF (dev)          | Implementar CF-01 a CF-04; desplegar en tum2-dev; ejecutar backfill en dev; verificar searchKeywords en Firestore console                                 | searchKeywords presente en 100% de docs de dev; tests CF verdes         |
| Fase 2 — Flutter core (dev)        | Implementar M-01 a M-08; conectar U-03 y U-04 (filtros y selector de zona); smoke test manual en emulador                                                 | Corpus carga correctamente; filtros mustan resultados reales            |
| Fase 3 — Flutter UI completo (dev) | Implementar U-01, U-02, U-05 a U-09; historial SharedPreferences; toggle lista/mapa; mapa básico                                                          | Todos los estados de SEARCH-01 y SEARCH-02 funcionales con datos reales |
| Fase 4 — Staging                   | Desplegar CF en staging; ejecutar backfill; desplegar app en staging; QA completo con checklist T-01 a T-15 y UX-01 a UX-12; test E2E en dispositivo real | Zero P0 bugs; todos los edge cases EC-01 a EC-12 verificados            |
| Fase 5 — Producción                | Feature flag: activar búsqueda real (Remote Config); ejecutar backfill en prod; monitor Analytics 48hs; rollback plan: desactivar feature flag            | KPI: tasa conversión búsqueda → ficha \> 40% en primeras 48hs           |

### Feature flag recomendado

Usar Firebase Remote Config con clave search_real_data_enabled: bool.
Mientras es false, SEARCH-01 y SEARCH-02 muestran el estado con datos
mock (comportamiento actual). Al activarlo en prod, el SearchNotifier
comienza a usar el corpus real. Esto permite rollback inmediato sin
redespliegue.

# 17. Estado actualizado (2026-04-03)

## 17.1 Resumen ejecutivo

- Estado general: En progreso avanzado.
- Implementacion base de backend + mobile de busqueda: Completa.
- Cierre de tarjeta al 100% (DoD): Pendiente por tests, analytics y QA de staging.

## 17.2 Subtareas por capa (estado real)

### Cloud Functions

- CF-01 buildSearchKeywords(): Completo.
- CF-02 Integracion en computeMerchantPublicProjection(): Completo.
- CF-03 Callable admin backfillSearchKeywords: Completo.
- CF-04 Unit tests de buildSearchKeywords: Pendiente.
- CF-05 Export callable en index.ts: Completo.

### Flutter datos/estado

- M-01 MerchantSearchRepository: Completo.
- M-02 SearchFilters modelo: Completo.
- M-03 SearchState (Riverpod): Completo.
- M-04 SearchNotifier (debounce/filtros/orden): Completo.
- M-05 Normalizacion y filtrado cliente: Completo.
- M-06 Orden final (sortBoost/openNow/distancia/fallback): Completo.
- M-07 Historial SharedPreferences (max 10): Completo.
- M-08 ZoneSearchRepository (zones reales): Completo.

### Flutter UI

- U-01 SEARCH-01 conectado a SearchNotifier: Completo.
- U-02 SEARCH-02 conectado a SearchNotifier: Completo (base funcional real).
- U-03 SearchFiltersSheet conectado: Completo.
- U-04 ZoneSelectorSheet con Firestore: Completo.
- U-05 Toggle lista/mapa en SEARCH-02: Completo.
- U-06 MerchantSearchCard: Completo.
- U-07 SearchEmptyState: Completo (base funcional).
- U-08 Category chips SEARCH-01/02: Completo.
- U-09 SEARCH-03 mapa basico: Parcial (vista basica; falta parity de pins/tap flow segun BDD final).

## 17.3 Checklist tecnico (estado real)

- T-01 Parcial: implementado; faltan tests CF.
- T-02 Completo.
- T-03 Completo.
- T-04 Pendiente de validacion de despliegue por ambiente.
- T-05 Completo.
- T-06 Completo.
- T-07 Completo.
- T-08 Completo.
- T-09 Completo.
- T-10 Completo.
- T-11 Completo.
- T-12 Completo (visual base).
- T-13 Completo.
- T-14 Completo.
- T-15 Completo.

## 17.4 Definicion de Done (estado real)

- D-01 Pendiente (falta bloque de tests CF y evidencia de despliegue en staging).
- D-02 Pendiente (falta ejecucion/evidencia en staging).
- D-03 Parcial (implementado; faltan tests unitarios Flutter).
- D-04 Completo.
- D-05 Parcial (implementado; falta validacion QA con metrica de tiempo).
- D-06 Parcial (implementado base real; falta cierre QA de todos los estados).
- D-07 Parcial (funciona en emulador; falta validacion en dispositivo real).
- D-08 Parcial (implementado; falta evidencia QA de persistencia entre sesiones).
- D-09 Pendiente.
- D-10 Pendiente.
- D-11 Pendiente.
- D-12 Completo (sin hardcode de zonas/categorias en el modulo search implementado).

## 17.5 Evidencia tecnica registrada

- Emuladores Firebase levantados correctamente con Functions + Firestore + Auth + Storage.
- Function `backfillSearchKeywords` cargada en emulator.
- `flutter analyze` limpio para los archivos nuevos/modificados del alcance de busqueda.
- Router actualizado para SEARCH-03 real.
- Aclaracion QA: las capturas pendientes para cierre E2E son screenshots de ejecucion real (emulador/dispositivo con datos reales), no mockups de UI.

*— Fin del documento TuM2-0056 —*
