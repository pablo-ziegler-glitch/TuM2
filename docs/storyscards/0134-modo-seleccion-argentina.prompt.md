# Prompt Codex — TuM2-0134

Actuá como Staff Software Engineer / Principal Architect del proyecto TuM2 (Tu metro cuadrado), con foco en arquitectura productiva, seguridad, costo Firebase/Firestore, UX, testing y release readiness.

Quiero que implementes COMPLETA la tarjeta propuesta:

# TuM2-0134 — Modo Selección Argentina + tarjeta pineada de próximo partido

## Misión
Implementar un feature estacional, apagable por feature flags, que agregue:

1. un look and feel temático sutil “Modo Selección Argentina” en superficies públicas relevantes;
2. una tarjeta especial pineada del próximo partido de Argentina;
3. un módulo Admin Web para cargar/editar/desactivar partidos;
4. una proyección pública backend-only compacta, costo-eficiente y segura;
5. analytics, tests y documentación;
6. una post-auditoría obligatoria al final, corrigiendo lo detectado antes de cerrar.

---

# CONTEXTO CANÓNICO DEL PROYECTO

## Producto
TuM2 es una app mobile + web de comercio local hiperlocal.
Tagline: “Lo que necesitás, en tu zona.”

Rubros MVP confirmados:
- Farmacias
- Kioscos
- Almacenes
- Veterinarias
- Tiendas de comida al paso
- Casas de comida / Rotiserías
- Gomerías

Panaderías/Confiterías están EXCLUIDAS del MVP. No deben aparecer en ningún output, seed, test data, fixtures ni ejemplos de UI.

## Stack técnico
Frontend:
- Flutter Mobile
- Flutter Web pública
- Flutter Web Admin Panel

Backend:
- 100% serverless Firebase
- Firebase Auth
- Firestore
- Cloud Functions TypeScript
- Storage
- Hosting
- FCM
- Analytics
- Crashlytics
- Remote Config
- App Check

Paquetes Flutter clave:
- go_router ^13
- flutter_riverpod ^2.5
- geolocator
- url_launcher

Idioma:
- UI strings, tickets y comentarios: español
- código fuente, identificadores, archivos, clases, funciones: inglés

## Reglas no negociables
- `merchant_public` nunca se escribe desde cliente.
- Toda proyección pública la escribe backend vía Cloud Functions / Admin SDK.
- No romper el patrón dual-collection.
- No usar mocks/fakes/stubs ni datos demo hardcodeados como sustituto de integración real.
- Si una pantalla queda con mock, la tarjeta NO se considera terminada.
- Respetar el patrón de 1 tarjeta = 1 PR cohesivo.
- Minimizar costo Firestore: evitar listeners permanentes, polling agresivo, scans globales y writes redundantes.
- Feature flags obligatorias para rollback sin redeploy.
- No proponer ni usar assets, logos, emblemas ni branding oficial del torneo/FIFA. Hacer una estética inspirada en “Selección Argentina” sin sugerir asociación oficial.

## Estado relevante ya implementado
- búsqueda de comercios cerrada y productiva;
- shell mobile cerrada;
- admin panel mínimo en Flutter Web disponible;
- patrón de proyección pública + no-op write avoidance ya usado en 0067;
- analytics base existe como línea de trabajo;
- el proyecto prioriza costo de infraestructura como requisito de diseño.

## Deuda técnica conocida a NO empeorar
- no introducir jobs secuenciales innecesarios;
- no sumar lecturas extra por request si se pueden evitar;
- no dejar App Check desactivado en callables admin de staging/prod;
- no meter inconsistencias de naming fuera del canon `zoneId/categoryId`.

---

# OBJETIVO FUNCIONAL EXACTO

Implementar un feature “Modo Selección Argentina” que funcione así:

## Componente A — Look & feel estacional
En superficies públicas relevantes (al menos search results; opcionalmente home pública si ya existe una superficie equivalente):
- aplicar un estilo temático sutil con los colores de la bandera argentina;
- NO rediseñar toda la app;
- NO tocar el logo;
- NO usar gradientes ni sombras si rompen el sistema visual actual;
- diferenciar claramente la card pineada del resto de merchant cards.

## Componente B — Tarjeta pineada especial
Debe existir una sola tarjeta pineada especial del próximo partido de Argentina.

