# TuM2-0146 — Performance contract y QA de costo del MVP

## 1. Estado y metadata
- **Estado:** TODO
- **Prioridad:** P0
- **Dependencia madre:** TuM2-0135

## 2. Objetivo
Definir un contrato explícito de costo y rendimiento para el MVP y evitar regresiones que reintroduzcan consumo excesivo sin ser detectadas.

## 3. Problema
Optimizar una vez no alcanza.
Sin un contrato de performance/costo, cualquier PR futuro puede:
- agregar listeners,
- sacar `limit`,
- duplicar reads,
- romper cachés,
- o inflar writes sin que nadie lo note.

## 4. Alcance IN
- tabla de presupuesto por flujo/pantalla,
- criterios máximos de lecturas y writes,
- checklist de revisión técnica,
- pruebas E2E de repetición,
- validación de degradación aceptable.

## 5. Alcance OUT
- benchmarking enterprise,
- SLAs públicos,
- testing masivo de laboratorio fuera del MVP.

## 6. Contrato inicial propuesto
### `zones`
- runtime Firestore: **0 lecturas recurrentes**
- apertura repetida de selector: **0 lecturas Firestore**
- refresh solo por cambio de versión

### search
- primera carga de zona: **1 query de corpus**
- cambios de filtro dentro de TTL: **0 lecturas extra**
- volver desde detalle dentro de TTL: **0 lecturas extra**

### abierto ahora
- dentro de TTL: **0 lecturas extra**
- refresh manual: **1 query controlada**

### farmacias de turno
- misma zona/día dentro de TTL: **0 lecturas extra**
- detalle desde listado: **0 requery si dataset ya existe**

### claims admin
- listado: **1 query paginada**
- detalle: **1 lectura puntual**
- evidencia: **solo on-demand**

### auth/roles
- sin lectura Firestore por request para rol si JWT claim alcanza

## 7. QA plan
### QA funcional
- flujo feliz
- vacíos
- errores de red
- retry

### QA de costo
- repetir navegación,
- medir rereads,
- medir reuse de cache,
- medir writes por acción.

### QA de seguridad
- validar App Check,
- validar claims,
- validar que no haya reveals cacheados.

### QA de regresión
- si se toca repositorio/Rules/trigger, correr batería de costo correspondiente.

## 8. Frontend
Checklist por PR:
- ¿agregaste listener?
- ¿es realmente necesario?
- ¿hay TTL?
- ¿hay key de invalidación?
- ¿hay refresh manual?
- ¿hay cleanup al logout?

## 9. Backend
Checklist por PR:
- ¿la query tiene `limit`?
- ¿usa cursor y no offset?
- ¿hace no-op write avoidance?
- ¿rechaza temprano?
- ¿lee claims desde JWT cuando puede?
- ¿genera logs de docsRead/docsWritten?

## 10. Seguridad
El contrato de costo no puede justificar atajos inseguros.
Nunca se acepta:
- mover auth sensible al cliente,
- exponer privados para ahorrar lecturas,
- escribir `merchant_public` desde cliente,
- claims desde cliente.

## 11. UX / Producto
Ahorro extremo sí, pero medido.
Si una optimización:
- confunde al usuario,
- degrada decisiones operativas,
- o rompe confianza,
debe revisarse aunque ahorre.

## 12. Datos impactados
Todos los dominios críticos del MVP.

## 13. APIs y servicios
Todos los repositorios críticos, Rules, Functions y dashboards internos.

## 14. Analytics
- `performance_budget_exceeded`
- `unexpected_reread_detected`
- `screen_cost_regression_detected`

## 15. Testing
- contratos de cache
- límites de flujo
- repos
- Rules
- triggers
- journeys repetidos
- logout/login
- cambio de zona
- claim approval
- admin detalle

## 16. DevOps
- PR checklist obligatorio,
- definición de gates de CI si es viable,
- checklist de release con top riesgos de costo.

## 17. Riesgos
- contrato demasiado teórico,
- métricas difíciles de capturar si no se instrumenta bien,
- equipo ignorándolo bajo presión.

## 18. Definition of Done
- contrato documentado,
- checklist aplicado,
- pruebas de costo incluidas en QA,
- regresiones detectables antes de prod.

## 19. Rollout
1. definir contrato
2. aplicar a features más caras
3. incorporar a QA/release
4. mantenerlo vivo

## 20. Checklist final
- [ ] tabla de presupuestos por flujo
- [ ] checklist de PR
- [ ] QA de costo definido
- [ ] regresiones detectables
- [ ] contrato anexado a release readiness
