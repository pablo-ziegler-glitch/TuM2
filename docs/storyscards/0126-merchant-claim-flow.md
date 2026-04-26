# TuM2-0126 — Flujo de claim del comercio (usuario / owner claimant)

Estado: READY_FOR_QA
Prioridad: P0 (MVP crítica)  
Épica madre: TuM2-0125 — Reclamo de titularidad de comercio

## Sync 0129 (2026-04-19)
- El paso de evidencia de mobile pasó a resolver policy canónica por `categoryId`.
- Copy y validación local ya no usan regla rígida única; distinguen `pharmacy`, `veterinary`, `fast_food`, general y fallback.

## 1. Objetivo
Diseñar y formalizar el flujo completo para que un usuario autenticado pueda reclamar la titularidad de un comercio en TuM2, aportando evidencia mínima suficiente para habilitar validación automática y, cuando corresponda, revisión manual en Admin.

Este flujo es la puerta formal de entrada al ciclo `CUSTOMER -> owner_pending -> OWNER`, sin romper reglas canónicas de seguridad, datos y costo.

## 2. Contexto
En TuM2 un comercio puede existir por importación, alta admin, sugerencia comunitaria, alta owner previa o bootstrap de datos externos. Por eso, no se puede asumir que comercio existente implique OWNER aprobado.

El dominio de claim resuelve:
- vinculación legítima de comercios sin dueño operativo asignado,
- prevención de apropiaciones indebidas,
- transición ordenada hacia capacidades OWNER,
- trazabilidad legal y operativa de decisiones.

## 3. Problema que resuelve
- Falta de camino formal para dueños reales.
- Riesgo de fraude si no hay evidencia mínima ni validaciones.
- Mezcla entre estados de reclamo y permisos efectivos.
- Baja trazabilidad de decisiones.
- Riesgo legal/reputacional por tratamiento informal de datos sensibles.

## 4. User stories de negocio
- Como usuario autenticado, quiero reclamar un comercio de forma simple para iniciar su administración.
- Como solicitante, quiero saber qué evidencia necesito según categoría.
- Como solicitante, quiero ver estado y próximo paso de mi claim.
- Como admin, quiero recibir claims prefiltrados y consistentes.
- Como plataforma, quiero separar claramente “claim enviado” de “OWNER aprobado”.

## 5. Objetivo de negocio
Maximizar simultáneamente:
- conversión legítima,
- calidad/confianza del dato,
- seguridad del proceso,
- costo operativo bajo para soporte y revisión.

## 6. Alcance IN (producto)
- Inicio del claim desde experiencias mobile/web.
- Email del claim derivado de sesión autenticada (no editable).
- Teléfono opcional en MVP sin verificación.
- Selección o identificación guiada del comercio.
- Formulario por etapas.
- Carga de evidencia mínima.
- Envío de claim y pantalla de resultado.
- Vista de estado del claim para usuario.
- Handoff a validación automática y revisión manual.
- Estados funcionales de claim y su semántica.
- Integración conceptual con `owner_pending`.

## 7. Alcance OUT (producto)
- Implementación profunda de validación automática (TuM2-0127).
- Implementación completa de revisión manual en Admin (TuM2-0128).
- Matriz exhaustiva de evidencia por categoría (TuM2-0129).
- Diseño técnico completo de cifrado/masking/auditoría (TuM2-0130).
- Lógica completa de transición de roles (TuM2-0131).
- Verificación telefónica (TuM2-0132, fase 2).
- Resolución avanzada de conflictos/disputas (TuM2-0133).

## 8. Supuestos
- Usuario autenticado al iniciar flujo.
- Email del claim = email autenticado, siempre.
- Teléfono opcional en MVP (sin verificación).
- El comercio puede existir previamente.
- El envío de claim no concede OWNER automático.
- Puede existir estado intermedio `owner_pending`.

## 9. Dependencias
Funcionales:
- TuM2-0004, 0053, 0054, 0064, 0125, 0127, 0128, 0129, 0130, 0131, 0133.

Legales:
- TuM2-0100, 0101, 0102, 0103, 0104.

