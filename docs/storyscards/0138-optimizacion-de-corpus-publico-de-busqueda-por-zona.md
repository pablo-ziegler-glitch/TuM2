# TuM2-0138 — Optimización de corpus público de búsqueda por zona

## 1. Estado y metadata
- **Estado:** TODO
- **Prioridad:** P0
- **Dependencia madre:** TuM2-0135
- **Dependencia funcional:** TuM2-0056

## 2. Objetivo
Reducir drásticamente el costo de lectura de la búsqueda pública de comercios reutilizando un corpus cacheado por `zoneId`, sin romper el modelo híbrido ya decidido para TuM2.

## 3. Contexto
TuM2-0056 ya definió correctamente:
- búsqueda scoped por `zoneId`,
- máximo 200 docs,
- filtrado cliente sobre `searchKeywords`,
- flag `search_real_data_enabled`.

Eso es una base sana, pero no alcanza por sí sola si el corpus se relee en cada entrada a la pantalla, cambio de filtro o navegación hacia atrás.

## 4. Problema
Sin cache de corpus por zona, la búsqueda puede convertirse en uno de los mayores consumidores de lecturas del MVP:
- entrar y salir de búsqueda rerelee lo mismo,
- cambiar filtros reconsulta datos que ya estaban,
- lista y mapa duplican consumo,
- una zona popular puede disparar costo recurrente enorme.

## 5. Alcance IN
- corpus por `zoneId` cacheado,
- TTL de 10 minutos inicial,
- manifest/version opcional por zona,
- reuse entre lista/mapa/filtros,
- invalidación por cambio de zona o TTL,
- integración mobile y web pública.

## 6. Alcance OUT
- full-text search externo,
- ranking geográfico avanzado Post-MVP,
- indexación externa tipo Algolia/Elastic,
- realtime total del corpus.

## 7. Decisiones canónicas
### 7.1 Patrón de consumo
`get()` puntual de corpus por zona + cache local + filtros cliente + refresh controlado.

### 7.2 TTL recomendado
**10 minutos** para MVP.

### 7.3 Snapshot
**No** usar snapshot sobre corpus público de búsqueda como patrón general.

### 7.4 Fuente
Siempre `merchant_public`, nunca `merchants`.

## 8. Arquitectura propuesta
```text
Search screen
   |
   v
SearchRepository
   |
   +--> cache key: search:zone:<zoneId>:<version?>
   |
   +--> Firestore query a merchant_public scoped por zoneId
   |
   v
client-side filtering/ranking
```
Reglas:
- una sola lectura de corpus por zona dentro de TTL,
- misma fuente para lista y mapa,
- filtros locales,
- refresh manual disponible.

## 9. Frontend
- `loadZoneCorpus(zoneId, forceRefresh: false)`
- reutilización desde lista y mapa
- providers desacoplados de la query cruda
Estados:
- empty initial,
- loading frío,
- cached result,
- revalidating,
- empty result,
- error con fallback a cache.

Cambio de filtros: no debe disparar red si ya existe corpus vigente.  
Cambio de zona: sí invalida la clave y consulta el nuevo corpus.

## 10. Backend
### 10.1 Query base
`merchant_public`
- filtro por `zoneId`
- `visibilityStatus == visible`
- `limit <= 200`
- índices correctos

### 10.2 Proyección pública
La calidad de esta estrategia depende de que `merchant_public` tenga:
- campos resumidos suficientes,
- `searchKeywords` realmente poblado,
- no-op write avoidance.

### 10.3 Deuda impactada
Debe corregirse la deuda de `buildSearchKeywords()` tipado pero no implementado en la proyección.

## 11. Seguridad
- lectura solo de proyección pública,
- sin campos sensibles,
- sin revelar estructura interna privada,
- sin listeners amplios que faciliten scraping continuo.

## 12. UX / Producto
La búsqueda puede mostrar resultados de hasta 10 minutos de antigüedad, con refresh manual explícito.  
Beneficio UX:
- menos loaders,
- cambio de filtros rápido,
- navegación lista/mapa más fluida.

## 13. Datos impactados
- `merchant_public`
- `searchKeywords`
- cache por `zoneId`
- pantalla SEARCH-01 / SEARCH-02 / SEARCH-03
- manifests opcionales por zona

## 14. APIs y servicios
- Firestore
- repositorio de búsqueda
- Remote Config para TTL
- Analytics

## 15. Analytics
Eventos:
- `search_zone_corpus_loaded`
- `search_zone_corpus_cache_hit`
- `search_zone_changed`
- `search_filter_applied`
- `search_manual_refresh`

## 16. Testing
- cache key por zona,
- filtros locales sin red,
- invalidación al cambiar zona,
- forceRefresh,
- query real a `merchant_public`,
- fallback cache si falla la red,
- lista/mapa compartiendo dataset,
- E2E de entrar/salir/cambiar filtros.

## 17. DevOps
- TTL configurable por Remote Config,
- dashboards de lecturas por search session,
- alarma si search supera presupuesto por sesión.

## 18. Riesgos
- corpus muy grande para zonas densas,
- ranking local costoso si el payload está mal modelado,
- resultados stale en cambios operativos rápidos.

## 19. Definition of Done
- search no relee corpus por cada filtro o retorno,
- lista y mapa reutilizan mismo dataset,
- TTL de 10 min configurable,
- `buildSearchKeywords()` implementado,
- lecturas por sesión de búsqueda reducidas materialmente.

## 20. Rollout
1. feature flag interno,
2. dev con métricas,
3. staging con comparación A/B manual,
4. prod gradual.

## 21. Checklist final
- [ ] cache por `zoneId`
- [ ] TTL cerrado
- [ ] sin snapshots de corpus
- [ ] lista/mapa compartidos
- [ ] `searchKeywords` completos
- [ ] analytics de costo habilitada
