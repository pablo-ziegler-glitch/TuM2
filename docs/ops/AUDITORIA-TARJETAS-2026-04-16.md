# Auditoría de tarjetas TuM2 (corte 2026-04-16)

## 1) Fuente de verdad y método

- **Fuente canónica de estado:** `CLAUDE.md` (regla explícita del repositorio).
- **Contraste documental:** `docs/storyscards/*.md`.
- **Contraste técnico real:** lectura de código en `functions/src`, `mobile/lib`, `web/lib`.
- **Criterio de costo Firestore aplicado en esta auditoría:** toda planificación propuesta exige queries con scope, `limit`/paginación real, cero listeners globales y evitar writes redundantes.

---

## 2) Snapshot ejecutivo global

### Backlog maestro (133 tarjetas)

| Métrica | Valor |
|---|---:|
| Total tarjetas | 133 |
| `DONE` | 48 |
| `IN_PROGRESS` | 8 |
| `TODO` | 77 |
| P0 abiertas (`IN_PROGRESS`+`TODO`) | 35 |
| P1 abiertas (`TODO`) | 28 |
| P2 abiertas (`TODO`) | 17 |
| P3 abiertas (`TODO`) | 5 |

### Frentes abiertos (tarjetas no cerradas)

| Frente | Abiertas |
|---|---:|
| Backend / Data / Seguridad / Operaciones / Auth | 40 |
| Frontend (Mobile/Web/Admin) | 33 |
| UX / Producto / Branding / Legal / Growth | 48 |
| Analytics / QA / Lanzamiento / Monetización | 28 |

---

## 3) Clasificación solicitada por estado operativo

> Esta clasificación está aterrizada sobre las storycards activas del repo (29 archivos en `docs/storyscards/`), usando estado canónico + evidencia técnica.

| Estado operativo | Cantidad | Tarjetas |
|---|---:|---|
| **Completadas** | 9 | 0054.md, 0056, 0057, 0066, 0067-tecnico, 0067-especificación, 0068, 0123, 0124 |
| **Comenzadas** (ya trabajadas pero sin cierre limpio documental/canónico) | 9 | 0004, 0053, 0054-auth-complete, 0065, 0100, 0101, 0102, 0103, 0104 |
| **En progreso** (canónico `IN_PROGRESS`) | 8 | 0064, 0125, 0126, 0127, 0128, 0130, 0131, 0133 |
| **Sin iniciar real** | 3 | 0081, 0129, 0132 |

---

## 4) Evidencia técnica verificada (estado real de implementación)

- **Claims backend y workflow base implementados** en [functions/src/callables/merchantClaims.ts](/home/pablo/IdeaProjects/TuM2/functions/src/callables/merchantClaims.ts) con callables de draft, submit, evaluación, resolución, reveal sensible y listados paginados por `zoneId`+`status`.
- **Claims mobile implementado** en [mobile/lib/modules/merchant_claim/screens/merchant_claim_flow_screens.dart](/home/pablo/IdeaProjects/TuM2/mobile/lib/modules/merchant_claim/screens/merchant_claim_flow_screens.dart) y [mobile/lib/modules/merchant_claim/application/merchant_claim_flow_controller.dart](/home/pablo/IdeaProjects/TuM2/mobile/lib/modules/merchant_claim/application/merchant_claim_flow_controller.dart).
- **owner_pending integrado** en Auth/Router/Owner panel: [mobile/lib/core/auth/auth_notifier.dart](/home/pablo/IdeaProjects/TuM2/mobile/lib/core/auth/auth_notifier.dart), [mobile/lib/core/router/router_guards.dart](/home/pablo/IdeaProjects/TuM2/mobile/lib/core/router/router_guards.dart), [mobile/lib/modules/owner/screens/owner_panel_screen.dart](/home/pablo/IdeaProjects/TuM2/mobile/lib/modules/owner/screens/owner_panel_screen.dart), [functions/src/triggers/claims.ts](/home/pablo/IdeaProjects/TuM2/functions/src/triggers/claims.ts).
- **Protección de sensibles implementada parcialmente** (vault cifrado + fingerprint + reveal auditado) en [functions/src/lib/claimSensitive.ts](/home/pablo/IdeaProjects/TuM2/functions/src/lib/claimSensitive.ts).
- **Admin claims UI NO implementada todavía**: no hay módulos `claim` en `web/lib` al corte.
- **0065 productos con evidencia de implementación** en mobile/functions/rules: [mobile/lib/modules/owner/screens/owner_products_screen.dart](/home/pablo/IdeaProjects/TuM2/mobile/lib/modules/owner/screens/owner_products_screen.dart), [functions/src/callables/catalogLimits.ts](/home/pablo/IdeaProjects/TuM2/functions/src/callables/catalogLimits.ts), [firestore.rules](/home/pablo/IdeaProjects/TuM2/firestore.rules).

