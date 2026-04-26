# TuM2-0136 — Catálogos estáticos versionados y serving barato

## Estado
- Estado: DONE
- Prioridad: P0
- Fecha de cierre técnico: 2026-04-24

## Objetivo cumplido
Se removió `zones` del hot path de Firestore para runtime normal en mobile y admin web, reemplazándolo por:
- seed local embebida
- manifest remoto versionado
- JSON versionado en Firebase Hosting
- caché persistente local + memoria
- búsqueda local normalizada

## Implementación aplicada

### 1) Publicación/versionado de catálogo
- Se agregó publicador reproducible: `tools/catalogs/publish_zones_catalog.mjs`.
- Soporta:
  - `publish` por ambiente (`dev|staging|prod`) con versión explícita
  - checksum `sha256-*`
  - escritura de `manifest.json`
  - escritura de `zones-vN.json`
  - `rollback` a versión previa publicada (`--rollback --rollback-to N`)
- Scripts npm:
  - `npm run catalogs:zones:publish -- --env <env> --version <N>`
  - `npm run catalogs:zones:publish -- --env prod --version <N> --update-seed`
  - `npm run catalogs:zones:rollback -- --env <env> --rollback-to <N>`
- Hardening de seguridad operativa:
  - `--update-seed` pasó a ser opt-in (default `false`).
  - `--update-seed` fuera de `prod` requiere `--allow-non-prod-seed` explícito.

### 2) Artefactos versionados por ambiente
- Canonical source: `data/catalogs/zones/`.
- Publicados por ambiente:
  - `data/catalogs/zones/dev/*`
  - `data/catalogs/zones/staging/*`
  - `data/catalogs/zones/prod/*`
- Cada ambiente tiene su `manifest.json`, historial `versions/zones-vN.json` y metadata de rollback.

### 3) Serving estático en Hosting
- Se espejan artefactos en:
  - `mobile/web/catalogs/zones/<env>/...` (hosting target `web`)
  - `web/web/catalogs/zones/<env>/...` (hosting target `admin`)
- Runtime consulta:
  - `/catalogs/zones/<env>/manifest.json`
  - y descarga condicional de `zones-vN.json` cuando cambia versión (upgrade o rollback).

### 4) Seed local y fallback
- Seed embebida en:
  - `mobile/assets/catalogs/zones/seed/zones-seed.json`
  - `web/assets/catalogs/zones/seed/zones-seed.json`
- Se usa para primer arranque/fallo de red.
- Se conserva catálogo previo ante:
  - falla de manifest
  - payload inválido
  - checksum mismatch.
- Si el manifest publicado hace rollback (`version` menor), el cliente aplica downgrade y persiste la versión validada.

### 5) Repositorio de catálogo mobile
- Nuevo: `mobile/lib/core/catalog/zones_catalog_repository.dart`.
- Incluye:
  - carga seed/cache/remoto
  - TTL de chequeo de manifest
  - validación de checksum
  - caché persistente (`SharedPreferences`)
  - caché memoria
  - índice de búsqueda local precomputado por versión de catálogo
  - búsqueda local normalizada.

### 6) Migración de consumidores mobile
- `ZoneSelectorSheet` migrado a catálogo real:
  - sin hardcode
  - búsqueda local
  - navegación jerárquica provincia → departamento → localidad
- Repositorios migrados a catálogo versionado:
  - `ZoneSearchRepository`
  - `ZonesRepository` (farmacias)
  - `OpenNowRepository` (zonas)
  - `GooglePlacesService.resolveZone` (onboarding owner)
- Se elimina lectura Firestore de `zones` en estos flujos.

### 7) Admin web alineado a la misma fuente lógica
- Nuevo cliente: `web/lib/core/catalog/zones_catalog_client.dart`.
- `ImportDataRepository.fetchAvailableZones()` deja de leer Firestore `zones` y usa catálogo versionado.
- Hardening:
  - timeout de red para `manifest` y payload
  - dedupe de cargas concurrentes (`in-flight`) para evitar requests duplicadas

## Analytics integrado
Se incorporaron eventos de catálogo/selector en mobile:
- `zones_catalog_load_started`
- `zones_catalog_load_succeeded`
- `zones_catalog_load_failed`
- `zones_catalog_manifest_checked`
- `zones_catalog_updated`
- `zone_selector_opened`
- `zone_selected`
- `zone_search_local_used`

Se habilitaron también en allowlist de `AnalyticsService`.

## Testing y validación

### Mobile
- Unit tests nuevos:
  - `mobile/test/core/catalog/zones_catalog_repository_test.dart`
    - seed fallback
    - update por versión nueva
    - fallback ante checksum inválido
    - no descarga payload cuando `manifest.version` no cambia
    - aplica rollback remoto cuando `manifest.version` baja
  - `mobile/test/modules/home/open_now_notifier_test.dart`
    - reutiliza cache por zona dentro de TTL/bucket
    - `refresh()` ignora cache y reconsulta

### Web Admin
- Unit tests nuevos:
  - `web/test/core/catalog/zones_catalog_client_test.dart`
    - dedupe de cargas concurrentes en cliente de catálogo
- Tests existentes en verde:
  - `search_notifier_test.dart`
  - `pharmacy_duty_notifier_test.dart`

### Análisis estático
- `flutter analyze` en `mobile`: sin issues.
- `flutter analyze` en `web`: sin issues.

## Costo/runtime
- Runtime normal de selector de zonas y consumos equivalentes:
  - 0 lecturas Firestore para servir catálogo de zonas
  - 0 listeners/snapshots sobre `zones`
  - 0 queries por tecleo de búsqueda de zonas
- Se eliminó residual legacy de lectura Firestore de zonas (`ZonesCacheService`) para evitar regresiones de costo.
- `OpenNow` incorpora cache local por zona con TTL + bucket temporal para reducir lecturas repetidas en navegación normal.
- Firestore queda disponible para fuente editorial/procesos internos, no como canal caliente de serving.

## Riesgos residuales
- El catálogo editorial inicial actual del repo es acotado (31 zonas); escalar a cobertura nacional completa depende del input editorial final.
- El flujo de publicación debe ejecutarse en CI/CD operativo para asegurar consistencia de versiones entre ambientes.

## DoD contra checklist
- [x] `ZoneSelectorSheet` sin hardcode
- [x] runtime normal sin Firestore para `zones`
- [x] manifest versionado
- [x] JSON versionado publicado
- [x] seed local
- [x] caché persistente local
- [x] búsqueda local
- [x] fallback offline con última versión válida
- [x] misma fuente lógica mobile/web/admin
- [x] tests de parser/versionado/fallback
- [x] rollback de versión publicada
- [x] documentación actualizada
