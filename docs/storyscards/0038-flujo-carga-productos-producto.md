# TuM2-0038 — Flujo carga de productos (Producto/UX)

Estado: READY_FOR_QA
Última actualización: 2026-04-26

## Decisiones funcionales cerradas
- Alta en 3 pasos máximos desde mobile OWNER.
- Alta mínima: nombre + disponibilidad.
- Foto opcional y con opción “Foto luego”.
- Precio opcional con modo “Consultar precio”.
- Acción frecuente en catálogo: marcar disponible/agotado en un toque.
- “Ocultar de Tu zona” priorizado sobre eliminación irreversible.
- Mensajería de límite como capacidad operativa (no punitiva).
- Lenguaje de producto en tono “vos”, sin semántica e-commerce.

## Relación con implementación
- Implementación técnica asociada: [TuM2-0065-alta-edicion-productos.md](./TuM2-0065-alta-edicion-productos.md)
- Enforce de capacidad: [TuM2-0123-limites-capacidad-catalogo.md](./TuM2-0123-limites-capacidad-catalogo.md)
- Entrada de módulo: OWNER-01 / Mi comercio.
- Gate de acceso aplicado: usuarios no-owner no ven ni acceden a gestión de productos (`/owner/products` bloqueado por guards + UI).

## Estado de cierre funcional
- El flujo de alta/edición OWNER quedó alineado con las pantallas de referencia entregadas.
- Se validó interacción de disponibilidad/ocultamiento/reactivación desde catálogo OWNER.
- Queda pendiente únicamente QA manual final en dev/staging con casos owner y owner_pending.

## Guardrails de arquitectura (obligatorios)
- No escritura cliente a `merchant_public`.
- Enforce de capacidad server-side (sin bypass en cliente).
- Sin listeners permanentes innecesarios en OWNER productos.
- Queries acotadas por `merchantId` + `limit`.
- Claims/roles gestionados solo por backend autorizado.
