# TuM2-0134 — Modo Selección Argentina + tarjeta pineada de próximo partido

Estado propuesto: TODO  
Prioridad propuesta: P1 condicional / MVP+ de lanzamiento estacional  
Tipo: Producto + Branding estacional + Mobile/Web pública + Admin Web + Backend  
Ventana objetivo: habilitable para junio 2026 si el MVP núcleo ya está estable  
Depende de: TuM2-0056, TuM2-0053, TuM2-0077, TuM2-0082, TuM2-0083, TuM2-0051  
No bloquea: release MVP core  
Feature flags obligatorias: sí

## 1. Objetivo

Incorporar un feature estacional “Modo Selección Argentina” que permita:

- aplicar un look & feel temático, sutil y apagable en superficies públicas;
- mostrar una tarjeta especial pineada del próximo partido de Argentina;
- administrar manualmente desde Admin Web los partidos de la Selección;
- cambiar automáticamente el estado visible de la tarjeta según fecha/hora configurada;
- desaparecer sin dejar ruido cuando no haya partido vigente o cuando el modo esté desactivado;
- evitar romper el modelo actual de comercios, búsqueda y proyecciones públicas.

El objetivo no es crear un módulo deportivo completo ni una experiencia editorial pesada. El objetivo es sumar una capa temporal de alto impacto visual y alto CTR con costo operativo mínimo.

## 2. Contexto

TuM2 ya tiene cerrada la búsqueda MVP, la navegación base y un portal admin mínimo; además, el proyecto ya trabaja con patrón de proyección pública, Cloud Functions como capa de sincronización y guardrails de costo para evitar escrituras redundantes y listeners innecesarios.

Esto habilita una implementación prolija si se respetan estas reglas:

- la tarjeta especial no debe modelarse como comercio;
- la información pública debe salir de una proyección o resumen backend-only;
- el estado temporal debe derivarse con la menor cantidad posible de escrituras;
- la activación/desactivación debe resolverse por flags, sin redeploy.

## 3. Problema a resolver

En una ventana estacional fuerte como el Mundial 2026, TuM2 puede capitalizar atención, recordación y tráfico si agrega una experiencia temática localmente relevante.

Hoy el producto no tiene una capa de campaña estacional reutilizable. Tampoco existe una card pineada no-comercial dentro de búsqueda que permita destacar información editorial útil y de alta atracción.

Si esto se resuelve mal, los riesgos son:

- mezclar contenido editorial con merchant_public;
- degradar ranking de búsqueda;
- sumar lecturas/escrituras innecesarias;
- introducir un branding demasiado invasivo;
- crear una solución difícil de apagar al finalizar el torneo.

## 4. Decisión de producto

La solución propuesta es un feature estacional de tres piezas:

1. Modo visual “Selección Argentina”  
   Capa de look & feel liviana, acotada a search/home/listados públicos.
2. Tarjeta pineada del próximo partido de Argentina  
   Una única card especial, separada visualmente de las merchant cards.
3. Módulo Admin Web para cargar partidos y activar/desactivar el modo  
   Gestión manual, simple y segura, con automatización temporal derivada por timestamps.

## 5. User stories

### CUSTOMER / visitante público
- Como usuario, quiero ver una tarjeta destacada del próximo partido de Argentina para sentir que la app está viva y contextual.
- Como usuario, quiero ver claramente si faltan días, horas, si el partido ya empezó o si ya finalizó.
- Como usuario, no quiero confundir esa tarjeta con un comercio real.
- Como usuario, quiero que la tarjeta desaparezca sola cuando deje de tener sentido.

### ADMIN
- Como admin, quiero poder activar o desactivar el modo estacional sin redeploy.
- Como admin, quiero cargar manualmente los partidos a medida que se conozcan.
- Como admin, quiero configurar fecha, hora, badges, textos y vigencias.
- Como admin, quiero una preview del estado resultante antes de publicar.

