# TuM2-0135 — Épica transversal de costo/performance del MVP

## 1. Estado y metadata
- **Estado:** TODO
- **Prioridad:** P0 (MVP crítica)
- **Tags:** `Backend`, `Mobile`, `Web`, `Admin`, `Data`, `Seguridad`, `DevOps`, `MVP`
- **Ambientes válidos:** `tum2-dev-6283d`, `tum2-staging-45c83`, `tum2-prod-bc9b4`
- **Objetivo económico inicial:** no superar **USD 50/mes** en MVP y mantener techo de contingencia de **USD 70/mes**

## 2. Objetivo
Diseñar e implementar una estrategia transversal de costo y consumo para TuM2 que minimice lecturas, escrituras, listeners y fan-out innecesario en Firebase/Firestore, sin degradar de forma material la UX, la seguridad ni la escalabilidad del producto.

## 3. Contexto
TuM2 es especialmente sensible al costo por tres razones:
1. gran parte del valor del producto se consume en flujos consultivos de alta recurrencia,
2. varios dominios del MVP son propensos a relecturas repetitivas,
3. el presupuesto permitido para el MVP es muy bajo y el producto podría tener picos de adopción sin monetización inmediata.

La arquitectura actual ya tiene decisiones correctas, como el patrón dual-collection (`merchants` + `merchant_public`) y varios guardrails de costo en tickets específicos. El problema es que esos guardrails están dispersos y todavía no forman una política global unificada.

## 4. Problema que resuelve
Sin una estrategia transversal de costo, TuM2 corre estos riesgos:
- crecimiento de lecturas por pantalla de forma lineal con navegación repetida,
- listeners innecesarios en listados o shells,
- autorizaciones caras por lecturas extra en Rules,
- write amplification en proyecciones públicas,
- jobs programados que no escalan,
- y costo mensual impredecible frente a una primera repercusión positiva.

## 5. User stories
### Como usuario final
quiero que la app abra rápido y no me muestre loaders eternos ni datos claramente rotos, aunque algunos listados no sean realtime absoluto.

### Como owner
quiero editar y consultar mi información sin que el sistema me obligue a refrescar todo el tiempo ni consuma recursos absurdos.

### Como admin
quiero revisar claims, datasets y listados con costo controlado, sin listeners globales ni tablas que disparen consultas caras al solo abrirse.

### Como equipo TuM2
quiero que el costo de infraestructura no se vuelva deuda impagable si el MVP consigue adopción antes de monetizar.

## 6. Alcance IN
- clasificación global de dominios por estrategia de consumo,
- política canónica de `snapshot` vs `get()` vs cache versionado,
- estándar de TTL por dominio,
- catálogos estáticos fuera del hot path de Firestore,
- optimización de corpus de búsqueda por zona,
- optimización de datasets diarios / semi-estáticos,
- autorización por JWT claims donde corresponda,
- paginación y refresh manual en admin,
- reducción de write amplification,
- escalado de jobs programados,
- App Check y anti-abuso con foco en costo,
- observabilidad y budgets por feature,
- performance contract y QA de costo.

## 7. Alcance OUT
- rediseño funcional del producto no vinculado a costo,
- salida de Firebase,
- cambios en monetización,
- optimización prematura de features Post-MVP no críticas,
- simplificaciones que rompan seguridad o las reglas no negociables de arquitectura.

## 8. Supuestos
- `merchant_public` se mantiene como única proyección pública para comercios.
- Los claims y permisos siguen siendo backend-only para transiciones sensibles.
- `zones` y otros catálogos pueden servirse como dataset versionado/publicado.
- Se prioriza ahorro extremo mientras el deterioro UX/performance sea medible y aceptable.

## 9. Decisiones canónicas de arquitectura
### 9.1 Regla madre de consumo por tipo de dato
- **Dato estático:** asset / JSON versionado / Hosting / bundle, sin listener.
- **Dato semi-estático:** `get()` + cache persistente + TTL/versionado.
- **Dato crítico y vivo:** snapshot solo si la query es pequeña y el valor del realtime lo justifica.
- **Admin:** refresh manual o intervalos amplios controlados; no realtime por defecto.
- **Auth y permisos:** JWT claims + refresh explícito del token.

### 9.2 Diagrama conceptual
```text
Fuente editorial / privada
Firestore + Cloud Functions
            |
            v
Proyecciones públicas resumidas
merchant_public / docs resumen / manifests
            |
   +--------+--------+------------------+
   |                 |                  |
   v                 v                  v
catálogos       datasets TTL        estado sensible
versionados     get + cache         get / snapshot chico
```

