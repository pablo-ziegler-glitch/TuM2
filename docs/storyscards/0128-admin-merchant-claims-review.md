# TuM2-0128 — Revisión manual de claims en Admin Web

Estado: IN_PROGRESS  
Prioridad: P0 (MVP crítica)  
Épica madre: TuM2-0125 — Reclamo de titularidad de comercio  
Depende de: TuM2-0126 — Flujo de claim del comercio, TuM2-0127 — Validación automática inicial de claims

## Sync 0129 (2026-04-19)
- El detalle admin muestra policy aplicada, versión, strictness, suficiencia, faltantes y razones de revisión manual en la misma vista del claim.
- Se mantiene carga lazy de metadata de evidencia; no se descargan binarios en listados.
## Estado real de implementación (corte 2026-04-17)
### Hecho
- Backend admin ya disponible para cola y decisión manual: `listMerchantClaimsForReview`, `evaluateMerchantClaim`, `resolveMerchantClaim`.
- Cola admin implementada con scope obligatorio (`zoneId` + `claimStatus`) y paginación por cursor (`createdAt` + `claimId`) para control de costo.
- Reveal sensible operativo y auditado en colección dedicada (`merchant_claim_sensitive_reveals`).
- Tests de integración cubren cola admin, paginación, reveal y rechazo de usuarios no admin.
- Admin Web implementado sobre callables backend: `/claims` + `/claims/:claimId`, listado paginado, filtros de scope, filtros locales sin lecturas extra, detalle con masking por defecto, timeline y panel de decisiones.
- Lectura directa desde cliente eliminada del detalle admin: el panel consume `getMerchantClaimReviewDetail` con payload mínimo, capabilities y token de concurrencia (`updatedAtMillis`).
- Control explícito de stale data cerrado: `evaluate`, `resolve` y `reveal` validan `expectedUpdatedAtMillis`; el backend rechaza replays stale y la UI fuerza refresh/reconciliación.
- Capability gating backend listo para reviewer/senior reviewer con fallback compatible (`admin`/`super_admin` conservan acceso pleno mientras no existan claims finos cargados en token).
- Reveal sensible endurecido: no prefetch, acción explícita, expiración visual en UI, auditoría append-only y resumen no sensible en el claim para timeline sin lecturas globales.
- Suite web agregada: tests de lógica local (filtros/sort/stale/gating) y widget tests del flujo de lista/detalle/reveal.

### Falta para cerrar
- Preview/descarga segura de adjuntos sensibles todavía no cerrada; el panel expone metadata lazy y evita fetch binario por defecto.
- Falta QA E2E real con emuladores/web runner sobre reveal temporal, stale conflict multi-admin y permisos diferenciados con custom claims finos reales.
- Falta activar claims finos (`claimsReviewLevel` / `capabilities`) en operación real y completar política de asignación administrativa.

## 1. Objetivo
Definir el módulo de revisión manual de claims en Admin Web para que el equipo administrador pueda evaluar, decidir y auditar reclamos de titularidad no resolubles de forma automática con seguridad suficiente.

Debe permitir:
- aprobar,
- rechazar,
- pedir más información,
- marcar conflicto,
- escalar,
- cerrar casos con trazabilidad completa.

## 2. Contexto
El flujo claim de TuM2 en MVP:
1. usuario autenticado envía claim,
2. validación automática inicial filtra lo obvio,
3. casos ambiguos/sensibles/conflictivos pasan a revisión manual.

Este módulo no es solo “aprobar/rechazar”: requiere priorización, filtros, masking, reveal controlado y auditoría.

## 3. Problema que resuelve
- Falta resolución humana de casos ambiguos.
- Riesgo de aprobación incorrecta sin contexto completo.
- Sobreexposición de PII/documentos sensibles.
- Falta de trazabilidad de decisiones.
- Baja eficiencia operativa sin cola priorizable.
- Incoherencia entre estado de claim y transición posterior a OWNER.

## 4. Objetivo de negocio
Maximizar:
- seguridad de decisión,
- claridad operativa,
- exposición mínima de sensibles,
- velocidad razonable de resolución,
- trazabilidad auditable,
- bajo costo operativo.

