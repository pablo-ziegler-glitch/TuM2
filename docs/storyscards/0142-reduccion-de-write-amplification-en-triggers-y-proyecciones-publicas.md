# TuM2-0142 — Reducción de write amplification en triggers y proyecciones públicas

## 1. Estado y metadata
- **Estado:** TODO
- **Prioridad:** P0
- **Dependencia madre:** TuM2-0135
- **Dependencias funcionales:** TuM2-0049, TuM2-0050, TuM2-0067, TuM2-0124

## 2. Objetivo
Reducir escrituras redundantes en triggers y proyecciones públicas, evitando que una misma operación lógica se traduzca en más writes de los realmente necesarios.

## 3. Contexto
TuM2 depende fuertemente de proyecciones públicas y campos derivados. Eso es correcto, pero cada trigger mal diseñado puede generar:
- writes repetidos sin cambio real,
- cascadas de recompute,
- más lecturas posteriores,
- más costo y más riesgo de condiciones de carrera.

Ya existe precedente correcto con `merchant_operational_signals` y no-op write avoidance; esta tarjeta busca generalizar esa disciplina.

## 4. Problema
Sin control de write amplification:
- un cambio pequeño dispara múltiples writes,
- listeners o consultas posteriores ven demasiados cambios,
- se encarece la operación por usuario,
- y el sistema escala peor.

## 5. Alcance IN
- función canónica de diff/normalización para proyecciones,
- no-op write avoidance sistemático,
- logs estructurados de writes evitados,
- revisión de triggers sobre `merchant_public` y otros dominios resumidos.

## 6. Alcance OUT
- eliminar por completo proyecciones públicas,
- mover derivación al cliente,
- sacrificar consistencia por evitar writes.

## 7. Decisiones canónicas
- no se escribe una proyección si el payload resultante es semánticamente igual al ya persistido,
- comparar payloads normalizados,
- todo skip debe loguearse con motivo y contexto.

## 8. Arquitectura propuesta
```text
evento write fuente
      |
      v
computeProjection()
      |
      v
normalize(next) vs normalize(current)
      |
   same? ---- yes ---> skip write + structured log
      |
      no
      v
persist projection
```

## 9. Frontend
No cambia directamente UI, pero reduce:
- ruido de cambios,
- costo indirecto,
- y posibles revalidaciones innecesarias del lado cliente.

## 10. Backend
Targets prioritarios:
- `merchant_public`
- campos derivados operativos
- señales operativas
- posibles resúmenes de duties o acceso

Utilidad reusable:
- `shouldWriteProjection(current, next)`
- `normalizeProjectionPayload(payload)`

Logs estructurados:
- `merchantId`
- `projection`
- `writeSkipped`
- `reason`
- `changedFields`
- `sourceTrigger`

## 11. Seguridad
Menos writes también reduce ruido de auditoría y exposición accidental por cambios innecesarios.

## 12. UX / Producto
Beneficio indirecto:
- menos latencia post-guardado,
- menos inconsistencias,
- menos “parpadeos” de estado.

## 13. Datos impactados
- `merchant_public`
- `merchant_operational_signals`
- otros docs derivados del MVP
- triggers/functions relevantes

## 14. APIs y servicios
- Cloud Functions
- Firestore
- logging estructurado

## 15. Analytics / métricas internas
- `projection_write_skipped_count`
- `projection_write_executed_count`
- `avg_changed_fields_per_write`

## 16. Testing
- igualdad semántica,
- nulos/defaults,
- arrays ordenados,
- cambios reales vs no reales,
- trigger recibe write fuente,
- payload igual → skip,
- payload distinto → write.

## 17. DevOps
- métricas por trigger,
- alarmas si aumenta ratio de writes por evento lógico,
- comparar before/after en staging.

## 18. Riesgos
- comparar mal y saltarse writes necesarios,
- normalización defectuosa,
- acoplar demasiado lógica de diff a un solo dominio.

## 19. Definition of Done
- helper canónico reutilizable,
- principales triggers con no-op write avoidance,
- métricas de writes evitados visibles,
- reducción tangible de writes redundantes.

## 20. Rollout
1. `merchant_public`
2. señales operativas
3. duties/proyecciones secundarias
4. resto de triggers con mayor volumen

## 21. Checklist final
- [ ] diff canónico
- [ ] normalización consistente
- [ ] structured logs
- [ ] tests unitarios
- [ ] reducción medible de writes