Esa tarjeta:
- NO es un comercio;
- NO participa del ranking de merchants;
- NO va al mapa como pin;
- NO vive en `merchant_public`;
- debe renderizarse arriba del listado de resultados;
- debe verse claramente distinta de una merchant card;
- debe poder desaparecer sin romper la búsqueda.

## Componente C — Admin Web
Debe existir una sección en el panel Admin para:
- activar/desactivar el modo;
- activar/desactivar visual theme;
- activar/desactivar pinned card;
- crear/editar/despublicar partidos de Argentina;
- configurar kickoffAt, stage, textos, badges, prioridad, TTLs;
- tener preview del estado visible;
- soportar la carga manual de partidos a medida que se conozcan.

## Componente D — Automatización temporal
Ejemplo de comportamiento esperado:
- si el partido es el 16/6 a las 22:00 Argentina,
- la tarjeta debe quedar pineada 5 días antes;
- al principio mostrar “Faltan N días”;
- cuando se acerque el partido, pasar a “Faltan N horas”;
- al inicio del partido, mostrar “Ya se está jugando”;
- a los 110 minutos, dejar de estar “en juego”;
- si no hay próximo partido cargado, quedar como “Finalizado” por 24 horas;
- luego desaparecer;
- si hay un próximo partido cargado y ya vigente en su ventana, debe pasar a mostrarse ese nuevo partido.

Muy importante:
- NO resolver esto con un cron que reescriba el estado cada minuto.
- El estado visible debe derivarse principalmente desde timestamps + hora actual, con mínimo costo.

---

# DECISIÓN DE ARQUITECTURA A IMPLEMENTAR

Implementar una nueva entidad separada del dominio de merchants.

## Diseño recomendado
Colecciones/documents nuevos:

### Privado admin-only
- `seasonal_events/{eventId}`
- `seasonal_configs/world_mode`

### Público read-only
- `seasonal_public/argentina_banner`

## Regla de modelado
NO modelar esta card como merchant fake.
NO escribir nada de esto en `merchant_public`.
NO mezclarlo con el ranking o la búsqueda de merchants.

## Patrón de datos
La UI pública debe leer idealmente 1 solo doc resumen:
- `seasonal_public/argentina_banner`

Ese doc debe contener:
- flags efectivas del modo;
- theme variant;
- currentEvent;
- nextEvent;
- fallbackLastEvent;
- timestamps necesarios para derivar el estado visible;
- schemaVersion;
- updatedAt.

## Justificación
Esto minimiza:
- lecturas
- índices
- complejidad de query
- latencia
- costo Firestore

Y mantiene el mismo criterio que ya usa TuM2 para proyecciones públicas backend-only.

---

# REQUERIMIENTOS DE IMPLEMENTACIÓN

## 1) Backend / Functions / Firestore

Implementar:

### A. Modelo privado `seasonal_events/{eventId}`
Campos mínimos sugeridos:
- eventId
- eventType = `argentina_match`
- status = `draft | scheduled | disabled`
- title
- subtitle
- homeTeam
- awayTeam
- opponentName
- stage = `group_stage | round_of_32 | round_of_16 | quarter_final | semi_final | final`
- kickoffAt
- pinLeadDays
- liveDurationMinutes
- finalizedTtlHours
- pinStartAt (derivado)
- liveUntilAt (derivado)
- finalizedUntilAt (derivado)
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

### B. Config privada `seasonal_configs/world_mode`
Campos mínimos:
- enabled
- themeEnabled
- pinnedCardEnabled
- showDismissOption
- defaultPinLeadDays
- defaultLiveDurationMinutes
- defaultFinalizedTtlHours
- scope = `global`
- themeVariant = `argentina_2026`
- updatedAt
- updatedByUid

### C. Proyección pública `seasonal_public/argentina_banner`
Payload mínimo:
- enabled
- themeEnabled
- pinnedCardEnabled
- themeVariant
- currentEvent
- nextEvent
- fallbackLastEvent
- updatedAt
- schemaVersion

No exponer listado completo público.

### D. Cloud Functions
Implementar backend con TypeScript para:
- validar inputs admin;
- normalizar timestamps;
- derivar `pinStartAt`, `liveUntilAt`, `finalizedUntilAt`;
- construir el doc resumen público;
- aplicar no-op write avoidance;
- emitir structured logs.