### Negocio / producto
- Como equipo TuM2, queremos aprovechar una oportunidad de alto interés sin comprometer arquitectura ni costos.
- Como equipo TuM2, queremos medir si esta card mejora engagement sin canibalizar clics a comercios.

## 6. Alcance IN

- Feature flag global para activar/desactivar el modo.
- Feature flag separada para tema visual.
- Feature flag separada para tarjeta pineada.
- Nueva entidad privada de eventos estacionales administrada por Admin.
- Nueva proyección pública compacta para consumo Mobile/Web.
- Tarjeta pineada única del próximo partido de Argentina.
- Estados visibles:
  - faltan_n_dias
  - faltan_n_horas
  - hoy_juega
  - en_juego
  - finalizado
  - oculto
- Badges temáticos configurables.
- Lógica de visibilidad:
  - visible 5 días antes;
  - live desde inicio del partido;
  - “finalizado” hasta 24 hs si no hay próximo partido;
  - al existir un nuevo partido con ventana activa, ese nuevo partido pasa a ser el pineado.
- Admin Web con listado, alta, edición, desactivación y preview.
- Analytics base de impresión/click/dismiss.
- TTL/cache para minimizar lecturas.
- Tests unitarios, integración y E2E focalizados.

## 7. Alcance OUT

- Resultados en vivo, marcador, minuto a minuto o estadísticas deportivas.
- Integración automática con APIs deportivas de terceros.
- Uso de assets oficiales de terceros o branding oficial del torneo.
- Múltiples tarjetas pineadas simultáneas.
- Geotargeting complejo por barrio o zona en MVP.
- Motor genérico completo de campañas para cualquier tipo de evento.
- Notificaciones push del partido.
- Modo especial dentro del panel OWNER.
- Card interactiva con compra, reservas o sponsoreo.

## 8. Supuestos y decisiones cerradas

- El feature será opt-in vía flag, no permanente.
- La tarjeta pineada será una entidad editorial, no un comercio fake.
- El estado visible se calculará principalmente en cliente a partir de timestamps, para evitar cron jobs y writes frecuentes.
- La administración de partidos será manual desde Admin Web.
- El feature debe poder apagarse sin afectar búsqueda.
- El modo visual será sutil: no se tocará el logo ni se reemplazará el branding base.
- El MVP de esta tarjeta apuntará solo a partidos de Argentina.
- El comportamiento se basa en hora Argentina (America/Argentina/Buenos_Aires).

## 9. Arquitectura propuesta

### Diagrama conceptual

```text
Admin Web
  -> seasonal_events/{eventId}          (privado)
  -> seasonal_configs/world_mode        (privado)

Cloud Functions (Admin SDK)
  -> valida + normaliza + proyecta
  -> seasonal_public/argentina_banner   (público, 1 doc resumen)

Flutter Mobile / Flutter Web pública
  -> lee seasonal_public/argentina_banner
  -> deriva estado temporal local
  -> pinea 1 card encima de resultados de búsqueda
```

### Justificación

El proyecto ya usa patrón de proyección pública server-side y write protection de colecciones públicas; además, en 0067 ya quedó establecido el patrón de cliente escribiendo solo privado y Cloud Functions sincronizando proyección con no-op write avoidance. Esta tarjeta debe seguir exactamente esa línea.

### Alternativas y trade-offs

- Alternativa A — tratar la card como merchant fake  
  Descartada. Rompe semántica, ranking, analytics, seguridad y mantenimiento.
- Alternativa B — colección seasonal_events_public y query limit(1..2)  
  Válida, simple, pero genera más complejidad de query/índices y más lecturas por pantalla.
- Alternativa C — doc resumen público único seasonal_public/argentina_banner  
  Elegida. Minimiza lecturas, evita queries e índices extra, simplifica cliente y escala mejor.

## 10. Modelo de datos propuesto

### 10.1 Colección privada: seasonal_events/{eventId}

Campos sugeridos:

