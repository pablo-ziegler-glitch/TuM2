# TuM2-0065 — Alta/edición de productos (implementación)

Estado: TODO

## Alcance implementado
- CRUD operativo OWNER sobre `merchant_products` con baja lógica (`status=inactive`).
- Imagen principal única por producto en Storage con path canónico:
  - `merchant-products/{merchantId}/{productId}/cover.jpg`
- Listado OWNER con empty state, badges de estado, acciones rápidas y confirmaciones.
- Formulario de alta/edición con validaciones inline y preview público.
- Trigger Functions para recalcular `merchants.hasProducts`.
- Rules de Firestore y Storage endurecidas por ownership, enums y campos inmutables.
- Índices de Firestore actualizados y válidos (sin comentarios JSON).

## Rutas OWNER
- `/owner/products`
- `/owner/products/new`
- `/owner/products/:productId/edit`

## Feature flag
- `owner_products_enabled` (Remote Config)
  - Default: `true`
  - Si está en `false`, el módulo de productos queda oculto para OWNER.

## Eventos de analytics
- `product_created`
- `product_edited`
- `product_deactivated`
- `product_hidden`
- `product_made_visible`
- `product_image_uploaded`
- `product_image_upload_failed`