Funciones sugeridas:
- callable admin-only `upsertSeasonalEvent`
- callable admin-only `toggleWorldMode`
- callable admin-only `rebuildArgentinaBannerProjection`
- trigger `onSeasonalEventWrite`
- trigger `onSeasonalConfigWrite`

### E. Lógica temporal
NO usar cron para cambiar “faltan días / horas / live / finalizado”.
La proyección pública debe persistir tiempos.
La UI debe derivar el estado localmente.

### F. Firestore Rules
Agregar reglas para:
- `seasonal_events`: admin-only read/write
- `seasonal_configs`: admin-only read/write
- `seasonal_public`: lectura pública, escritura cliente denegada

### G. Índices
Agregar solo los índices mínimos realmente necesarios.
Si con doc resumen público no hacen falta índices extras para cliente, mejor.

---

## 2) Admin Web (Flutter Web)

Implementar un módulo real dentro del panel admin existente.

### Debe incluir
- ruta nueva dentro del AdminShell existente;
- listado de eventos estacionales;
- formulario create/edit;
- toggle global del modo;
- toggle del theme;
- toggle de pinned card;
- preview de tarjeta;
- acciones publicar / despublicar / desactivar;
- validaciones inline;
- estados loading / success / error / empty.

### Campos del formulario
- rival
- etapa
- fecha/hora de kickoff
- badge principal
- badge secundario
- CTA label
- CTA route
- pin lead days
- live duration
- finalized ttl
- prioridad
- nota interna
- publicado sí/no

### Validaciones
- no permitir kickoff vacío;
- no permitir duraciones negativas;
- no permitir dos eventos publicados activos con misma prioridad superpuesta si eso rompe la precedencia;
- warning si el modo está activo pero no hay partido futuro cargado;
- preview local sin escribir en Firestore en cada cambio de campo.

### Guardrails de costo
- listado paginado / limitado;
- sin listeners globales;
- detalle y preview on-demand;
- nada de descargar payload pesado innecesario.

---

## 3) Mobile (Flutter)

Integrar el feature en búsqueda pública existente.

### Superficie mínima obligatoria
- search results screen / listado de comercios

### Opcional si ya existe superficie equivalente y queda limpio
- home pública

### Reglas
- la card pineada debe ir arriba del listado;
- no debe participar del ranking de merchants;
- no debe entrar al mapa;
- si falla su carga, la búsqueda debe seguir funcionando normal.

### Providers / estado
Implementar algo como:
- `seasonalBannerRepository`
- `seasonalBannerProvider`
- `seasonalBannerComputedStateProvider`

### Cache / refresh
- cache local con TTL;
- refresh al abrir pantalla;
- refresh al volver foco;
- refresh manual si ya existe pull-to-refresh;
- refresh cada 15 minutos mientras la pantalla esté visible;
- refresh más frecuente SOLO en ventana crítica cercana al kickoff/live;
- evitar polling agresivo.

### Estados visibles
Implementar al menos:
- hidden
- `faltan_n_dias`
- `faltan_n_horas`
- `hoy_juega`
- `en_juego`
- `finalizado`

### UX
- diferenciar visualmente la special card de las merchant cards;
- microcopy clara;
- no usar solo color para comunicar estado;
- accesibilidad correcta;
- soporte responsive si reutiliza widgets en Flutter Web pública.

### Dismiss
Si es razonable y simple, agregar dismiss por sesión.
No persistir dismiss server-side salvo que ya exista patrón claro y barato.
Si no entra limpio, dejarlo fuera y documentarlo.

---

## 4) Web pública (Flutter Web pública)

Si el repo ya comparte suficiente capa de presentación/estado, integrar también la misma card en web pública donde aplique.
No rehacer una arquitectura paralela.

La implementación web debe:
- reutilizar lo máximo posible;
- soportar layout responsive;
- mantener la misma lógica temporal;
- usar el mismo doc resumen.

---

## 5) Feature Flags / Remote Config

Agregar y cablear flags reales, con defaults seguros:

- `world_mode_enabled`
- `world_mode_theme_enabled`
- `world_mode_pinned_card_enabled`
- `world_mode_dismiss_enabled`
- `world_mode_refresh_minutes`
- `world_mode_live_refresh_minutes`