## 5. Alcance IN
- Listado Admin de claims.
- Filtros y priorización.
- Vista detalle del claim.
- Resumen de comercio, solicitante y evidencia.
- Timeline del caso.
- Resultado de validación automática.
- Acciones administrativas manuales.
- Masking por defecto de sensibles.
- Reveal temporal y auditado.
- Notas/observaciones de revisión.
- Definición de handoff a roles/módulos posteriores.

## 6. Alcance OUT
- Flujo inicial del reclamante (TuM2-0126).
- Lógica automática de validación (TuM2-0127).
- Matriz detallada de evidencia por categoría (TuM2-0129).
- Diseño técnico exhaustivo de cifrado/fingerprints (TuM2-0130).
- Asignación completa OWNER/roles (TuM2-0131).
- Verificación telefónica fase 2 (TuM2-0132).
- Disputas avanzadas ampliadas (TuM2-0133).

## 7. Supuestos
- El claim ya fue creado por usuario autenticado.
- Existe validación automática previa.
- Habrá claims que necesariamente requieren revisión humana.
- La aprobación impacta luego en roles/permisos.
- Se necesita auditoría de acciones y reveals.
- El módulo debe escalar a mayor volumen sin degradar operación.

## 8. Dependencias
Funcionales:
- TuM2-0126, 0127, 0129, 0130, 0131, 0133.

Cruzadas:
- TuM2-0004, 0053, 0064, 0100 a 0104.

## 9. Actores
- Admin revisor.
- Admin senior/super admin (si aplica permisos extendidos).
- Solicitante del claim (afectado por decisiones).
- Sistema TuM2 (trazabilidad, control de exposición y consistencia).

## 10. Arquitectura funcional propuesta
Modelo recomendado (MVP): dos superficies claras.
1. Listado de claims: triage/priorización/navegación.
2. Detalle de claim: revisión completa y decisión.

Evita listar PII en exceso y evita revisión fragmentada en múltiples módulos.

## 11. Flujo funcional general
1. Admin ingresa a “Claims de comercios”.
2. Visualiza listado filtrado/priorizado.
3. Abre claim específico.
4. Revisa detalle completo del caso.
5. Ejecuta acción manual.
6. Sistema registra estado, motivo, actor y timestamp.
7. Se reflejan efectos posteriores (estado usuario, handoff roles, auditoría).

## 12. Estructura del módulo
- CLAIMS-ADMIN-01: Listado de claims.
- CLAIMS-ADMIN-02: Detalle de claim.
- CLAIMS-ADMIN-03: Patrón de reveal sensible (modal/panel controlado).
- CLAIMS-ADMIN-04: Bloque de decisiones (approve/reject/more info/conflict/escalate).

## 13. CLAIMS-ADMIN-01 — Listado
Debe mostrar por fila/card:
- `claimId`,
- comercio (denominación visible),
- `categoryId`,
- `zoneId`,
- fecha de envío,
- estado actual,
- flags: conflicto, duplicado, falta info, revisión obligatoria, owner existente resumido,
- resumen de validación automática.

No mostrar en listado:
- nombre completo, email completo, teléfono completo,
- previews amplias de documentos sensibles,
- notas internas extensas.

## 14. Filtros, búsqueda y ordenamiento
Filtros recomendados:
- estado del claim,
- categoría,
- zona,
- fecha,
- conflicto/no conflicto,
- missing info,
- validación automática limpia,
- pendientes/revisados,
- owner existente,
- duplicado detectado.

Ordenamientos recomendados:
- recientes,
- más antiguos sin resolver,
- prioridad/riesgo,
- conflicto primero,
- needs_more_info primero,
- pendientes de acción primero.

Búsqueda:
- nombre de comercio,
- `claimId`,
- zona,
- referencias operativas internas sin exponer PII.

## 15. CLAIMS-ADMIN-02 — Detalle
Secciones mínimas:
- A. Resumen del caso: `claimId`, estado, fecha, categoría, zona, badges, resultado auto-validación.
- B. Comercio: nombre, dirección/referencia territorial, categoría, estado de comercio, owner/claim previo relevante.
- C. Solicitante: nombre/email/teléfono enmascarados por defecto, rol declarado.
- D. Evidencia: fachada, documento de vínculo, extras opcionales, completitud.
- E. Resultado automático: checks superados/observados y motivos de derivación.
- F. Timeline del caso.
- G. Observaciones internas.
- H. Acciones manuales.