---

## 5) Matriz por tarjeta activa (Backend / Frontend / UX-Legal + partes chicas)

| Tarjeta | Estado canónico | Backend | Frontend | UX/Legal | Partes chicas sugeridas |
|---|---|---|---|---|---|
| 0004 | DONE (con update requerido) | Ajustar contrato final `claimStatus`↔`roleStatus` en doc canónico | Validar guards contra transiciones en sesión viva | Microcopy final pending/owner | 1) cerrar matriz estado-permisos, 2) test de regresión de acceso, 3) cerrar documentación cruzada |
| 0053 | DONE (con update requerido) | Sin cambios mayores de dominio | Shell pending ya existe; falta hardening de edge cases | Afinar mensajes de revisión especial | 1) QA rutas `/owner/*` en pending, 2) limpiar residuos pending post-cierre, 3) sincronizar storycard con estado real |
| 0054 | DONE (con update requerido) | Revisar fallback Firestore solo cuando falten claims (costo) | Auth ya resuelve pending/owner | Ajuste copy post-login por estado | 1) medir frecuencia de fallback, 2) reducir lecturas en splash, 3) cierre documental |
| 0064 | IN_PROGRESS | Consolidar contrato owner_pending en backend | OWNER-02 pending implementado; falta cierre de casos límite | Claridad pending vs owner pleno | 1) matriz de permisos por submódulo owner, 2) QA de more-info/conflict, 3) cerrar criteria DoD |
| 0065 | TODO (con evidencia de implementación) | Callables y rules presentes | Screens owner products/form presentes | Falta cierre formal de tarjeta | 1) corrida QA final, 2) evidencia de tests/analytics, 3) decidir cierre canónico en `CLAUDE.md` |
| 0081 | TODO | Definir restricciones de edición por `owner_pending` | Implementar en admin/perfil | Ajustar mensajes de perfil en revisión | 1) matriz editable por estado, 2) UI de revisión, 3) QA permisos |
| 0100 | TODO (doc avanzada) | Mapear reglas reales de privacidad a implementación claims | Insertar enlaces/consentimiento en flujo | Texto legal final publicable | 1) congelar versión legal, 2) validar contra flujo real, 3) preparar publicación |
| 0101 | TODO (doc avanzada) | Alinear medidas de moderación/restricción con backend | Exponer T&C en punto de envío claim | Texto contractual final | 1) cerrar cláusulas no-approval/fraude, 2) validar copy UX, 3) checklist legal release |
| 0102 | TODO (doc avanzada) | Trazabilidad de consentimiento por envío | UI de consentimiento ya debe quedar previa a submit | Texto claro y no ambiguo | 1) confirmar evento de aceptación, 2) reforzar copy por categoría, 3) cierre legal |
| 0103 | TODO (doc avanzada) | Backend para corrección/desistimiento con trazabilidad | Pantallas de derechos/acciones del claim | Política de límites de eliminación | 1) definir canal y SLA, 2) UX de solicitud, 3) reglas de excepción por seguridad |
| 0104 | TODO (doc avanzada) | Definir retención y cleanup operativo | Admin: masking/reveal con límites de export | Política final de acceso interno | 1) plazos concretos por estado, 2) job cleanup + auditoría, 3) aprobación legal |
| 0125 | IN_PROGRESS | Orquestación global de épica claims | Coordinar móvil/admin como entregable único | Cierre de alcance y dependencias | 1) congelar mapa de hijas, 2) definir gate de release, 3) tablero único de avance |
| 0126 | IN_PROGRESS | Backend base claim funcional | Mobile claim wizard funcional | Falta cierre UX por categoría (0129) | 1) conectar matriz de evidencia por categoría, 2) completar QA e2e/rules, 3) cerrar doc de rollout |
| 0127 | IN_PROGRESS | Auto-validación implementada, falta externalizar política por categoría | Estado usuario ya expuesto en mobile | Afinar motivos y outcomes visibles | 1) policy engine por `categoryId`, 2) telemetría de falsos positivos, 3) QA costo (sin scans) |
| 0128 | IN_PROGRESS | Callables admin review list/resolve/reveal disponibles | **Falta UI web admin de claims** | Definir flujo de triage/revisión | 1) cola paginada por `zoneId+status`, 2) detalle con masking/reveal temporal, 3) acciones con reason codes |
| 0129 | TODO | Definir política canónica de evidencia por categoría | Ajustar formularios/copy dinámico por rubro | Matriz UX de evidencia por categoría | 1) JSON policy versionada, 2) integración en mobile+backend, 3) QA por rubro |
| 0130 | IN_PROGRESS | Cifrado/fingerprint/reveal ya existen; falta hardening de claves y retención | Admin aún sin UI para reveal auditado | Cierre legal-operativo de sensibilidad | 1) gestión de keys segura, 2) UI audit trail de reveals, 3) alinear con 0104 cleanup |
| 0131 | IN_PROGRESS | Sync de `owner_pending` ya existe | Guards/auth/owner pending ya implementados | Afinar journeys de transición | 1) pruebas de transición approve/reject en sesión viva, 2) limpieza estados residuales, 3) cierre documental |
| 0132 | TODO (Post-MVP) | Diseñar OTP + rate-limit + storage estado | UI perfil para verify phone | Definir cuándo se vuelve requisito | 1) diseño técnico costo-eficiente, 2) feature flag fase 2, 3) legal/privacidad de teléfono |
| 0133 | IN_PROGRESS | Dedupe/conflict en backend implementado base | Falta carril admin de resolución completa | Copy de conflicto y cierre seguro | 1) tablero de disputas admin, 2) reglas de resolución auditables, 3) QA concurrencia |