La experiencia debe poder apagarse por flag sin redeploy.

---

## 6) Analytics

Implementar eventos mínimos:
- `seasonal_mode_impression`
- `seasonal_banner_impression`
- `seasonal_banner_click`
- `seasonal_banner_dismiss`
- `seasonal_banner_visible_state`
- `seasonal_admin_event_created`
- `seasonal_admin_event_published`
- `seasonal_admin_mode_toggled`

Parámetros sugeridos:
- `event_id`
- `state`
- `stage`
- `opponent`
- `surface`
- `theme_variant`

No meter analytics ruidosos o redundantes.

---

## 7) Testing

Agregar tests reales y útiles.

### Unit tests
- cálculo de estado temporal
- transición días -> horas
- transición horas -> live
- transición live -> finalizado
- expiración final
- precedencia entre current/next/fallback
- timezone Argentina

### Integration tests
- crear evento admin -> proyección pública actualizada
- toggle mode off -> ocultar banner
- edición de kickoff -> cambia proyección
- no-op write avoidance -> no reescribe si payload efectivo no cambia
- validaciones rechazan payload inválido

### Rules tests
- anonymous puede leer `seasonal_public`
- anonymous no puede escribir `seasonal_public`
- customer no puede escribir privado
- admin sí puede escribir privado

### Flutter widget/integration tests
- banner visible con data válida
- banner oculto con modo apagado
- búsqueda no se rompe si el banner falla
- card arriba del listado
- estados visuales correctos

### Si existe test harness E2E
- cubrir al menos el flujo crítico de admin create/publish + render en búsqueda

---

## 8) Seguridad

Aplicar:
- validación server-side estricta
- whitelist de campos
- sanitización de textos
- validación de rutas/URLs
- no HTML arbitrario
- no markdown externo renderizado
- App Check activo para callables admin en staging/prod
- structured logs
- sin exposición pública de datos admin innecesarios

---

## 9) Look & feel / diseño

Hacer un look estacional sutil:
- filete/borde celeste-blanco-celeste;
- badge `SELECCIÓN`, `PRÓXIMO PARTIDO`, `HOY`, `EN JUEGO`, `FINALIZADO`, etc.;
- estética compatible con el design system actual;
- sin romper flat vector / sin gradientes / sin sombras si eso choca con TuM2;
- NO usar assets oficiales ni elementos que sugieran branding oficial del torneo.

---

# OUTPUT ESPERADO DE TU TRABAJO

## Tu tarea NO es solo proponer.
Tu tarea es IMPLEMENTAR en el repo una versión completa, coherente y productiva.

## Debés:
1. inspeccionar el repo y localizar la mejor integración posible;
2. diseñar la implementación exacta en los archivos correctos;
3. aplicar cambios reales;
4. agregar tests;
5. actualizar documentación;
6. ejecutar validaciones;
7. hacer post-auditoría;
8. corregir lo encontrado en la post-auditoría;
9. entregar un resumen final sólido.

---

# RESTRICCIONES DE CALIDAD

- No inventes paths si ya existe un patrón claro en el repo.
- No dupliques lógica si ya existe infraestructura reusable.
- No metas abstracciones sobreingenierizadas.
- No rompas navegación existente.
- No metas cron o polling caro si no hace falta.
- No generes deuda innecesaria.
- No mezcles esta card con merchants.
- No uses mocks.
- No incluyas panaderías/confiterías en ejemplos o fixtures.
- No agregues código muerto.
- No dejes TODOs vagos salvo que sean estrictamente fuera de alcance y estén documentados con motivo real.

---

# DOCUMENTACIÓN OBLIGATORIA A ACTUALIZAR

Actualizar como mínimo:
- `docs/storyscards/0134-modo-seleccion-argentina.md` (crear si no existe)
- `CLAUDE.md` con estado real y registro operativo reciente
- cualquier doc técnico adicional si el repo lo exige

La documentación debe quedar en español.

---

# FLUJO DE EJECUCIÓN OBLIGATORIO

## Fase 1 — Discovery técnico
Primero inspeccioná:
- estructura de búsqueda;
- providers/repositorios de search;
- integración Remote Config;
- Analytics;
- AdminShell/routes;
- Cloud Functions patterns;
- Rules/tests existentes;
- patrones de proyección pública y no-op write avoidance;
- tests existentes de features similares.