Debe responder rápido:
- ¿Quién reclama?
- ¿Qué comercio?
- ¿Qué evidencia?
- ¿Qué validó automático?
- ¿Hay conflicto/duplicado/owner?
- ¿Falta algo?
- ¿Cuál es el riesgo?
- ¿Cuál acción corresponde?

## 16. Acciones manuales
### Aprobar
Uso: caso claro y válido.
Requiere: cambio de estado, actor, timestamp y handoff posterior controlado.

### Rechazar
Uso: caso inválido/riesgoso no recuperable.
Requiere: motivo estructurado y salida entendible para usuario.

### Pedir más información
Uso: caso potencialmente legítimo pero incompleto.
Requiere: indicar faltantes accionables y mantener caso vivo.

### Marcar conflicto
Uso: disputa o incompatibilidad real que requiere carril especial.

### Escalar
Uso: caso excede atribución del revisor o requiere intervención superior.

### Aplicar restricción funcional de seguridad
Uso: evidencia razonable de fraude, abuso, hostigamiento o uso indebido del flujo de claims/reportes.
Requiere: trazabilidad de motivo, alcance temporal/permanente, bloqueo de capacidades sensibles (claims/reportes) y criterio explícito de eventual rehabilitación por revisión autorizada.

## 17. Reglas de decisión de negocio
- Aprobar solo con evidencia/contexto suficientes.
- Rechazar cuando no sea recuperable con seguridad razonable.
- `needs_more_info` para faltantes puntuales sin conflicto severo.
- `conflict_detected` ante disputa de titularidad o colisión fuerte.
- Toda acción requiere motivo trazable.
- Evitar aprobación por “destrabar cola” y rechazo por “falta de tiempo”.
- Ante abuso/fraude razonablemente acreditado, habilitar restricción de capacidades sensibles sin expulsar necesariamente el acceso general de usuario final.

## 18. Seguridad, masking y reveal
Principio: mínima exposición.

Reglas obligatorias:
- sensibles ocultos por defecto,
- reveal solo cuando hace falta,
- reveal por rol autorizado,
- reveal temporal,
- reveal auditado,
- sin PII completa en listados,
- sin exportación masiva simple de sensibles.

Estado por defecto:
- nombre parcial,
- email parcial,
- teléfono parcial,
- documentos no visibles completos por defecto.

Auditoría de reveal:
- quién,
- cuándo,
- qué claim,
- tipo de dato revelado,
- motivo opcional.

## 19. Evidencia en Admin
Debe mostrar:
- tipo de evidencia,
- fecha de carga,
- vínculo con claim,
- preview controlada cuando aplique,
- señal de completitud.

No debe hacer por defecto:
- descargas masivas,
- render full-size de todo junto,
- exposición de metadata innecesaria.

## 20. Timeline y trazabilidad
Eventos mínimos:
- claim creado/enviado,
- validación automática ejecutada,
- derivación a revisión manual,
- pedido de más info / info recibida,
- reveal sensible,
- cambios de estado,
- decisión final (approve/reject/conflict/escalate).

## 21. Concurrencia y consistencia
Riesgos:
- dos admins deciden a la vez,
- claim cambia estado mientras está abierto,
- decisiones pisadas silenciosamente.

Requisitos:
- detectar/prevenir decisiones simultáneas inconsistentes,
- validar acciones contra estado más reciente,
- informar cambios en tiempo real razonable del caso abierto,
- no permitir sobrescritura silenciosa.

## 22. Integración con roles y OWNER
Relación con TuM2-0131:
- aprobación manual alimenta transición posterior backend-driven,
- revisar/approbar claim no equivale a habilitar OWNER desde cliente,
- mantener coherencia con `owner_pending` y módulo TuM2-0064.

## 23. Guardrails de costo Firestore
- Listado siempre paginado y con `limit`.
- Queries siempre acotadas por `claimStatus` + `zoneId` (y filtros equivalentes).
- Sin listeners permanentes sobre cola completa de `merchant_claims`.
- Carga de detalle/evidencia on-demand, no prefetch masivo.
- Reveal puntual, sin prehidratar sensibles.
- Evitar joins lógicos caros y polling agresivo.
- No leer adjuntos/binarios en listado.