- eventId
- eventType: argentina_match
- status: draft | scheduled | disabled
- title
- subtitle
- homeTeam
- awayTeam
- opponentName
- stage: group_stage | round_of_32 | round_of_16 | quarter_final | semi_final | final
- kickoffAt
- pinLeadDays
- liveDurationMinutes
- finalizedTtlHours
- pinStartAt (derivado server-side)
- liveUntilAt (derivado server-side)
- finalizedUntilAt (derivado server-side)
- primaryBadge
- secondaryBadge
- ctaLabel
- ctaRoute
- displayPriority
- isPublished
- sourceNote
- createdAt
- updatedAt
- createdByUid
- updatedByUid
- schemaVersion

### 10.2 Documento privado de config: seasonal_configs/world_mode

Campos:

- enabled
- themeEnabled
- pinnedCardEnabled
- showDismissOption
- defaultPinLeadDays
- defaultLiveDurationMinutes
- defaultFinalizedTtlHours
- scope: global
- themeVariant: argentina_2026
- updatedAt
- updatedByUid

### 10.3 Documento público compacto: seasonal_public/argentina_banner

Campos:

- enabled
- themeEnabled
- pinnedCardEnabled
- themeVariant
- currentEvent
- nextEvent
- fallbackLastEvent
- updatedAt
- schemaVersion

currentEvent / nextEvent / fallbackLastEvent incluirán solo campos mínimos:

- eventId
- title
- subtitle
- opponentName
- stage
- kickoffAt
- pinStartAt
- liveUntilAt
- finalizedUntilAt
- primaryBadge
- secondaryBadge
- ctaLabel
- ctaRoute

Regla central de costo:
No exponer listado completo de eventos al cliente público.  
El cliente público lee un solo doc y deriva estado.

## 11. Máquina de estados funcional

### Estados de visualización derivados en cliente

- hidden
  - el modo está apagado;
  - no hay partido válido;
  - no se llegó a pinStartAt;
  - se venció finalizedUntilAt.
- faltan_n_dias
  - now >= pinStartAt
  - faltan 24 hs o más para kickoffAt
- faltan_n_horas
  - falta menos de 24 hs
  - aún no llegó kickoffAt
- hoy_juega
  - mismo día calendario Argentina
  - faltan horas para inicio
- en_juego
  - now >= kickoffAt
  - now < liveUntilAt
- finalizado
  - now >= liveUntilAt
  - now < finalizedUntilAt
  - y no existe un nuevo partido más prioritario en ventana activa

### Regla de precedencia

El cliente debe elegir en este orden:

1. evento en juego;
2. próximo evento dentro de ventana de pin;
3. último evento finalizado dentro de TTL;
4. no mostrar nada.

### Regla solicitada por negocio

Si el partido inicia el 16/6 a las 22:00 Argentina:

- debe aparecer el 11/6 a las 22:00;
- debe mostrar “faltan N días” hasta entrar en ventana horaria;
- el día del partido debe pasar a “faltan N horas” / “hoy juega”;
- desde el kickoff hasta +110 min: “ya se está jugando”;
- si no hay nuevo partido cargado: “finalizado” por 24 hs;
- luego desaparece.

## 12. Look & feel propuesto

### Principios

- usar colores inspirados en bandera argentina sin romper identidad base;
- mantener diseño plano, sin sombras ni gradientes;
- no tocar logo;
- no rediseñar toda la app.

### Aplicación visual sugerida

Tarjeta especial:
- borde superior o lateral con patrón celeste-blanco-celeste;
- badge principal destacado;
- contenedor claramente distinto a merchant card;
- ícono simple temático;
- fondo neutro claro;
- CTA secundario opcional.

Merchant cards normales (solo si el modo visual está activo):
- filete superior celeste muy sutil;
- chip pequeño “Modo Selección” o badge contextual;
- nunca reemplazar badges operativos reales del comercio.

### Paleta sugerida