## Fase 2 — Diseño de implementación
Antes de tocar mucho código, definí:
- modelo exacto;
- paths de archivos;
- funciones nuevas;
- providers nuevos;
- rutas nuevas admin;
- estrategia de tests;
- rollout seguro.

## Fase 3 — Implementación
Aplicá los cambios reales.

## Fase 4 — Validación técnica
Ejecutá lo que corresponda según stack/repo, por ejemplo:
- analyze/lint
- unit tests
- integration/widget tests
- tests de functions
- tests de rules si existen
- build/check focalizado

No hace falta correr comandos innecesarios o prohibitivamente lentos si el repo no lo soporta localmente, pero sí una validación seria.

## Fase 5 — Post-auditoría obligatoria
Después de implementar, hacé una auditoría crítica de tu propio trabajo.

Debés revisar:
- arquitectura
- seguridad
- reglas Firestore
- auth/authz
- costo Firestore
- writes redundantes
- UX
- accesibilidad
- edge cases temporales
- testing insuficiente
- rollback / flags
- naming / consistencia
- deuda técnica creada

### Regla obligatoria
Si detectás problemas en tu propia implementación, CORREGILOS antes de cerrar.
No te limites a listarlos.

---

# CHECKLIST DE POST-AUDITORÍA QUE DEBÉS EJECUTAR Y REPORTAR

## Arquitectura
- [ ] la card no se modela como merchant
- [ ] `merchant_public` no fue contaminado
- [ ] la proyección pública es backend-only
- [ ] no hay fan-out innecesario
- [ ] no hay cron innecesario para estados temporales

## Frontend
- [ ] la búsqueda funciona si el banner falla
- [ ] la card no participa del ranking
- [ ] la card no aparece en mapa
- [ ] accesibilidad básica correcta
- [ ] no hay jank/over-render obvio

## Backend
- [ ] validaciones server-side completas
- [ ] no-op write avoidance implementado
- [ ] logs estructurados correctos
- [ ] sin lecturas/escrituras redundantes
- [ ] reglas de precedencia temporal correctas

## Seguridad
- [ ] rules correctas
- [ ] customer/anonymous no pueden escribir privado/público indebido
- [ ] App Check contemplado para admin callables
- [ ] no se exponen datos internos innecesarios
- [ ] no hay rutas/URLs inseguras

## Costos
- [ ] 1 doc resumen público preferido
- [ ] refresh acotado con TTL
- [ ] sin listeners globales
- [ ] sin scans completos
- [ ] sin reescrituras equivalentes

## Testing
- [ ] tests unitarios relevantes
- [ ] tests de integración relevantes
- [ ] tests de rules si aplica
- [ ] casos de borde temporal cubiertos
- [ ] documentación de cualquier gap residual real

---

# FORMATO DE RESPUESTA FINAL QUE QUIERO

Al terminar, devolveme exactamente estas secciones:

## 1. Resumen ejecutivo
Qué implementaste y qué quedó operativo.

## 2. Arquitectura aplicada
Colecciones/documentos nuevos, functions, rules, Remote Config, providers y superficies tocadas.

## 3. Archivos modificados
Lista clara por capa.

## 4. Comandos ejecutados
Qué corriste para validar.

## 5. Resultado de validaciones
Qué pasó / qué falló / qué corregiste.

## 6. Post-auditoría
Hallazgos reales detectados por vos mismo y correcciones aplicadas.

## 7. Riesgos residuales
Solo los realmente pendientes.

## 8. Rollback
Cómo apagar el feature rápido y seguro.

## 9. Próximos pasos sugeridos
Solo los estrictamente útiles.

---

# CRITERIO DE ÉXITO

La tarea se considera bien hecha solo si:
- el feature queda implementado de punta a punta;
- no rompe búsqueda;
- no rompe arquitectura;
- no mete costo tonto;
- tiene flags;
- tiene tests;
- tiene docs;
- pasa una post-auditoría seria;
- queda lista para un PR cohesivo de una sola tarjeta.

Empezá inspeccionando el repo y seguí el patrón ya existente de TuM2 para features reales con proyección pública, admin web, Flutter + Riverpod + go_router, Cloud Functions TypeScript y Firestore Rules.