## 10. Actores
- Usuario autenticado reclamante.
- Usuario `owner_pending`.
- Admin revisor.
- Sistema TuM2 (validación, derivación y seguridad).

## 11. Arquitectura funcional (producto)
Flujo recomendado:
1. Usuario inicia claim.
2. Identifica/selecciona comercio.
3. Completa datos básicos y evidencia.
4. Envía claim.
5. Sistema registra claim.
6. Validación automática inicial.
7. Si hay dudas/conflicto/riesgo, deriva a revisión manual.
8. Decisión final (`approved`/`rejected`/`needs_more_info`/otros estados).

Modelo recomendado: automático primero + manual cuando hay duda.

## 12. Flujo funcional propuesto
Paso 1 — Inicio: explicación, expectativas y reglas básicas.  
Paso 2 — Comercio: selección guiada para evitar ambigüedad.  
Paso 3 — Solicitante: email fijo de sesión, teléfono opcional, rol declarado.  
Paso 4 — Evidencia: fachada obligatoria + documento mínimo de vínculo + nota opcional.  
Paso 5 — Consentimiento y envío.  
Paso 6 — Resultado inmediato (claim enviado).  
Paso 7 — Seguimiento del estado y próximos pasos.

## 13. Pantallas y estados UX
- CLAIM-01: Introducción.
- CLAIM-02: Selección/identificación comercio.
- CLAIM-03: Datos del solicitante.
- CLAIM-04: Evidencia.
- CLAIM-05: Confirmación y consentimiento.
- CLAIM-06: Éxito / enviado.
- CLAIM-07: Estado del claim.

## 14. Frontend (definición funcional)
Principios:
- flujo corto y claro,
- mínima fricción,
- jerarquía fuerte de “qué pasa ahora / qué sigue”.

Estados críticos:
- loading,
- error de red,
- evidencia inválida/incompleta,
- comercio no identificable,
- claim ya existente/duplicado/conflicto,
- envío exitoso.

Conectividad:
- sin envíos parciales silenciosos,
- sin autosave agresivo,
- borradores controlados y explícitos.

## 15. Backend (definición funcional)
Debe registrar claim estructurado y trazable, sin promoción automática de rol.

Estados mínimos:
- `draft`
- `submitted`
- `auto_validating`
- `under_review`
- `needs_more_info`
- `approved`
- `rejected`
- `duplicate_claim`
- `conflict_detected`
- `cancelled`

Regla clave: estado de claim y estado de usuario son dominios distintos.

## 16. Seguridad (negocio)
Reglas obligatorias:
- claim solo por usuario autenticado,
- email derivado de sesión,
- usuario solo accede a claims propios,
- evidencia sensible nunca pública,
- envío de claim no concede permisos OWNER.

Separación de datos:
- revisables por humano (PII/documentos),
- comparables para antifraude sin exposición (fingerprints, `ipHash`, etc.).

## 17. Reglas de negocio detalladas
- Email del claim siempre autenticado y no editable.
- Teléfono opcional y sin verificación en MVP.
- Debe existir identificación suficiente del comercio.
- Foto de fachada obligatoria.
- Documento mínimo de vínculo obligatorio.
- Requisitos pueden variar por `categoryId`.
- Claims dudosos/conflictivos pasan a revisión manual.
- Debe existir trazabilidad temporal y de decisión.

## 18. Datos impactados
Dominios:
- `merchant_claims`,
- `users`,
- `merchants`,
- proyecciones/resúmenes de rol/claim para guards UX,
- legal/consentimientos y auditoría.

`merchant_public` solo por proyección server-side. Nunca editable desde cliente.

Campos mínimos de claim:
- `claimId`, `userId`, `authenticatedEmail`,
- `phone` (opcional), `declaredRole`,
- `merchantId` o referencia controlada,
- `categoryId`, `claimStatus`,
- `submittedAt`, `updatedAt`,
- evidencia mínima y flags de validación/conflicto.

## 19. Integración con roles y OWNER
- `CUSTOMER`: inicia y sigue claim.
- `owner_pending`: experiencia intermedia contextual.
- `OWNER`: solo tras aprobación autorizada.
- OWNER-01 (TuM2-0064) debe diferenciar sin ambigüedad:
  - sin claim,
  - claim en curso/revisión,
  - aprobado.