## 24. UX y microcopy
Tono interno, claro y sobrio.

Copys sugeridos:
- “Pendiente de revisión”
- “Falta información”
- “Conflicto detectado”
- “Validación automática completada”
- “Revelar dato”
- “Aprobar claim”
- “Solicitar más información”

Evitar copy técnico interno (“payload inválido”, “fingerprint collision”).

## 25. Analytics y KPIs
Eventos recomendados:
- `admin_claims_list_viewed`
- `admin_claim_opened`
- `admin_claim_sensitive_revealed`
- `admin_claim_approved`
- `admin_claim_rejected`
- `admin_claim_more_info_requested`
- `admin_claim_marked_conflict`
- `admin_claim_escalated`

KPIs:
- tiempo a primera revisión,
- tiempo a decisión final,
- % claims que requieren reveal,
- distribución approve/reject/more_info/conflict,
- tasa de corrección posterior,
- claims resueltos por revisor/período.

North Star local:
% de claims resueltos correctamente con baja exposición de sensibles y tiempo operativo razonable.

## 26. Edge cases
- Doble revisión simultánea del mismo claim.
- Claim cambiado mientras el admin lo tenía abierto.
- Claim ya resuelto abierto desde navegación vieja.
- Evidencia faltante no conflictiva.
- Conflicto real entre múltiples reclamantes.
- Comercio ya vinculado a owner.
- Reveal y cambio de foco/sesión.
- Admin sin permiso para reveal o aprobar.
- `needs_more_info` repetido varias veces.
- Claim conflictivo que requiere escalamiento.

## 27. QA plan
- QA funcional: listado/filtros/detalle/acciones/timeline.
- QA seguridad: masking, reveal auditado, permisos, no PII en listado.
- QA concurrencia: doble revisión, cambios de estado en segundo plano, acciones conflictivas.
- QA costo: paginación, carga on-demand, sin prefetch innecesario.
- QA integración: coherencia con 0127, 0130, 0131, 0133 y owner_pending/OWNER.

## 28. Definition of Done
- Módulo definido con listado y detalle.
- Filtros operables para cola.
- Información suficiente y estructurada para decidir.
- Acciones manuales cerradas.
- Masking por defecto y reveal temporal auditado definidos.
- Timeline y trazabilidad completas definidas.
- Edge cases principales cubiertos.
- Impacto en roles/claim status documentado.
- Lista para implementación técnica sin contradicciones de negocio/seguridad.

## 29. Plan de rollout
Fase 1: cierre de definición con 0126/0127/0129/0130/0131.  
Fase 2: implementación MVP (listado + detalle + acciones + masking + reveal auditado básico).  
Fase 3: mejoras operativas (filtros, priorización, notas estructuradas, escalamiento).  
Fase 4: endurecimiento (permisos granulados, reveal con justificación obligatoria, reporting ampliado).

## 30. Documentos a sincronizar
Crear/mantener alineados:
- `docs/storyscards/0128-admin-merchant-claims-review.md`
- `docs/storyscards/0126-merchant-claim-flow.md`
- `docs/storyscards/0127-merchant-claim-auto-validation.md`
- `docs/storyscards/0129-merchant-claim-evidence-by-category.md`
- `docs/storyscards/0130-merchant-claim-sensitive-data-protection.md`
- `docs/storyscards/0131-owner-claim-role-integration.md`
- `docs/storyscards/0133-merchant-claim-conflicts-and-duplicates.md`

Actualizar por impacto:
- `docs/storyscards/0004-role-segment-architecture.md`
- `docs/storyscards/0064-owner-module-business.md`
- `docs/storyscards/0100-privacy-policy.md`
- `docs/storyscards/0101-terms-and-conditions.md`
- `docs/storyscards/0102-claim-evidence-consent.md`
- `docs/storyscards/0104-sensitive-data-retention-access.md`

## 31. Cierre ejecutivo
TuM2-0128 es la capa operativa que permite resolver claims de forma segura y trazable sin sobreactuar automatización.

Definición MVP:
- listado + detalle dedicados,
- contexto suficiente para decidir,
- acciones manuales claras,
- masking por defecto,
- reveal temporal y auditado,
- trazabilidad end-to-end,
- control de concurrencia,
- alineación estricta con roles, legales y protección de datos.