- base TuM2 intacta;
- acento estacional:
  - sky blue suave;
  - white;
  - navy para contraste;
- conservar #0E5BD8, #0F766E, #FF8D46, #F9F8F6 como sistema dominante.

### Accesibilidad

- no depender solo del color para estado;
- texto/badge siempre legibles;
- contraste AA mínimo;
- labels accesibles para screen readers.

## 13. Frontend — Mobile y Web pública

### Stack

- Flutter Mobile
- Flutter Web pública
- go_router
- Riverpod

### Pantallas impactadas

- SEARCH-02 resultados de búsqueda
- opcional: HOME-01 o home pública si existe superficie equivalente
- no impacta OWNER

### Comportamiento

- lectura del doc seasonal_public/argentina_banner
- cache en memoria + persistencia TTL local
- render de la tarjeta solo si hay estado visible
- la tarjeta aparece encima del listado
- no entra en ranking ni filtrado de merchants
- no participa en mapa como pin

### Estado local recomendado

Provider dedicado:
- seasonalBannerProvider
- seasonalBannerComputedStateProvider

TTL recomendado: 15 min  
refresh adicional:
- on screen focus
- on manual refresh
- cada 15 min mientras esté visible
- cada 1 min solo en ventana crítica: desde 2 hs antes hasta fin del live

### Errores

- si falla la lectura, usar último snapshot cacheado si sigue vigente;
- si no hay dato válido, no mostrar card;
- nunca bloquear búsqueda por falla del banner.

### Offline

- si hay cache reciente, usarla;
- si no, ocultar silenciosamente;
- no mostrar estados erróneos con reloj local claramente desfasado si falta dato de referencia.

### Performance

- 1 doc adicional como máximo;
- sin listeners permanentes;
- sin polling agresivo por defecto;
- reuso de widgets livianos;
- sin imágenes pesadas.

### Seguridad cliente

- no interpolar HTML;
- validar rutas deeplink internas;
- sanitizar cualquier URL externa opcional antes de abrir.

## 14. Admin Web

### Objetivo

Permitir a ADMIN gestionar la capa estacional de forma segura, rápida y sin dependencia técnica.

### Pantallas / módulos

- listado de eventos estacionales
- formulario alta/edición
- panel de configuración del modo
- preview de tarjeta resultante
- acciones:
  - crear
  - editar
  - publicar
  - despublicar
  - desactivar
  - clonar siguiente partido

### Campos del formulario

- rival
- fecha/hora kickoff
- etapa
- badges
- CTA label
- ruta/URL
- lead days
- live duration
- finalized TTL
- visibilidad
- prioridad
- nota interna

### Validaciones

- no permitir dos partidos “publicados” con misma prioridad activa superpuesta;
- no permitir kickoffAt vacío;
- no permitir valores negativos de duraciones;
- warning si el próximo partido no está cargado;
- warning si el modo está activo pero no hay card futura.

### UX admin

- preview inmediata de todos los estados:
  - faltan días
  - faltan horas
  - hoy juega
  - en juego
  - finalizado
- tabla con columnas:
  - rival
  - etapa
  - kickoff
  - estado editorial
  - publicado sí/no
  - updatedAt
- filtros simples:
  - draft
  - publicado
  - vencido
  - desactivado

### Guardrails de costo

- paginación por cursor
- limit chico
- sin listeners globales
- detalle on-demand
- preview client-side sin writes extra

## 15. Backend

### Arquitectura

Firestore como fuente de configuración y eventos.  
Cloud Functions TypeScript para:

- validar;
- normalizar;
- derivar campos temporales;
- escribir doc resumen público;
- evitar no-op writes.

### Funciones sugeridas

- upsertSeasonalEvent callable admin-only
- toggleWorldMode callable admin-only
- rebuildArgentinaBannerProjection callable admin-only/manual recovery
- trigger Firestore:
  - onSeasonalEventWrite
  - onSeasonalConfigWrite

### Lógica server-side

