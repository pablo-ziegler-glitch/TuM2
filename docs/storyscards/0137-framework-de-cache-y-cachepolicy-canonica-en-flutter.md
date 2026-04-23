# TuM2-0137 — Framework de cache y `CachePolicy` canónica en Flutter

## 1. Estado y metadata
- **Estado:** TODO
- **Prioridad:** P0
- **Dependencia madre:** TuM2-0135

## 2. Objetivo
Crear un framework simple, consistente y reutilizable de cache en Flutter para TuM2, evitando relecturas innecesarias y eliminando decisiones ad-hoc por pantalla.

## 3. Problema
Sin una política común de cache, cada feature puede terminar resolviendo consumo de forma distinta, generando:
- relecturas evitables,
- comportamiento inconsistente,
- bugs de invalidación,
- dificultad para medir costo por feature,
- y tentación de usar listeners donde no hacen falta.

## 4. Alcance IN
- definición de `CachePolicy`,
- contrato base de repositorios,
- cache en memoria,
- metadata persistente de cache,
- invalidación por TTL, versión y logout,
- soporte para stale-while-revalidate cuando convenga,
- métricas de hit/miss por feature.

## 5. Alcance OUT
- motor local complejo estilo ORM full,
- sincronización offline bidireccional,
- reemplazar Firestore local SDK para todos los casos.

## 6. Decisión técnica
### 6.1 Principio
Cada repositorio de TuM2 debe declarar explícitamente cómo consume y cuánto puede reutilizar.

### 6.2 Enum sugerido
```dart
enum CachePolicy {
  staticVersioned,
  ttlCached,
  sessionCached,
  manualRefreshOnly,
  networkOnly,
}
```

### 6.3 Contrato base sugerido
```dart
abstract class CacheAwareRepository<T, K> {
  Future<T> load(K key, {bool forceRefresh = false});
  Future<void> invalidate(K key);
  Future<void> clearAll();
}
```

## 7. Arquitectura propuesta
```text
UI / Notifier
    |
    v
Repository
    |
    +--> Memory cache
    |
    +--> Persistent metadata/cache
    |
    +--> Network/Firestore/Hosting
```
Reglas:
- primero memoria si está vigente,
- luego persistencia si está vigente,
- si está stale pero usable, servirlo y revalidar,
- si no hay nada válido, ir a red.

## 8. Frontend
Casos de uso:
- `ZonesRepository` → `staticVersioned`
- `SearchRepository` → `ttlCached`
- `PharmacyDutiesRepository` → `ttlCached`
- `UserAccessRepository` → `sessionCached`
- `AdminClaimsRepository` → `manualRefreshOnly`

Keys de cache:
- `zones:v3`
- `search:zone:<zoneId>:v<manifestVersion>`
- `duties:zone:<zoneId>:date:<yyyy-mm-dd>`
- `merchant_public:<merchantId>`
- `claims:active:<uid>`

Invalidation triggers:
- TTL vencido,
- versión nueva,
- logout,
- cambio de zona,
- guardado exitoso,
- pull-to-refresh,
- cambio de sesión/rol.

Nunca cachear:
- reveals sensibles,
- adjuntos de claim,
- tokens crudos.

## 9. Backend
Esta tarjeta no agrega backend complejo, pero exige que backend entregue:
- docs/manifests de versión cuando aplique,
- timestamps consistentes,
- payloads resumidos,
- y no cambie formatos sin versionar.

## 10. UX / Producto
Cache no significa “mostrar cualquier cosa vieja”.
Significa: **mostrar rápido lo último razonablemente válido y actualizar cuando haga falta**.

Microcopy sugerido:
- “Actualizado hace 2 min”
- “Mostrando datos recientes”
- “No se pudo actualizar, se muestra la última versión disponible”

## 11. Datos impactados
- repositorios Flutter de búsqueda
- zonas
- farmacias de turno
- abierto ahora
- claims
- admin listados
- owner módulos

## 12. APIs y servicios
- repositorios Flutter
- persistencia local simple
- Remote Config para TTLs configurables
- Analytics para hit/miss

## 13. Analytics
Eventos:
- `cache_hit`
- `cache_miss`
- `cache_stale_served`
- `cache_invalidated`
- `cache_refresh_started`
- `cache_refresh_failed`

## 14. Testing
- TTL vigente/vencido,
- serving desde memoria y persistencia,
- force refresh,
- invalidación por logout,
- invalidación por cambio de versión,
- fallback si falla la red,
- revalidación silenciosa.

## 15. DevOps
- flags para ajustar TTL sin redeploy,
- logging de hit ratio por feature,
- posibilidad de desactivar cache agresiva si una pantalla queda demasiado stale.

## 16. Riesgos
- demasiada complejidad para repositorios simples,
- errores de invalidación,
- mezclar datos sensibles con cache reusable,
- pérdida de coherencia entre web y mobile.

## 17. Definition of Done
- existe `CachePolicy` canónica documentada,
- al menos 3 features críticas la usan,
- invalidación por logout implementada,
- métricas de hit/miss disponibles,
- sin listeners usados para resolver problemas que el cache ya cubre.

## 18. Rollout
1. framework base,
2. integración en `zones`,
3. integración en search,
4. integración en farmacias/abierto ahora,
5. luego claims/admin donde aplique.

## 19. Checklist final
- [ ] contrato base de repositorio definido
- [ ] `CachePolicy` documentada
- [ ] TTLs configurables
- [ ] invalidación por logout
- [ ] métricas de cache
- [ ] fallback offline razonable
