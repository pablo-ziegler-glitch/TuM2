# TuM2-0127 — Validación automática inicial de claims

Estado: READY_FOR_QA
Prioridad: P0 (MVP crítica)  
Épica madre: TuM2-0125 — Reclamo de titularidad de comercio  
Depende de: TuM2-0126 — Flujo de claim del comercio

## Sync 0129 (2026-04-19)
- La validación automática ahora consume policy centralizada versionada (`merchantClaimEvidencePolicy`).
- El resultado persiste trazabilidad por claim: `evidencePolicyVersion`, `sufficiencyLevel`, `requiredEvidenceSatisfied`, `manualReviewReasons` y `riskHints`.

## Estado real de implementación (corte 2026-04-16)
### Hecho
- Motor de validación automática implementado en backend con outcomes canónicos: `under_review`, `needs_more_info`, `duplicate_claim`, `conflict_detected` (`functions/src/callables/merchantClaims.ts`).
- Integración real en submit y re-evaluación admin (`submitMerchantClaim`, `evaluateMerchantClaim`) con `reasonCode` y estados de workflow.
- Detección de duplicado por usuario+comercio con query acotada y `limit`, evitando scans amplios.
- Pruebas de integración cubren escenarios clave de validación, conflicto y duplicado (`functions/src/callables/__tests__/merchantClaims.integration.test.ts`).

### Falta para cerrar
- Extender señal de conflicto a disputa multi-actor (mismo comercio, distinto usuario) con mayor granularidad de `conflictType`.
- Completar matriz por `categoryId`/riesgo (TuM2-0129) para reglas automáticas más finas.
- Endurecer antifraude de reincidencia/abuso y su integración con restricciones funcionales.
- Publicar métricas operativas de precisión (falsos positivos/negativos) y carga manual evitada para calibrar reglas.

## 1. Objetivo
Definir la capa de validación automática inicial que corre inmediatamente después del envío de un claim para:
- bloquear casos inválidos o incompletos antes de revisión humana,
- detectar duplicados, conflictos y señales tempranas de riesgo,
- enrutar cada claim al siguiente estado correcto,
- reducir costo operativo y tiempos de respuesta,
- mantener una experiencia ágil para casos legítimos.

Esta capa no reemplaza revisión humana. Resuelve lo obvio, deriva lo ambiguo y nunca concede OWNER.

## 2. Contexto
El flujo de claim no escala con revisión manual 100%.  
Tampoco es seguro aprobar automáticamente en un dominio con disputa de titularidad, documentación sensible y permisos privilegiados.

Por eso esta tarjeta define un filtro automático obligatorio entre:
1. claim enviado por usuario autenticado,
2. revisión manual y decisión posterior.

## 3. Problema que resuelve
- Saturación de Admin por claims incompletos o inválidos.
- Latencia alta en casos simples y legítimos.
- Costo operativo innecesario por ruido administrativo.
- Menor seguridad ante duplicados, conflictos o abuso temprano.
- Mala UX cuando no hay feedback accionable rápido.

## 4. Objetivo de negocio
Maximizar simultáneamente:
- rapidez,
- confianza del claim,
- reducción de carga manual,
- protección antifraude,
- consistencia con roles/permisos,
- bajo costo Firestore/Functions.

No se busca scoring opaco ni IA decisora en MVP.

## 5. Alcance IN
- Trigger automático post-`submitted`.
- Validación de identidad básica (`auth` + email del claim).
- Validación de completitud mínima.
- Validación de evidencia mínima por base común + categoría.
- Coherencia básica claim-comercio.
- Detección de duplicado inicial.
- Detección de conflicto obvio.
- Señales tempranas de riesgo.
- Decisión inicial de estado.
- Registro de motivos estructurados y auditable.
- Handoff ordenado a revisión manual y feedback funcional para usuario/Admin.

## 6. Alcance OUT
- UX completa de formulario (TuM2-0126).
- Revisión manual detallada en Admin (TuM2-0128).
- Matriz avanzada de evidencia por categoría (TuM2-0129).
- Diseño profundo de cifrado/masking (TuM2-0130).
- Transición final a OWNER (TuM2-0131).
- Verificación telefónica fase 2 (TuM2-0132).
- Disputas avanzadas (TuM2-0133).

## 7. Supuestos
- El claim llega desde TuM2-0126.
- Usuario autenticado.
- Email del claim coincide con email autenticado.
- Teléfono opcional sin verificación en MVP.
- Existe referencia controlada a comercio objetivo.
- Existe señal de owner/claim activo/conflicto.
- Decisión automática nunca concede OWNER.
- Validación debe ser idempotente y de bajo costo.

## 8. Arquitectura funcional propuesta
Modelo: motor de reglas explícitas, acotado y auditable.

