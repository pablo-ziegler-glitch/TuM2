# TuM2-0133 — Conflictos, duplicados y disputa de titularidad

Estado: READY_TO_QA  
Prioridad: P0 (MVP crítica)  
Épica madre: TuM2-0125 — Reclamo de titularidad de comercio  
Depende de: TuM2-0126, TuM2-0127, TuM2-0128, TuM2-0131

## Estado real de implementación (corte 2026-04-16)
### Hecho
- Duplicados simples ya detectados en backend (mismo `userId` + `merchantId` + claim activo) con salida `duplicate_claim`.
- Conflicto básico implementado cuando comercio ya tiene owner o estado de ownership reclamado (`conflict_detected`).
- Flujo submit/evaluate/resolve ya respeta bloqueo de promoción automática en estados conflictivos.
- Tests de integración verifican flujo conflictivo, mantenimiento de `owner_pending` y resolución aprobada controlada.

### Falta para cerrar
- Completar detección de disputa real multi-actor (múltiples reclamantes plausibles sobre mismo comercio no reclamado).
- Modelar relación explícita entre claims vinculados (expediente, prioridad, historial de resolución).
- Implementar carril de resolución de disputa en UI Admin (clasificación visual, decisiones, escalamiento y trazabilidad completa).
- Afinar heurísticas para separar duplicado benigno vs abuso recurrente con guardrails de costo y sin falsos positivos altos.

## 1. Objetivo
Definir el tratamiento de casos no lineales de claim:
- duplicado,
- conflicto,
- disputa de titularidad.

Debe dejar explícito qué bloquea automatización, cómo se enruta cada caso, qué ve usuario/Admin y cómo se evita promoción errónea a OWNER.

## 2. Contexto
El flujo base ya existe (claim + validación automática + revisión manual + owner_pending + promoción backend-only a OWNER).  
Falta cerrar el carril para colisiones reales entre reclamos incompatibles.

## 3. Problema que resuelve
- Ruido operativo por claims duplicados.
- Riesgo de aprobar parte equivocada.
- Ambigüedad de `owner_pending` en conflictos.
- Criterios admin inconsistentes.
- Riesgo de escalación indebida a OWNER.
- Riesgo legal/reputacional en disputas de titularidad.

## 4. Objetivo de negocio
Maximizar:
- seguridad de asignación de titularidad,
- claridad entre duplicado/conflicto/disputa,
- cero promoción automática en conflicto,
- bajo ruido operativo por duplicados simples,
- trazabilidad y prudencia en casos sensibles.

## 5. Alcance IN
- Definiciones canónicas de duplicado/conflicto/disputa.
- Reglas de clasificación y carriles de resolución.
- Impacto en estados claim y `owner_pending`.
- Bloqueo de automatización en conflicto/disputa.
- Lineamientos UX usuario + operación Admin.
- Outcomes de cierre/escalamiento.

## 6. Alcance OUT
- Flujo base claim (0126),
- motor general auto-validación (0127),
- UI completa Admin (0128),
- matriz documental (0129),
- seguridad técnica profunda de sensibles (0130),
- phone verification fase 2 (0132).

## 7. Supuestos
- Un comercio puede recibir múltiples intentos de claim.
- Puede haber owner existente.
- Puede haber evidencia plausible de más de una parte.
- No debe haber promoción automática en conflicto.
- Admin necesita carril explícito y trazable.

## 8. Dependencias
Funcionales:
- TuM2-0126, 0127, 0128, 0130, 0131.

Cruzadas:
- TuM2-0004, 0054, 0064 y legales aplicables.

## 9. Principios rectores
- Duplicado ≠ conflicto.
- Conflicto ≠ evidencia faltante.
- Disputa bloquea promoción automática.
- Owner existente implica máxima prudencia.
- En disputa: revisión humana por defecto.
- No castigar duplicado simple, sí ordenar flujo.
- No revelar datos de terceros al reclamante.
- Todo cierre en disputa debe ser auditable.

## 10. Arquitectura de carriles
Carril A: duplicado simple.  
Carril B: conflicto operativo.  
Carril C: disputa de titularidad.

Recomendación MVP: separar explícitamente estos carriles.

## 11. Definiciones canónicas
### Duplicado simple
Reenvío equivalente (mismo usuario + mismo comercio + sin cambios materiales) sin disputa real.

Tratamiento:
- reconducir al claim activo,
- evitar abrir expediente paralelo,
- feedback claro al usuario.