---

## 6) Estado de sincronización documental

### Resultado del saneamiento (2026-04-16)

- Drift de estado entre `CLAUDE.md` y storycards: **RESUELTO**.
- Storycards normalizadas a estado canónico (`DONE`, `IN_PROGRESS`, `TODO`).
- Storycards que no tenían estado explícito ya quedaron con `Estado` inicial:
  - 0056 (`DONE`)
  - 0065 (`TODO`)
  - 0067-tecnico (`DONE`)
  - TuM2-0067 (`DONE`)

### Nota de seguimiento

- **0065** sigue canónicamente en `TODO` (por `CLAUDE.md`) aunque tiene alcance técnico implementado documentado.
- Recomendación operativa: cierre QA + evidencia de release para decidir promoción a `DONE` en el backlog canónico.

---

## 7) Inventario abierto P0/P1 (63 tarjetas) con marca de frente

Leyenda: `B` Backend/Data/Seguridad/Auth/Ops, `F` Frontend (Mobile/Web/Admin), `U` UX/Producto/Legal/Branding/Growth.

### 7.1 En progreso (8)

- 0064 (P0, IN_PROGRESS) [BF-] Implementar módulo OWNER
- 0125 (P0, IN_PROGRESS) [BFU] Épica: Reclamo de titularidad de comercio
- 0126 (P0, IN_PROGRESS) [-FU] Flujo de claim del comercio (usuario/owner)
- 0127 (P0, IN_PROGRESS) [B--] Validación automática inicial de claims
- 0128 (P0, IN_PROGRESS) [BF-] Revisión manual de claims en Admin Web
- 0130 (P0, IN_PROGRESS) [BF-] Seguridad y protección de datos sensibles en claims
- 0131 (P0, IN_PROGRESS) [BFU] Integración de claim con roles OWNER / owner_pending / aprobación
- 0133 (P0, IN_PROGRESS) [BF-] Conflictos, duplicados y disputa de titularidad

### 7.2 Sin iniciar (55)