Inputs:
- identidad autenticada,
- datos del claim,
- datos mínimos del comercio,
- categoría (`categoryId`),
- evidencia cargada,
- señales de dedupe/conflicto/riesgo.

Outputs:
- estado actualizado del claim,
- motivos codificados,
- flags de riesgo/revisión/conflicto,
- trazabilidad para Admin y UX de usuario.

Alternativa recomendada MVP: reglas explícitas (no scoring complejo).

## 9. Principios rectores
- Bloquear primero lo obviamente inválido.
- Escalar a humano ante duda.
- Separar estado de claim de estado de rol.
- No mutar `merchant_public` en esta etapa.
- No otorgar permisos ni claims desde cliente.
- Usar `zoneId` y `categoryId` canónicos.
- Mantener trazabilidad clara y explicable.
- Diseñar desde costo y no desde conveniencia.

## 10. Flujo detallado de validación
1. Trigger al pasar a `submitted`.
2. Claim entra a `auto_validating`.
3. Validaciones de identidad y elegibilidad de estado.
4. Validaciones de estructura mínima.
5. Validaciones de evidencia mínima.
6. Validación de coherencia claim ↔ comercio.
7. Detección de duplicados.
8. Detección de conflictos.
9. Detección de señales de riesgo.
10. Decisión de estado + motivos.
11. Escritura idempotente de resultado y handoff.

## 11. Validaciones obligatorias
### Identidad
- Claim asociado a `userId` autenticado.
- Email del claim idéntico al email autenticado.
- Cuenta habilitada para iniciar claim.

### Completitud
- Claim no vacío.
- Comercio objetivo identificado.
- Rol declarado.
- Consentimientos aceptados.
- Evidencia base presente.

### Evidencia
- Foto de fachada obligatoria.
- Documento base de vínculo obligatorio.
- Reglas mínimas por categoría.

### Integridad de comercio
- Comercio existe o referencia controlada válida.
- Categoría no ambigua.
- Coherencia mínima entre claim y comercio.

### Deduplicación
- No duplicar claim activo del mismo usuario para mismo comercio.
- No reabrir claim equivalente sin cambio material.

### Conflicto
- Comercio con owner activo.
- Más de un claim incompatible activo.
- Colisión evidente con estado actual del comercio.

### Riesgo
- Categoría sensible.
- Inconsistencia fuerte de inputs.
- Señales de abuso o patrón anómalo.
- Reincidencia en claims/reportes improcedentes o uso malicioso de funciones sensibles.

## 12. Estados impactados (MVP)
Estados posibles post-validación:
- `under_review`
- `needs_more_info`
- `duplicate_claim`
- `conflict_detected`

Estados disponibles pero no recomendados como salida primaria MVP:
- `approved_candidate` (interno opcional)
- `rejected` (solo casos muy claros y severos)
- `cancelled` (si deja de ser elegible por estado previo)

## 13. Decisiones permitidas vs no permitidas
Permitidas:
- pedir más información,
- marcar duplicado,
- marcar conflicto,
- derivar a revisión manual,
- etiquetar riesgo/prioridad.
- bloquear avance del claim y marcar la cuenta para posible restricción futura de claims/reportes cuando haya indicios razonables de fraude o abuso.

No permitidas en MVP:
- otorgar OWNER automáticamente,
- resolver disputa compleja en automático,
- cambiar estados públicos de comercio,
- exponer señales internas sensibles al usuario.

## 14. Casos obligatorios por outcome
### Va a `needs_more_info`
- falta fachada,
- falta documento base,
- falta dato esencial para identificar comercio,
- categoría exige evidencia adicional mínima y no está.

### Va a `duplicate_claim`
- mismo usuario + mismo comercio + claim activo equivalente,
- reenvío equivalente sin cambios materiales.

### Va a `conflict_detected`
- comercio con owner activo,
- reclamos incompatibles simultáneos,
- colisión fuerte entre claim y estado del comercio.

### Va a `under_review` (manual estándar)
- claim completo y coherente sin conflicto obvio,
- categoría sensible que requiere criterio humano,
- caso ambiguo que no debe resolverse en automático.

## 15. Frontend (definición funcional)
Mostrar estados entendibles, no detalles internos:
- “Estamos revisando tu solicitud”
- “Necesitamos más información”
- “Ya existe una solicitud similar”
- “Tu reclamo requiere revisión especial”

No mostrar:
- detalles antifraude,
- fingerprints/hashes,
- reglas internas de matching o scoring.

## 16. Backend (definición funcional)
Requisitos:
- ejecución confiable e idempotente,
- una sola evaluación por transición relevante,
- sin doble decisión sobre el mismo evento,
- registro de motivos estructurados,
- handoff limpio a Admin.

Guardrails:
- no alterar `merchant_public`,
- no mezclar validación de claim con mutaciones de catálogo,
- no promover roles en esta etapa.

