# TuM2 — Reglas de ejecución para agentes

Estas reglas son **restricción de arquitectura de primer nivel** para cualquier cambio en este repositorio.

## 1) Restricción principal: costo Firestore

Todo diseño, refactor o feature debe incluir explícitamente:

- minimización de lecturas Firestore
- eliminación de listeners innecesarios
- uso obligatorio de límites (`limit`) y/o paginación real
- evitar queries amplias sin scope (`zoneId`, `visibilityStatus`, y filtros equivalentes)
- preferencia por cache + TTL/control de invalidez frente a realtime permanente
- evitar polling/refetch agresivo
- reducción de writes redundantes en Cloud Functions
- diseño orientado a costo desde el inicio

Si una propuesta rompe esto, se considera **error crítico con impacto económico**.

## 2) Reglas no negociables de arquitectura

- Patrón dual-collection obligatorio: `merchants` (privado) + `merchant_public` (proyección pública).
- `merchant_public` nunca se escribe desde cliente; solo Cloud Functions.
- Custom claims solo vía Admin SDK en Cloud Functions.
- Contribuciones anónimas con `ipHash`, nunca IP cruda.
- Campos canónicos: usar `zoneId` y `categoryId` (evitar `zone` / `category` salvo compatibilidad legacy controlada).

## 3) Ambientes válidos

- `tum2-dev-6283d`
- `tum2-staging-45c83`
- `tum2-prod-bc9b4`

No usar `tum2-dev` (huérfano).

