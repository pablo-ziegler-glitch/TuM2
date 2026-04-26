# TuM2-0065 — Alta/edición de productos (implementación)

Estado: READY_FOR_QA

## Alcance implementado
- Alta OWNER en 3 pasos (`datos básicos` → `foto/detalles` → `revisión/publicación`).
- Edición OWNER con guardado directo y preview actualizado.
- Precio opcional con `priceMode` (`none|fixed|consult`) y soporte de “Consultar precio”.
- Foto opcional con publicación permitida ante fallo de upload.
- Descripción breve opcional en producto (`description`).
- Lista OWNER con filtros `Activos / Agotados / Ocultos`.
- Acción rápida desde card para `marcar agotado/disponible`.
- Acción `Ocultar de Tu zona` (baja lógica `status=inactive`) y `Volver a mostrar`.
- Integración visual adicional de Stitch v2:
  - acceso a catálogo desde `Mi comercio` con card destacada,
  - estado `loading` con skeleton en listado de catálogo,
  - confirmaciones de ocultar/eliminar con layout modal alineado a diseño,
  - preview pública enriquecida en paso de revisión.
- Callables de catálogo:
  - `createMerchantProduct` (enforce capacidad + nuevos campos de precio/descripcion)
  - `deactivateMerchantProduct` (ocultar)
  - `reactivateMerchantProduct` (reactivar con enforce de capacidad)
- Trigger Functions existente para recalcular `merchants.hasProducts` mantenido.
- Firestore rules de `merchant_products` ajustadas para `description`, `priceMode` y `priceLabel` opcional.

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
- `owner_product_marked_available`
- `owner_product_marked_out_of_stock`
- `owner_product_reactivated`

## Pendientes para cierre
- QA manual end-to-end en dev/staging con usuarios `owner` y `owner_pending`.
- Definir decisión final de hard-delete irreversible (en esta iteración se mantiene ocultamiento/baja lógica).

## Validación técnica y CI (2026-04-26)
- Diagnóstico de falla CI en PR #138: el job `mobile` fallaba por commit incompleto (faltaban archivos dependientes del flujo OWNER, no por falla del workflow).
- Corrección aplicada: se incorporó el set faltante de código/modelos/auth/guards/tests relacionado a OWNER products.
- Verificación ejecutada en worktree limpio:
  - `flutter analyze` ✅
  - `flutter test --dart-define=ENV=staging` ✅