- calcular pinStartAt, liveUntilAt, finalizedUntilAt
- ordenar eventos publicados
- construir resumen público mínimo
- escribir solo si cambió el payload efectivo
- structured logs

Regla de oro:
No agregar cron que escriba estado cada minuto u hora.  
La transición de “faltan días / horas / en juego / finalizado” se deriva en cliente.

### Logs mínimos

- eventId
- kickoffAt
- projectionUpdated
- projectionSkipped
- reason
- modeEnabled
- pinnedCardEnabled

## 16. Firestore Rules y Auth/Authz

### Reglas

- seasonal_events: solo ADMIN write/read
- seasonal_configs: solo ADMIN write/read
- seasonal_public: solo lectura pública; escritura cliente denegada

### Auth/Authz

- no usar claims desde cliente para mutar estado público
- toda publicación pasa por backend autorizado
- en staging/prod, admin callables con App Check habilitado

### Rate limiting

- callables admin protegidas por rol
- throttling básico por UID en backend para evitar spam administrativo accidental

## 17. Seguridad

### Threat model

- cliente intentando escribir banner público;
- admin comprometido cargando texto malicioso;
- deeplink/URL maliciosa;
- desbordes por hora mal configurada;
- superposición de eventos;
- abuso de callables admin;
- regresión visual que tape señales reales de comercio.

### Controles

- seasonal_public read-only para clientes;
- sanitización de textos;
- whitelist de rutas internas;
- validación estricta de enums y timestamps;
- App Check para callables admin;
- logs estructurados;
- tests de rules con emulador.

### OWASP / hardening

- no HTML renderizado;
- no inyección de markdown externo;
- validación server-side completa;
- no confiar en hora enviada por cliente;
- no aceptar payloads arbitrarios fuera de whitelist.

## 18. UX / Microcopy

### Microcopy sugerido

- “Próximo partido de Argentina”
- “Faltan {N} días”
- “Faltan {N} horas”
- “Hoy juega Argentina”
- “Ya se está jugando”
- “Finalizado”
- “Modo Selección activo”

### Badges sugeridos

- SELECCIÓN
- PRÓXIMO PARTIDO
- HOY
- EN JUEGO
- FINALIZADO
- FASE DE GRUPOS
- OCTAVOS
- CUARTOS
- SEMIFINAL
- FINAL

### Reglas UX

- 1 sola card pineada;
- diferencia visual clara respecto de comercio;
- no desplazar señales operativas críticas del comercio;
- permitir dismiss por sesión si negocio lo aprueba;
- no mostrar “finalizado” más de 24 hs.

## 19. Analytics + KPI

### Eventos

- seasonal_mode_impression
- seasonal_banner_impression
- seasonal_banner_click
- seasonal_banner_dismiss
- seasonal_banner_visible_state
- seasonal_theme_enabled
- seasonal_admin_event_created
- seasonal_admin_event_published
- seasonal_admin_mode_toggled

### Parámetros

- event_id
- state
- stage
- opponent
- surface
- theme_variant

### KPI North Star

uplift de CTR en búsqueda sin degradar clicks a merchants

### Métricas secundarias

- ratio de impresiones con banner vs sin banner
- CTR del banner
- impacto en click-through a merchants
- dismiss rate
- errores de carga del banner
- cobertura temporal correcta

## 20. Edge cases

- partido cargado con hora incorrecta;
- admin publica 2 partidos superpuestos;
- no hay próximo partido y el actual vence;
- hay próximo partido pero todavía no entra en ventana;
- usuario con reloj del dispositivo incorrecto;
- caída de red al abrir búsqueda;
- cache vieja y modo ya apagado;
- cambio manual de config en medio del partido;
- partido deshabilitado a último momento;
- mismo día con múltiples eventos cargados por error.

Resolución propuesta:

- validaciones server-side duras;
- fallback a ocultar antes que mostrar mal;
- TTL corto de config pública;
- admin preview obligatoria;
- rebuildProjection manual disponible.