## 20. UX y microcopy
Tono:
- claro,
- cercano,
- confiable,
- no burocrático.

Mensajes clave:
- “Reclamá tu comercio”.
- “Usaremos el email de tu cuenta actual”.
- “Subí una foto del frente y una prueba de vínculo”.
- “Vamos a revisar tu solicitud”.
- “Todavía no tenés acceso completo al panel de tu comercio”.

## 21. Analytics y KPIs
Eventos recomendados:
- `merchant_claim_started`
- `merchant_claim_step_viewed`
- `merchant_claim_step_completed`
- `merchant_claim_evidence_uploaded`
- `merchant_claim_submitted`
- `merchant_claim_submission_failed`
- `merchant_claim_status_viewed`
- `merchant_claim_more_info_requested_viewed`

KPIs:
- inicio/finalización/abandono por paso,
- suficiencia de evidencia al primer envío,
- porcentaje aprobado sin pedido extra,
- tiempo a primera decisión,
- tasa de revisión manual,
- tasa de duplicados/conflictos.

North Star local:
- porcentaje de claims legítimos resueltos sin fricción excesiva.

## 22. Riesgos y deuda
Riesgos:
- fricción excesiva (caída de conversión),
- fricción insuficiente (fraude),
- inconsistencia claim vs rol efectivo,
- backlog admin por filtrado automático débil,
- exposición de PII.

Deuda a evitar:
- email alternativo en claim,
- asignación de OWNER acoplada a submit de claim,
- falta de separación entre sensibles revisables y fingerprints.

## 23. Edge cases
- Claim sobre comercio ya reclamado o con OWNER activo.
- Abandono antes de enviar.
- Evidencia incompleta o contradictoria.
- Múltiples claims por mismo comercio.
- Usuario `owner_pending` intentando UX de OWNER pleno.
- Solicitud de más info tras submit.
- Reintento duplicado.
- Error de red durante adjuntos o confirmación.
- Cancelación/desistimiento.

## 24. Subtareas por capa
Producto:
- cerrar journey, estados y decisiones.

Cliente (mobile/web):
- pantallas claim, formulario por pasos, evidencias, estado y errores.

Backend:
- registrar claim, validar precondiciones, crear estado inicial y handoff.

Admin:
- consumir claims derivados y habilitar seguimiento.

Seguridad/Legal/Analytics:
- políticas de PII, consentimientos, auditoría y embudo de métricas.

## 25. Checklist UX
- propósito del claim claro antes de iniciar,
- email fijo entendido,
- formulario sin redundancias,
- documentación requerida explicada sin jerga,
- post-envío claro,
- diferencia claim vs acceso OWNER explícita,
- errores accionables.

## 26. Criterios BDD / aceptación
1. Dado un usuario autenticado sin comercio vinculado, cuando inicia claim, entonces puede enviar con evidencia mínima y email autenticado.
2. Dado un usuario autenticado, cuando entra a datos personales, entonces ve email fijo no editable.
3. Dado un usuario autenticado, cuando falta fachada o prueba mínima, entonces no puede enviar.
4. Dado un claim enviado, cuando consulta estado, entonces ve estado y próximo paso de forma clara.
5. Dado un claim en revisión sin aprobación, cuando intenta acceso OWNER pleno, entonces no se concede.
6. Dado un claim en conflicto/duplicado, cuando consulta estado, entonces recibe estado claro no genérico.
7. Dado un admin, cuando revisa claim derivado, entonces encuentra información ordenada para decisión.

## 27. QA plan
QA funcional:
- flujo punta a punta, validaciones y estados.

QA UX:
- comprensión de email fijo, consentimiento y estado post-envío.

QA seguridad:
- acceso solo a claims propios, sin exposición indebida de evidencia ni permisos.

QA integración:
- auth, roles (`owner_pending`/`OWNER`), admin review y legales.

QA costo:
- sin listeners continuos,
- sin autosave agresivo,
- sin writes redundantes por navegación,
- queries acotadas para estado.

