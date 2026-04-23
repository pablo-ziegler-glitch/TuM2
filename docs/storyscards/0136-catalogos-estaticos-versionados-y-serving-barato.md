# TuM2-0136 — Catálogos estáticos versionados y serving barato (`zones`, taxonomías, reglas)

## 1. Estado y metadata
- **Estado:** TODO
- **Prioridad:** P0
- **Dependencia madre:** TuM2-0135

## 2. Objetivo
Sacar los catálogos estáticos del hot path de Firestore y servirlos mediante un esquema versionado/publicado de muy bajo costo, comenzando por `zones` y siguiendo por taxonomías y reglas semi-estáticas del MVP.

## 3. Contexto
`zones` hoy es un dominio delicado por dos razones:
1. el selector actual tiene deuda conocida por usar lista hardcodeada,
2. una migración ingenua a Firestore con 15k registros y lecturas repetidas sería una mala decisión económica.

Además de `zones`, TuM2 tiene otros datasets de naturaleza estática o casi estática:
- categorías/rubros canónicos del MVP,
- tipos de señales operativas,
- reglas de evidencia por categoría,
- labels y taxonomías operativas auxiliares.

## 4. Problema
Usar Firestore como serving directo para catálogos estáticos produce:
- muchas lecturas repetidas del mismo dato,
- mala latencia en selectores o filtros,
- costo innecesario en admin/mobile/web,
- tentación de listeners absurdos sobre datos que no cambian.

## 5. User stories
### Como usuario
quiero que el selector de zonas abra rápido y funcione sin esperas absurdas.

### Como admin
quiero publicar una nueva versión de catálogo sin forzar a que cada apertura me cueste miles de lecturas.

### Como equipo
quiero que `zones` y otras taxonomías tengan costo casi nulo en runtime.

## 6. Alcance IN
- resolver `zones` con publicación versionada,
- definir formato de `zones.json`,
- definir manifiesto/versionado,
- definir repositorio Flutter para consumo local,
- habilitar uso en mobile, web pública y admin web,
- incluir taxonomías y reglas estáticas elegibles.

## 7. Alcance OUT
- editor admin complejo de cartografía,
- edición colaborativa en vivo del catálogo,
- geosearch avanzado Post-MVP.

## 8. Decisión canónica
### 8.1 Estrategia elegida
**Hosting + JSON versionado/publicado + cache de navegador/cliente + invalidación por versión**

### 8.2 Alternativas evaluadas
- Firestore directo: más caro y peor para este dominio.
- Firestore bundle: válido, pero para MVP la solución JSON versionado/publicado en Hosting es más simple operativamente.
- Asset embebido puro: extremadamente barato, pero obliga a deploy para cada cambio.

### 8.3 Conclusión
Se elige una solución híbrida:
- fuente editorial/admin: dataset fuente en repositorio o pipeline interno de publicación,
- serving runtime: archivo JSON versionado en Hosting,
- invalidación: doc/manifiesto mínimo o Remote Config con `zones_catalog_version`.

## 9. Arquitectura propuesta
```text
dataset fuente (manual/admin/pipeline)
            |
            v
publicación controlada
            |
            v
Firebase Hosting
  /catalogs/zones/v{N}/zones.json
  /catalogs/zones/manifest.json
            |
            v
Flutter repos
  memory cache + persistent metadata
            |
            v
UI local con búsqueda jerárquica
```

## 10. Frontend
- descargar `manifest.json`,
- comparar `version`,
- si cambió, descargar JSON nuevo,
- guardar metadata local,
- usar dataset en memoria para búsqueda.
Modelo de interacción:
- selector jerárquico: provincia → departamento → ciudad
- búsqueda local normalizada,
- sin requests por cada tecla.

## 11. Backend
Flujo de publicación:
1. validar dataset fuente,
2. generar `zones.json`,
3. generar `manifest.json`,
4. publicar a Hosting,
5. actualizar `zones_catalog_version` en Remote Config o doc mínimo.

### Formato sugerido
#### `manifest.json`
```json
{
  "catalog": "zones",
  "version": 3,
  "publishedAt": "2026-04-23T00:00:00Z",
  "path": "/catalogs/zones/v3/zones.json",
  "checksum": "sha256:..."
}
```

## 12. Seguridad
- `zones.json` es público y no contiene información sensible.
- la publicación debe estar protegida del lado admin/pipeline,
- no se habilita escritura cliente,
- no se expone pipeline de publicación a clientes anónimos.

## 13. UX / Producto
- el selector debe sentirse instantáneo,
- si hay actualización, debe aplicarse sin fricción,
- si falla la descarga de una nueva versión, se usa la versión anterior.

## 14. Datos impactados
- `zones`
- `manifest.json` / catálogo publicado
- Remote Config o doc mínimo de versión
- `ZoneSelectorSheet`

## 15. APIs y servicios
- Firebase Hosting
- Remote Config o doc mínimo
- repositorios Flutter
- utilidades de normalización de texto UTF-8

## 16. Analytics
Eventos sugeridos:
- `zones_catalog_manifest_fetched`
- `zones_catalog_updated`
- `zones_catalog_update_failed`
- `zone_selector_opened`
- `zone_selector_search_used`

## 17. Testing
- parser de manifest,
- parser de catálogo,
- normalización de búsqueda,
- invalidación por versión,
- fallback a catálogo anterior,
- Hosting fetch,
- cache local,
- E2E de sesión fría/caliente/offline.

## 18. DevOps
- pipeline de publicación de catálogo,
- checksum obligatorio,
- rollback simple por versión anterior,
- hosting headers con cache control adecuados.

## 19. Riesgos
- JSON excesivamente grande si se modela mal,
- parser lento si no se optimiza estructura,
- invalidación defectuosa.

## 20. Definition of Done
- `ZoneSelectorSheet` consume catálogo real no hardcodeado,
- `zones` no usa snapshots ni Firestore hot path,
- catálogo versionado/publicado operativo,
- búsqueda local normalizada funcionando.

## 21. Rollout
1. publicar versión inicial,
2. migrar primero admin web,
3. luego mobile,
4. luego web pública,
5. remover hardcodes y feature flag legacy.

## 22. Checklist final
- [ ] `zones` fuera de Firestore runtime hot path
- [ ] manifest y catálogo versionados
- [ ] selector jerárquico real
- [ ] búsqueda local
- [ ] fallback offline
- [ ] rollback por versión