## 21. Testing

### Unit tests

- cálculo de estado derivado
- transición días -> horas
- transición horas -> live
- transición live -> finalizado
- expiración final
- precedencia entre current/next/fallback
- timezone Argentina

### Integration tests

- admin crea evento -> se actualiza doc público
- toggle modo off -> no se muestra banner
- cambio de kickoff -> cambia proyección
- no-op write avoidance funciona
- validaciones rechazan payload inválido

### E2E

- banner visible en search
- banner invisible si modo apagado
- banner cambia copy en ventanas temporales
- dismiss por sesión
- búsqueda sigue funcionando si banner falla

### Seguridad

Rules tests:
- anonymous read seasonal_public
- anonymous deny write
- customer deny write privado
- admin allow write privado

### Carga

- validar apertura masiva de Search con doc resumen cacheable
- validar que no haya polling excesivo

## 22. DevOps / CI-CD / Observabilidad

### Entornos

- dev: dataset fake controlado pero funcional
- staging: smoke tests temporales
- prod: flags apagadas primero, luego activación gradual

### Flags Remote Config

- world_mode_enabled
- world_mode_theme_enabled
- world_mode_pinned_card_enabled
- world_mode_dismiss_enabled
- world_mode_refresh_minutes
- world_mode_live_refresh_minutes

### Pipeline

- deploy separado de rules/functions/admin/mobile
- rollback por flags antes que por redeploy

### Observabilidad

- logs backend estructurados
- Crashlytics para errores de widget/provider
- alertas si:
  - banner público queda vacío con modo activo
  - hay eventos publicados sin proyección
  - callables admin fallan por validación

## 23. Escalabilidad / Performance

### Decisión principal

Usar 1 doc resumen público en lugar de una query abierta sobre eventos.

### Beneficios

- 1 lectura máxima por superficie
- sin índice compuesto extra
- menos latencia
- menos complejidad de cliente
- más simple de cachear

### Cuellos potenciales

- refresh demasiado frecuente durante live;
- múltiples superficies leyendo el doc sin TTL;
- sobrecarga por preview admin si se persiste en cada cambio.

### Mitigación

- TTL local;
- preview admin local, sin persistencia automática;
- refresh rápido solo en ventana crítica.

## 24. Costos

### Componentes baratos

- 1 doc público resumen
- pocas escrituras admin
- triggers solo en cambios efectivos
- estado derivado en cliente

### Componentes caros a evitar

- cron de actualización por minuto
- API externa deportiva
- colección pública consultada en cada screen con varios docs
- polling continuo
- imágenes/medios pesados

Guardrail obligatorio:
Esta tarjeta debe cumplir el principio de costo que ya se aplica en TuM2: evitar fan-out, evitar listeners permanentes y evitar writes redundantes, siguiendo el patrón usado en 0067.

## 25. Riesgos / deuda / impacto cruzado

### Riesgos

- comenzar esta tarjeta antes de estabilizar P0 núcleo;
- mezclar branding estacional con identidad permanente;
- confusión del usuario entre card editorial y comercio;
- errores de horario por timezone;
- implementar una solución demasiado genérica y costosa.

### Deuda técnica a no empeorar

- no sumar jobs secuenciales de refresco temporal;
- no abrir una nueva colección pública editable por cliente;
- no introducir hardcodes de zona;
- no dejar callables admin sin App Check en staging/prod.

### Impacto cruzado

- TuM2-0056 búsqueda
- TuM2-0077 admin mínimo
- TuM2-0082/0083 analytics
- TuM2-0051 CI/CD mínimo
- potencial futura relación con TuM2-0026 badges/branding snippets, que hoy figura como Post-MVP, por lo que esta tarjeta debe resolver solo lo estrictamente necesario y no rehacer ese dominio completo.

## 26. Subtareas por capa

### Producto / UX

