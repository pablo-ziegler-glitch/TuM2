# TuM2-0145 — Observabilidad, budgets y telemetría de consumo por feature

## 1. Estado y metadata
- **Estado:** TODO
- **Prioridad:** P0
- **Dependencia madre:** TuM2-0135

## 2. Objetivo
Hacer visible el costo real de TuM2 por feature, flujo y entorno para poder tomar decisiones antes de que el gasto se vuelva inmanejable.

## 3. Problema
No se puede optimizar lo que no se mide.
Y peor: si el costo explota sin observabilidad, el primer síntoma llega tarde.

## 4. Alcance IN
- dashboards de consumo por entorno,
- alertas de presupuesto,
- telemetría por feature,
- métricas por callable/trigger/query clave,
- estimación de costo por pantalla/flujo.

## 5. Alcance OUT
- cost accounting financiero exhaustivo,
- BI avanzada fuera del MVP,
- atribución perfecta por usuario individual.

## 6. Decisiones canónicas
### 6.1 Budgets
- objetivo mensual: **USD 50**
- umbral de alerta temprana: **USD 35**
- umbral crítico: **USD 50**
- tolerancia máxima extraordinaria: **USD 70**

### 6.2 Entornos
Budgets y alertas separados por:
- dev
- staging
- prod

### 6.3 Métrica mínima obligatoria
Todo callable/trigger crítico debe loguear:
- docs leídos,
- docs escritos,
- duración,
- branch lógica tomada.

## 7. Arquitectura propuesta
```text
client analytics + backend structured logs
                 |
                 v
tableros operativos por feature / entorno
                 |
                 v
alertas y decisiones de rollback / tuning
```

## 8. Frontend
Cada carga relevante debe permitir estimar:
- uso de cache,
- refresh manual,
- frecuencia de apertura,
- latencia de pantalla.

## 9. Backend
Structured logs con:
- `feature`
- `operation`
- `environment`
- `docsRead`
- `docsWritten`
- `durationMs`
- `cacheHit` si aplica
- `writeSkipped` si aplica

Dashboards iniciales:
- search
- open now
- pharmacy duties
- claims admin
- imports
- triggers de proyección

## 10. Seguridad
- no loguear sensibles,
- no loguear payloads completos de claims,
- usar IDs y contadores,
- masking de datos privados.

## 11. UX / Producto
Observabilidad no cambia UX directamente, pero evita optimizaciones ciegas que rompan producto sin necesidad.

## 12. Datos impactados
- logs de Functions
- Analytics
- tableros internos
- budgets por proyecto

## 13. APIs y servicios
- Cloud Logging / logs estructurados
- Firebase Analytics
- dashboards internos
- budgets del proyecto GCP/Firebase

## 14. KPI
- costo estimado por 1.000 sesiones
- lecturas por sesión
- writes por operación
- pantallas más caras
- triggers más costosos
- hit ratio de cache

## 15. Testing
- validación de logs emitidos,
- consistencia de nombres de feature,
- alertas disparándose en staging de prueba.

## 16. DevOps
- budgets configurados,
- alertas por email/canal interno,
- revisión semanal de top costs,
- checklist release con consumo esperado.

## 17. Riesgos
- logs incompletos,
- demasiado ruido sin criterio,
- métricas que no conectan con decisiones reales.

## 18. Definition of Done
- budgets configurados,
- dashboards mínimos activos,
- top 5 features costosas identificables,
- logs estructurados en callables/triggers críticos.

## 19. Rollout
1. budgets
2. logs backend
3. dashboard base
4. ajuste por feature

## 20. Checklist final
- [ ] budgets por entorno
- [ ] alertas tempranas
- [ ] logs estructurados
- [ ] tablero por feature
- [ ] costo estimado por flujo