## 28. Definition of Done
La tarjeta cierra cuando:
- flujo de claim queda definido de punta a punta,
- email autenticado fijo queda canónico,
- teléfono opcional sin verificación queda cerrado para MVP,
- evidencia mínima base queda formalizada,
- estados del claim quedan formalizados,
- handoff a 0127/0128 queda definido,
- relación con `owner_pending`/`OWNER` queda documentada,
- edge cases principales quedan cubiertos,
- impactos cruzados quedan identificados sin contradicciones.

## 29. Plan de rollout
Fase 1: cierre funcional 0126 + alineación 0127/0129/0131.  
Fase 2: implementación MVP cliente + backend + admin mínima + owner_pending contextual.  
Fase 3: endurecimiento antifraude/conflicto + optimización de conversión.  
Fase 4 (futuro): verificación de teléfono y resolución avanzada.

## 30. Sincronización documental
Crear/mantener alineados:
- `docs/storyscards/0126-merchant-claim-flow.md`
- `docs/storyscards/0127-merchant-claim-auto-validation.md`
- `docs/storyscards/0128-admin-merchant-claims-review.md`
- `docs/storyscards/0129-merchant-claim-evidence-by-category.md`
- `docs/storyscards/0130-merchant-claim-sensitive-data-protection.md`
- `docs/storyscards/0131-owner-claim-role-integration.md`
- `docs/storyscards/0133-merchant-claim-conflicts-and-duplicates.md`

Actualizar por impacto cruzado:
- `docs/storyscards/0004-role-segment-architecture.md`
- `docs/storyscards/0053-mobile-shell.md`
- `docs/storyscards/0054-auth-complete.md`
- `docs/storyscards/0064-owner-module-business.md`
- `docs/storyscards/0100-privacy-policy.md`
- `docs/storyscards/0101-terms-and-conditions.md`
- `docs/storyscards/0102-claim-evidence-consent.md`
- `docs/storyscards/0103-user-rights-claims-data.md`
- `docs/storyscards/0104-sensitive-data-retention-access.md`

## 31. Guardrails de costo Firestore (crítico)
- Minimizar lecturas por claim y por comercio; prohibido scan amplio sin scope.
- Queries siempre acotadas con `limit` y filtros (`userId`, `merchantId`, `zoneId` cuando aplique, estado).
- Sin listeners globales para seguimiento de claim.
- Sin polling agresivo; refresco por acción/foco y eventos del flujo.
- Draft persistido por acción explícita (no autosave ruidoso).
- Reusar cache local con TTL para metadata estática (categorías/requisitos).
- Evitar writes redundantes de estado si no hay cambio efectivo.

## Cierre ejecutivo
TuM2-0126 formaliza el ingreso legítimo de dueños al ecosistema operativo de TuM2 y conecta identidad, evidencia, validación, revisión, seguridad y transición de rol con criterios de costo y trazabilidad.

## Estado real de implementación (corte 2026-04-16)
### Hecho
- Implementación productiva inicial completada en backend + mobile con callables `upsertMerchantClaimDraft`, `submitMerchantClaim`, `cancelMerchantClaim`, `getMyMerchantClaimStatus`, `searchClaimableMerchants`.
- Flujo mobile CLAIM-01..07 conectado a Firebase real (sin mocks), con upload de evidencia a Storage y estado de claim por callable.
- Endurecimiento de `firestore.rules` para bloquear escrituras cliente directas en `merchant_claims`.
- Reglas Storage activas para evidencia privada en `merchant-claims/{uid}/{claimId}/...`.
- Índices de `merchant_claims` actualizados para lectura por estado y por usuario.
- Pruebas ejecutadas con resultado PASS: `flutter analyze`, tests mobile nuevos y `npm test` (functions).

### Falta para cerrar
- Completar consumo funcional de historial paginado (`listMyMerchantClaims`) en UI final de usuario.
- Ejecutar y dejar verde `test:rules` con entorno Java 21+ en CI/local.
- Cerrar integración operativa completa con revisión admin (TuM2-0128) para circuito punta a punta sin pasos manuales.
- Terminar ajustes legales/copy vinculados a consentimientos y retención (TuM2-0100..0104).