- definir microcopy final
- definir badges y estados
- definir visual differentiator de la card
- definir dismiss por sesión o no

### Flutter Mobile

- provider de banner
- widget de card pineada
- integración en search/home
- TTL local y refresh inteligente
- analytics

### Flutter Web pública

- mismo provider/abstracción
- render responsive
- fallback seguro

### Admin Web

- listado de eventos
- formulario crear/editar
- toggle modo
- preview
- validaciones

### Backend / Cloud Functions

- schema
- triggers
- callables admin
- builder del doc resumen
- no-op write avoidance

### Firestore / Rules

- nuevas colecciones/documents
- reglas privadas/públicas
- tests emulador

### QA

- matriz temporal
- matriz de flags
- matriz de fallas de red/cache
- regresión search

### Analytics

- definición de eventos
- instrumentación
- validación en DebugView

## 27. BDD / Gherkin

```gherkin
Feature: Tarjeta pineada del próximo partido de Argentina

  Scenario: El partido entra en ventana de pin 5 días antes
    Given existe un partido publicado de Argentina con kickoffAt válido
    And faltan exactamente 5 días para el kickoff
    When el usuario abre la búsqueda
    Then ve una tarjeta pineada del partido
    And el estado visible indica "Faltan N días"

  Scenario: El partido se acerca el mismo día
    Given existe un partido publicado para hoy
    When el usuario abre la búsqueda horas antes del kickoff
    Then ve la tarjeta pineada
    And el estado visible indica "Faltan N horas" o "Hoy juega"

  Scenario: El partido ya comenzó
    Given el reloj actual está entre kickoffAt y liveUntilAt
    When el usuario abre la búsqueda
    Then ve la tarjeta pineada
    And el estado visible indica "Ya se está jugando"

  Scenario: El partido finalizó y no existe uno nuevo cargado
    Given el reloj actual es posterior a liveUntilAt
    And no hay próximo partido publicado vigente
    When el usuario abre la búsqueda
    Then ve la tarjeta con estado "Finalizado"
    And la tarjeta expira en finalizedUntilAt

  Scenario: Existe un próximo partido más relevante
    Given el partido anterior ya finalizó
    And existe un nuevo partido dentro de su ventana de pin
    When el usuario abre la búsqueda
    Then el sistema pinea el nuevo partido
    And no muestra el partido anterior

  Scenario: El modo está desactivado
    Given world_mode_enabled es false
    When el usuario abre la búsqueda
    Then no ve la tarjeta pineada
    And la búsqueda de comercios funciona normal
```

## 28. Definition of Done

La tarjeta se considera cerrada solo si:

- existe un flujo admin funcional y real, sin mocks;
- el banner público sale de backend-only;
- el cliente no escribe colecciones públicas;
- la card no se modela como merchant;
- la visual cambia por flags;
- el estado temporal cambia correctamente con hora Argentina;
- la búsqueda sigue funcionando si el banner falla;
- analytics básicos están operativos;
- rules y tests críticos están en verde;
- staging/prod pueden apagar el feature sin redeploy.

## 29. Checklist final de producción

- nueva entidad privada seasonal_events
- config privada seasonal_configs/world_mode
- doc público seasonal_public/argentina_banner
- cliente sin writes públicos
- no-op write avoidance en proyección
- timezone Argentina validada
- card claramente distinta de merchant card
- no aparece en mapa ni ranking
- flags Remote Config operativas
- App Check en callables admin
- tests rules + unit + integración + E2E
- analytics validados
- rollback por flag probado
- sin uso de branding externo no validado
- documentación actualizada en docs/storyscards/0134-... y CLAUDE.md

## 30. Recomendación ejecutiva

Esta tarjeta sí conviene, pero solo en versión acotada y costo-optimizada.  
No la trataría como P0 de MVP core. La trataría como:

- P1 condicional de lanzamiento
- activable si búsqueda, admin y release readiness están estables
- acotada a una sola card y un solo doc público resumen