- 0002 (P1, TODO) [--U] Definir claim principal de marca
- 0008 (P1, TODO) [B-U] Mantener actualizado ROADMAP.md
- 0009 (P1, TODO) [B-U] Mantener actualizado PROMPT-PLAYBOOK.md
- 0011 (P0, TODO) [--U] Diseñar logo principal
- 0012 (P0, TODO) [-FU] Diseñar app icon
- 0013 (P1, TODO) [--U] Definir sistema de sellos
- 0015 (P0, TODO) [B-U] Relevar rubros prioritarios
- 0016 (P0, TODO) [B-U] Relevar caso farmacias de turno
- 0017 (P0, TODO) [B-U] Relevar señales operativas por rubro
- 0018 (P1, TODO) [B-U] Relevar flujo real del dueño
- 0025 (P1, TODO) [BFU] Diseñar modelo de propuestas y votos
- 0032 (P1, TODO) [--U] Diseñar pantalla Mapa
- 0034 (P1, TODO) [--U] Diseñar ficha de producto
- 0038 (P0, TODO) [B-U] Diseñar flujo carga de productos
- 0039 (P0, TODO) [B-U] Diseñar flujo carga de horarios y señales
- 0040 (P0, TODO) [B-U] Diseñar flujo carga de turnos de farmacia
- 0041 (P1, TODO) [-FU] Diseñar board de propuestas y votos
- 0051 (P1, TODO) [BF-] Configurar CI/CD técnico mínimo
- 0055 (P1, TODO) [-FU] Implementar home CUSTOMER
- 0065 (P0, TODO) [-F-] Implementar alta/edición de productos
- 0069 (P1, TODO) [-FU] Implementar módulo de propuestas y votos
- 0070 (P1, TODO) [-F-] Crear web pública base
- 0071 (P1, TODO) [-FU] Implementar landing principal
- 0072 (P0, TODO) [-F-] Implementar ficha pública de comercio web
- 0074 (P0, TODO) [BF-] Implementar landing Farmacias de turno web
- 0075 (P0, TODO) [-F-] Implementar landing Abierto ahora web
- 0076 (P1, TODO) [-FU] Implementar links compartibles
- 0080 (P1, TODO) [BF-] Implementar moderación de contenido
- 0081 (P1, TODO) [BF-] Implementar revisión de señales operativas reportadas
- 0082 (P0, TODO) [--U] Definir eventos analytics
- 0083 (P0, TODO) [-F-] Implementar tracking base
- 0084 (P1, TODO) [---] Crear dashboard MVP
- 0085 (P1, TODO) [B--] Medir activación OWNER
- 0086 (P1, TODO) [---] Medir activación CUSTOMER
- 0087 (P0, TODO) [--U] Medir uso de señales operativas
- 0088 (P1, TODO) [B--] Configurar App Check
- 0089 (P1, TODO) [B--] Configurar Crashlytics
- 0090 (P0, TODO) [---] Crear checklist QA MVP
- 0091 (P0, TODO) [B--] Testear permisos por rol
- 0092 (P0, TODO) [B--] Testear edge cases operativos
- 0093 (P1, TODO) [B--] Configurar alertas técnicas mínimas
- 0094 (P0, TODO) [--U] Definir piloto geográfico
- 0095 (P0, TODO) [--U] Definir rubros iniciales de salida
- 0096 (P1, TODO) [B-U] Armar material de onboarding para comercios
- 0097 (P0, TODO) [B-U] Armar material para captar primeras farmacias
- 0098 (P1, TODO) [-F-] Preparar publicación beta
- 0099 (P1, TODO) [-FU] Preparar metadata de stores y canales
- 0100 (P0, TODO) [B-U] Redactar política de privacidad
- 0101 (P0, TODO) [--U] Redactar términos y condiciones
- 0102 (P0, TODO) [B-U] Definir consentimiento y tratamiento de evidencia documental (claims)
- 0103 (P0, TODO) [B-U] Definir derechos de rectificación/eliminación/revisión de datos de claim
- 0104 (P0, TODO) [BFU] Definir política de retención, acceso interno y resguardo de datos sensibles
- 0105 (P1, TODO) [--U] Diseñar sistema de propuestas y votos usable
- 0129 (P0, TODO) [B-U] Evidencia y documentación por categoría de comercio
- 0132 (P1, TODO) [B--] Verificación de teléfono del usuario para fase 2

---

## 8) Plan de ejecución en partes chicas (secuencial y medible)

## Lote A — Cierre técnico claims (2 semanas)

- Backend:
  - Cerrar 0127 + 0133 con policy por categoría y motivos estructurados.
  - Mantener queries con scope (`zoneId`, `claimStatus`) y paginación por cursor.
- Frontend mobile:
  - Cerrar 0126 con copy dinámico por categoría (insumo 0129).
- UX/Producto:
  - Validar estados visibles (`under_review`, `needs_more_info`, `conflict_detected`, `duplicate_claim`).

## Lote B — Admin review real (2 semanas)

- Backend:
  - Ajustes finales en callables de review/reveal si hay gaps de filtros.
- Frontend web/admin:
  - Implementar cola 0128 (listado paginado + filtros + detalle + resolver).
  - Sin listeners globales de claims; refresh por acción/paginación.
- UX:
  - Microcopy de revisión y conflicto sin fuga de datos.

## Lote C — Seguridad y retención (1-2 semanas)

- Backend:
  - Hardening de llaves de `claimSensitive` + política de rotación.
  - Definir cleanup/retención alineado a 0104.
- Admin:
  - Historial de reveals y auditoría mínima visible.

## Lote D — Legal y go-live (1 semana)

- 0100, 0101, 0102, 0103, 0104 a versión final publicable.
- Vincular textos en puntos reales del flujo (claim submit, perfil, estado claim).

## Lote E — QA/observabilidad y cierre canónico (1 semana)

- QA:
  - Permisos por rol, edge cases pending/owner, concurrencia de review.
- Observabilidad:
  - Eventos 0082/0083/0087 para embudo de claims.
- Documentación:
  - Mantener alineación sin drift entre storycards y `CLAUDE.md`.

---

## 9) Riesgos si reaparece drift documental

- Lectura ejecutiva engañosa (tarjetas técnicamente avanzadas marcadas como `TODO` en algunos documentos).
- Priorización errónea de sprint por falta de estado canónico unificado.
- Riesgo de sobrecosto por rediseños duplicados en claims si no se cierra 0128/0129 como carriles formales.

---

## 10) Próxima actualización recomendada

- Re-corte semanal con el mismo formato.
- Actualizar en conjunto: `CLAUDE.md` + este documento + `docs/ROADMAP.md`.