## 17. Seguridad de negocio y datos
Reglas:
- solo claims autenticados,
- sin ampliación de permisos por validación,
- sin exposición de claims ajenos,
- dedupe/conflicto con señales protegidas (`ipHash`, fingerprints),
- sin PII sensible en logs funcionales.

Mitiga:
- IDOR de claims,
- apropiación indebida de comercios,
- escalación indebida a OWNER,
- abuso por duplicación maliciosa.

## 18. Guardrails críticos de costo Firestore
- Validación por claim puntual, sin barridos de colección.
- Queries siempre scoped e indexadas (`merchantId`, `userId`, `claimStatus`, `zoneId`, `categoryId`).
- Dedupe/conflicto con `limit` bajo y criterio claro.
- Evitar listeners permanentes de `merchant_claims`.
- Evitar recalcular claims ya procesados.
- Escribir solo si cambia estado/flags (no writes redundantes).
- Cache/TTL para metadatos de reglas cuando aplique.

## 19. Datos impactados
Entidad principal: `merchant_claims`  
Referencias: `users`, `merchants`, señales de owner/conflicto.

Campos derivados sugeridos (conceptuales):
- `autoValidationStatus`
- `autoValidationReasons`
- `hasConflict`
- `hasDuplicate`
- `requiresManualReview`
- `missingEvidence`
- `riskFlags`

## 20. BDD de aceptación (MVP)
1. Dado claim completo con evidencia mínima, cuando se valida, entonces se enruta al estado correcto sin acción extra del usuario.
2. Dado claim sin fachada o sin documento mínimo, cuando se valida, entonces va a `needs_more_info`.
3. Dado claim equivalente activo previo, cuando se reenvía, entonces se marca `duplicate_claim`.
4. Dado comercio con owner activo o reclamo incompatible, cuando se valida, entonces va a `conflict_detected`.
5. Dado claim sobre categoría sensible, cuando se valida, entonces se deriva a revisión manual.
6. Dado claim ya procesado, cuando se reejecuta accidentalmente, entonces no duplica decisiones.
7. Dado usuario consultando estado, cuando validación terminó, entonces ve estado claro y accionable.

## 21. QA plan resumido
- QA funcional: completo/incompleto/duplicado/conflictivo/sensible.
- QA reglas: email autenticado, evidencia mínima, owner existente, claim previo.
- QA seguridad: no fuga de PII, no escalación de permisos, no acceso a claims ajenos.
- QA costo: lecturas acotadas, sin scans masivos, sin writes redundantes.
- QA integración: coherencia con 0126, 0128, 0131 y 0133.

## 22. Definition of Done
- Reglas cerradas para completitud, evidencia, duplicado y conflicto.
- Outcomes permitidos/no permitidos formalizados.
- Estados impactados y motivos estructurados definidos.
- Guardrails de costo explícitos y verificables.
- Sin contradicciones con Admin, OWNER, seguridad y legales.
- Lista de edge cases principales cubierta.
- Lista para implementación técnica sin ambigüedad de negocio.

## 23. Plan de rollout
Fase 1: cerrar definición y sincronización con 0126/0128/0129/0130/0131/0133.  
Fase 2: implementar motor MVP (completitud + evidencia + dedupe + conflicto + handoff).  
Fase 3: medir filtrado, carga manual evitada, falsos positivos y fricción.  
Fase 4: evolucionar reglas por categoría y priorización de riesgo si volumen lo requiere.

## 24. Documentos sincronizados por impacto
Crear/mantener alineado:
- `docs/storyscards/0127-merchant-claim-auto-validation.md`
- `docs/storyscards/0126-merchant-claim-flow.md`
- `docs/storyscards/0128-admin-merchant-claims-review.md`
- `docs/storyscards/0129-merchant-claim-evidence-by-category.md`
- `docs/storyscards/0130-merchant-claim-sensitive-data-protection.md`
- `docs/storyscards/0131-owner-claim-role-integration.md`
- `docs/storyscards/0133-merchant-claim-conflicts-and-duplicates.md`

Actualizar por impacto:
- `docs/storyscards/0004-role-segment-architecture.md`
- `docs/storyscards/0054-auth-complete.md`
- `docs/storyscards/0064-owner-module-business.md`
- legales `0100` a `0104` si cambian mensajes/consentimientos/tratamiento de claim.

## 25. Cierre ejecutivo
TuM2-0127 define una capa obligatoria para que el dominio de claims no sea caro, lento ni inseguro:
- valida identidad, completitud, evidencia, duplicado y conflicto,
- enruta a outcomes simples y auditables,
- deriva a humano cuando hay riesgo o ambigüedad,
- nunca concede OWNER automáticamente,
- prioriza costo Firestore bajo desde diseño.
