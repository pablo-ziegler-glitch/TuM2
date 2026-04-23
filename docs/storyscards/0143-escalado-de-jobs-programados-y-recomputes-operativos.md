# TuM2-0143 — Escalado de jobs programados y recomputes operativos

## 1. Estado y metadata
- **Estado:** TODO
- **Prioridad:** P0
- **Dependencia madre:** TuM2-0135
- **Dependencias funcionales:** TuM2-0049, TuM2-0124

## 2. Objetivo
Rediseñar jobs programados y recomputes operativos para evitar patrones secuenciales que no escalan en costo ni en tiempo de ejecución.

## 3. Contexto
Existe una deuda conocida:  
`nightlyRefreshOpenStatuses` usa N lecturas secuenciales y presenta riesgo de timeout con más de ~50 merchants.

## 4. Problema
Jobs secuenciales producen:
- tiempos largos,
- timeouts,
- costo impredecible,
- fan-out por lote,
- peor resiliencia ante crecimiento.

## 5. Alcance IN
- particionado por zona/lote,
- límites por ciclo,
- processing incremental,
- retries controlados,
- evitar scans completos cuando no hagan falta,
- priorización de jobs realmente necesarios.

## 6. Alcance OUT
- scheduler complejo multi-cloud,
- streaming engine,
- colas externas fuera de Firebase.

## 7. Decisiones canónicas
No ejecutar scans globales secuenciales para recomputes rutinarios si se puede partir por:
- zona,
- fecha,
- estado,
- delta temporal,
- o docs marcados como “dirty”.

Modelo recomendado:
- jobs pequeños,
- particionados,
- idempotentes,
- con límite de documentos por ciclo.

## 8. Arquitectura propuesta
```text
scheduler
   |
   v
partition selector
   |
   +--> zone A batch 1
   +--> zone A batch 2
   +--> zone B batch 1
   |
   v
recompute worker idempotente
```

## 9. Frontend
No impacta directamente UI, pero mejora:
- consistencia de estados operativos,
- latencia de propagación,
- y estabilidad del sistema.

## 10. Backend
Candidatos prioritarios:
- refresh de abiertos/cerrados,
- reconciliaciones diarias,
- expiraciones de incidentes o rondas operativas,
- recalculados masivos heredados.

Estrategias:
- marcar docs “dirty” si algo cambió,
- evitar recomputar todo lo que ya está correcto,
- batch writes controlados,
- logs por partición.

## 11. Seguridad
- jobs con privilegio mínimo necesario,
- idempotencia para evitar writes repetidos,
- controles de concurrencia para no correr dos veces el mismo lote.

## 12. UX / Producto
Beneficio indirecto:
- menos estados incoherentes,
- menos riesgo de datos públicos atrasados por jobs que no terminan.

## 13. Datos impactados
- `merchant_public`
- `merchant_schedules`
- `merchant_operational_signals`
- `pharmacy_duties`
- colecciones auxiliares de rounds/incidents si corresponde

## 14. APIs y servicios
- Cloud Functions programadas
- Firestore
- logging estructurado

## 15. Métricas internas
- `job_partition_processed_count`
- `job_docs_read_count`
- `job_docs_written_count`
- `job_duration_ms`
- `job_timeout_count`

## 16. Testing
- particionador,
- idempotencia,
- selección incremental,
- job sobre muestra grande,
- retries,
- batch writes,
- load tests con 100, 1.000 y 5.000 merchants.

## 17. DevOps
- límites de ejecución por entorno,
- alarmas por timeout,
- alarmas por costo anormal,
- dashboards de duración y throughput.

## 18. Riesgos
- partición mala que deje zonas sin procesar,
- concurrencia duplicada,
- dirty flags inconsistentes.

## 19. Definition of Done
- jobs críticos sin patrón N secuencial,
- procesamiento particionado,
- métricas y logs por lote,
- sin timeouts en escenarios razonables del MVP.

## 20. Rollout
1. job de open statuses
2. jobs heredados operativos
3. reconciliaciones secundarias

## 21. Checklist final
- [ ] particionado por zona/lote
- [ ] `limit` por ciclo
- [ ] idempotencia
- [ ] métricas de tiempo/costo
- [ ] deuda de nightly refresh resuelta