### Conflicto operativo
Incompatibilidad relevante que bloquea carril normal (otro claim activo, owner existente, colisión con estado comercio, evidencia inconsistente).

Tratamiento:
- bloquear avance lineal,
- derivar a revisión manual.

### Disputa de titularidad
Colisión real entre partes plausibles sobre legitimidad del mismo comercio.

Tratamiento:
- riesgo alto,
- bloquear cualquier promoción a OWNER hasta resolución firme.

## 12. Casos típicos
Duplicado:
- reenvío por error/ansiedad,
- claim ya abierto reenviado.

Conflicto operativo:
- claim simultáneo,
- owner actual,
- contradicción relevante con estado comercio.

Disputa:
- dos reclamantes plausibles incompatibles,
- owner actual vs nuevo reclamante plausible,
- cambio de manos no resuelto.

## 13. Estados de claim impactados
Estados relevantes:
- `duplicate_claim`
- `conflict_detected`
- `under_review`
- `needs_more_info`
- `approved`
- `rejected`
- `cancelled`

Recomendación MVP:
- duplicado simple → `duplicate_claim`
- conflicto/disputa → `conflict_detected` + carril manual especial

## 14. Relación con owner_pending
- Duplicado terminal sin claim vivo: no debe sostener pending.
- Conflicto operativo: puede sostener pending mientras caso siga abierto.
- Disputa: puede sostener pending, nunca acceso owner.

Mensaje de pending en conflicto: “caso vivo en revisión especial”, no “avance normal”.

## 15. Relación con OWNER
Regla crítica:
ningún conflicto/disputa puede promover OWNER automáticamente.

Implica:
- auto-validación nunca decide titular final en disputa,
- Admin debe revisar contexto completo,
- cliente nunca interpreta conflicto como “casi aprobado”.

## 16. Relación con validación automática (0127)
Puede:
- detectar duplicado obvio,
- detectar colisión con claim activo u owner existente,
- marcar flags y bloquear carril limpio.

No puede:
- resolver disputa entre partes plausibles,
- definir ownership final.

## 17. Relación con Admin review (0128)
Admin debe distinguir:
- duplicado reconducible,
- conflicto operable,
- disputa de titularidad.

En conflicto/disputa: carril más prudente que el claim lineal.

## 18. Reglas de decisión
Duplicado:
- no abrir vía paralela,
- reconducir y evitar carga manual innecesaria.

Conflicto:
- bloquear aprobación automática,
- revisión manual + trazabilidad,
- pedir más info cuando aporte.

Disputa:
- bloquear promoción,
- revisar con prudencia reforzada,
- registrar motivo y resolución clara.
- cuando haya mala fe o abuso reincidente, permitir restricción de nuevas capacidades de claims/reportes manteniendo acceso general no sensible del usuario final.

## 19. Outcomes de conflicto/disputa
- legitimidad clara de una parte,
- falta info (seguir `under_review` / `needs_more_info`),
- reconducción a duplicado simple,
- caso sigue conflictivo sin resolución,
- cierre negativo por inconsistencia.

## 20. UX usuario
Objetivo: claridad sin exponer terceros.

Copys sugeridos:
- “Tu solicitud necesita una revisión adicional”
- “Detectamos que este caso requiere una validación especial”
- “Todavía no podemos avanzar con la gestión del comercio”

Evitar:
- revelar existencia/identidad de otra parte,
- copy legalista o técnico interno.

## 21. Frontend (funcional)
Estados visibles:
- duplicado,
- revisión especial,
- conflicto detectado,
- more info por conflicto,
- cierre por duplicado terminal,
- cierre sin aprobación.

Cliente debe:
- bloquear rutas owner,
- mantener pending solo si caso sigue abierto,
- evitar reintentos ciegos que multipliquen claims.

## 22. Backend (funcional)
Debe:
- detectar/marcar duplicado y conflicto,
- relacionar claims vinculados,
- bloquear promociones en conflicto,
- sostener una única fuente de verdad de estado.

Guardrails:
- no OWNER con conflicto activo,
- no claims incompatibles avanzando en paralelo,
- no estados huérfanos/contradictorios.

## 23. Seguridad obligatoria
1. Duplicado nunca crea privilegios.
2. Conflicto nunca habilita OWNER.
3. Disputa = alto riesgo.
4. No exposición de datos de terceros.
5. Resolución backend-authoritative y auditada.
6. Sin automatización que elija entre partes plausibles en MVP.

