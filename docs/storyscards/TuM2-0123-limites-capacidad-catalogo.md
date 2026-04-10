# TuM2-0123 — Límites de capacidad de catálogo

Estado: DONE  
PR: #58  
Fecha de cierre: 2026-04-09

## Objetivo

Aplicar control operativo de capacidad de catálogo por comercio para evitar crecimiento descontrolado de productos y mantener costos predecibles de Firestore en flujos OWNER y ADMIN.

## Alcance implementado

### Backend (Cloud Functions)

- Configuración central de límites en `admin_configs/catalog_limits`:
  - `defaultProductLimit`
  - `categoryLimits`
- Callables administrativas (con `enforceAppCheck: true`):
  - `setGlobalCatalogProductLimit`
  - `setCategoryCatalogProductLimit`
  - `clearCategoryCatalogProductLimit`
  - `setMerchantCatalogLimitOverride`
  - `clearMerchantCatalogLimitOverride`
- Búsqueda de comercios para gestión de límites:
  - `searchCatalogLimitMerchants` con `limit` acotado (máximo 30).
- Alta de producto vía callable transaccional:
  - `createMerchantProduct` valida ownership y cupo efectivo antes de crear.
  - bloqueo duro con error `catalog_limit_reached` cuando se alcanza el límite.
- Baja lógica de producto vía callable:
  - `deactivateMerchantProduct` ajusta `catalogStats.activeProductCount`.

### Mobile OWNER

- Capacidad visible en UI (`used/limit/remaining/source`) en listado y formulario.
- Estados de warning/bloqueo cuando se acerca o alcanza el cupo.
- Integración con flags remotas:
  - `catalog_capacity_policy_enabled`
  - `catalog_capacity_hard_block_enabled`
  - `catalog_product_create_via_cf_enabled`
- Cache con TTL de configuración de límites en provider (`10 min`).

### Admin Web

- Pantalla de gestión de límites (`CatalogLimitsScreen`) para:
  - límite global,
  - límites por categoría,
  - override por comercio con buscador.

### Schema y tipos

- Tipado de `CatalogLimitsConfig` en `schema/types/admin_configs.ts`.
- Modelos de capacidad en owner mobile (`OwnerCatalogCapacity`, `CatalogLimitSource`).

## Eventos analytics agregados

- `owner_catalog_limit_warning_seen`
- `owner_catalog_limit_block_seen`
- `owner_contact_admin_from_catalog_limit`
- `owner_product_create_blocked_by_limit`

## Criterios de costo cumplidos

- Queries de administración con `limit` explícito.
- Cálculo de capacidad basado en `catalogStats.activeProductCount` denormalizado en `merchants` (evita scans completos de `merchant_products`).
- Mutaciones de catálogo concentradas en callables transaccionales para prevenir writes redundantes/inconsistentes.
- Sin listeners globales nuevos para esta historia.