### 9.3 Regla brutal sobre snapshots
- **No** snapshots por defecto en TuM2.
- **Sí** solo en docs puntuales o queries chicas con valor de UX muy claro.
- **Nunca** snapshots para `zones`, listados amplios, search general o admin masivo.

## 10. Frontend
- Flutter + Riverpod con una capa explícita de política de cache en repositorios.
- Tipos recomendados: `staticVersioned`, `ttlCached`, `sessionCached`, `manualRefreshOnly`, `networkOnly`.
- Shell sin listeners globales.
- Search con corpus por zona cacheado.
- Claims con refresh por foco/acción.
- Owner con lecturas puntuales por entrada y guardado explícito.
- Caches sensibles limpiadas al logout.

## 11. Backend
- Firestore sigue como source of truth.
- Cloud Functions sigue siendo la única capa autorizada para proyecciones públicas.
- Firebase Hosting se usa como serving barato para datasets estáticos/publicados.
- Patrones obligatorios: no-op write avoidance, manifests/version docs, queries acotadas, jobs batch/particionados, rechazo temprano.

## 12. Seguridad
Threat model orientado a costo:
- scraping sobre catálogos y búsquedas,
- abuso de callables,
- listeners masivos,
- Rules con lecturas extras,
- queries caras abiertas a usuarios no autenticados.

Controles:
- App Check en staging/prod,
- rate limiting donde el dominio lo requiera,
- filtros obligatorios,
- límites de tamaño/paginación,
- nada sensible en colecciones de lectura amplia.

## 13. UX / Producto
Política de frescura:
- `zones`: por versión
- search: 10 min
- abierto ahora: 3 min
- farmacias de turno: 10 min
- admin listados: manual / 60 s opcional
- claim status: foco/acción
- roles/permisos: token refresh

## 14. Datos impactados
- `zones`
- `merchant_public`
- `pharmacy_duties`
- `users`
- `merchant_claims`
- `import_batches`
- `admin_configs`
- posibles docs nuevos: `catalog_versions`, `zone_manifests`, `search_zone_manifests`, `daily_dataset_manifests`

## 15. APIs y servicios
- Firestore
- Firebase Hosting
- Firebase Auth + custom claims
- Cloud Functions TypeScript
- Remote Config
- App Check
- Analytics / Crashlytics

## 16. Analytics y KPI
- lecturas promedio por sesión útil
- lecturas promedio por apertura de pantalla
- escrituras promedio por cambio operativo
- costo estimado por feature y por 1.000 sesiones
- hit ratio de cache
- writes evitados por no-op
- listeners activos por módulo

## 17. Testing
- unit tests de cache/TTL/versionado,
- integration tests de repos y manifests,
- Rules tests para evitar lecturas extra,
- E2E de navegación repetida,
- pruebas de refresh de token tras cambios de claims,
- pruebas de degradación controlada con red mala.

## 18. DevOps y observabilidad
- feature flags para TTLs y modos de serving,
- dashboards por entorno,
- alertas por picos de lecturas,
- budgets mensuales y alertas tempranas,
- checklist release con presupuesto por flujo.

## 19. Riesgos y deuda
Impacta deudas conocidas:
- `ZoneSelectorSheet` hardcodeado,
- `getUserRole()` costoso en Rules,
- `nightlyRefreshOpenStatuses` secuencial,
- `buildSearchKeywords()` faltante,
- `enforceAppCheck: false` en admin callables,
- comentarios inválidos en índices,
- inconsistencia `zone/category` vs `zoneId/categoryId`.

## 20. Definition of Done
- clasificación de consumo aplicada a todos los dominios MVP,
- epic hijas expandidas y priorizadas,
- dashboards básicos de costo disponibles,
- budgets definidos,
- sin listeners amplios en módulos críticos,
- catálogos estáticos resueltos fuera del hot path de Firestore.

## 21. Plan de rollout
### Fase 1
`zones`, JWT/rules, cache framework, admin refresh manual.

### Fase 2
search por zona, datasets diarios, write amplification.

### Fase 3
jobs, anti-abuso, observabilidad, QA de costo.

## 22. Checklist final
- [ ] `zones` fuera del hot path de Firestore
- [ ] JWT claims usados para permisos críticos
- [ ] admin sin listeners globales
- [ ] search con cache por zona
- [ ] farmacias/abierto ahora con TTL cerrados
- [ ] no-op writes en proyecciones
- [ ] jobs batch/particionados
- [ ] App Check activo en staging/prod
- [ ] budgets y alertas configurados
- [ ] performance contract definido