## 24. Guardrails de costo
- Detección temprana de duplicado para evitar trabajo repetido.
- No abrir expedientes paralelos sin valor.
- Queries conflict/duplicate acotadas e indexadas.
- Feedback UX para reducir reenvíos.
- Revisión manual paginada y priorizable.

## 25. Datos impactados
Entidades:
- `merchant_claims`,
- `users`,
- `merchants`,
- ownership linkage,
- flags de conflicto/duplicado,
- timeline de resolución.

Datos:
- `hasConflict`,
- `hasDuplicate`,
- referencias a claims relacionados,
- `ownerExists`,
- notas de resolución,
- timestamps de apertura/cierre.

## 26. Reglas de negocio detalladas
- No múltiples claims activos equivalentes del mismo usuario/comercio.
- Owner existente bloquea carril lineal limpio.
- Claim incompatible activo dispara conflicto.
- Conflicto bloquea promoción automática a OWNER.
- Disputa real requiere humano.
- No revelar datos de otra parte al usuario.
- Cierre negativo limpia pending obsoleto.
- UI no debe incentivar nuevos claims si ya hay claim vivo/conflictivo.
- Conflicto legítimo y abuso del flujo deben diferenciarse, con posibilidad de restricción funcional progresiva de claims/reportes ante uso malicioso.

## 27. Analytics y KPI
Eventos:
- `merchant_claim_marked_duplicate`
- `merchant_claim_marked_conflict`
- `merchant_claim_dispute_opened`
- `merchant_claim_dispute_resolved`
- `merchant_claim_duplicate_redirected`
- `merchant_claim_conflict_more_info_requested`

KPI:
- % duplicados,
- % conflictivos,
- tiempo de resolución de conflicto,
- tasa de promoción a OWNER post-conflicto,
- falsos duplicados,
- reenvíos evitados.

North Star local:
% de duplicados/conflictos correctamente clasificados sin permisos indebidos ni carga manual innecesaria.

## 28. Edge cases
- mismo usuario reenvía múltiples veces,
- dos usuarios reclaman mismo comercio en ventana corta,
- owner existente con nuevo reclamante plausible,
- conflicto que cambia con nueva evidencia,
- resolución de un lado dejando otro pending residual,
- decisión admin concurrente,
- conflictivo en rubro sensible (p.ej. farmacia) con mayor prudencia.

## 29. QA plan
- QA funcional: duplicado, conflicto, owner existente, resolución, limpieza pending.
- QA UX: estado especial claro, sin fuga de terceros, sin confusión pending vs owner.
- QA seguridad: no OWNER con conflicto activo, no bypass cliente, resolución auditada.
- QA integración: 0127/0128/0131 + impacto auth/owner module.
- QA costo: reducción de reenvíos y revisiones repetidas.

## 30. Definition of Done
- Definidos duplicado, conflicto y disputa.
- Cerrado bloqueo de OWNER automático en conflicto/disputa.
- Relación con `owner_pending` formalizada.
- UX para casos especiales definida sin fuga de terceros.
- Rol Admin en resolución trazable definido.
- Edge cases principales cubiertos.
- Lista para implementación sin contradicciones de roles/claims.

## 31. Plan de rollout
Fase 1: cierre con 0127/0128/0131.  
Fase 2: implementación detección y clasificación (duplicado/conflicto/owner existente).  
Fase 3: medición (volumen, falsos positivos, tiempo resolución, fricción).  
Fase 4: evolución (heurísticas y herramientas admin más avanzadas).

## 32. Documentos a sincronizar
Crear/mantener:
- `docs/storyscards/0133-merchant-claim-conflicts-and-duplicates.md`
- `docs/storyscards/0127-merchant-claim-auto-validation.md`
- `docs/storyscards/0128-admin-merchant-claims-review.md`
- `docs/storyscards/0131-owner-claim-role-integration.md`

Actualizar por impacto:
- `docs/storyscards/0004-role-segment-architecture.md`
- `docs/storyscards/0054-auth-complete.md`
- `docs/storyscards/0064-owner-module-business.md`
- `docs/storyscards/0101-terms-and-conditions.md`
- `docs/storyscards/0102-claim-evidence-consent.md`

## 33. Cierre ejecutivo
TuM2-0133 cierra la seguridad funcional del dominio claims:
- duplicado simple y conflicto no son lo mismo,
- disputa de titularidad requiere carril especial,
- conflicto/disputa nunca promueven OWNER automáticamente,
- owner existente implica máxima prudencia,
- usuario recibe estado claro sin datos de terceros,
- Admin resuelve con clasificación y trazabilidad.
