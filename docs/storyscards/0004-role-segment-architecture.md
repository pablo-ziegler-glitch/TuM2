# TuM2-0004 — Role / Segment Architecture (actualización por dominio claim)

Estado: DONE (actualizado)  
Prioridad: P0

## Objetivo de esta actualización
Integrar explícitamente el ciclo de claim de titularidad dentro del modelo de roles sin romper seguridad ni permisos existentes.

## Segmentos y estados relevantes
- `CUSTOMER`: usuario autenticado sin control operativo pleno del comercio.
- `owner_pending`: usuario con claim enviado/en revisión, con permisos limitados.
- `OWNER`: usuario aprobado para operar su comercio.
- `ADMIN`: rol revisor/autorizador del flujo claim.

## Reglas de transición
- `CUSTOMER -> owner_pending`: al enviar claim válido (`submitted`/`under_review`).
- `owner_pending -> OWNER`: solo por aprobación backend autorizada.
- `owner_pending -> CUSTOMER`: rechazo definitivo o baja del claim.
- No se permite `CUSTOMER -> OWNER` directo por envío de claim.

## Capacidades por estado (claim-sensitive)
- `CUSTOMER`: puede iniciar claim y consultar estado propio.
- `owner_pending`: puede ver estado/evidencias requeridas, completar info faltante, pero no operar módulos OWNER sensibles.
- `OWNER`: acceso operativo completo según modelo OWNER vigente.

## Dependencias
- TuM2-0054 auth.
- TuM2-0053 shell mobile.
- TuM2-0064 módulo OWNER.
- TuM2-0131 integración claim-roles.

## Guardrails de costo Firestore
- Resolver rol efectivo desde una fuente resumida (evitar fan-out de lecturas por pantalla).
- Evitar listeners permanentes multi-colección para decidir acceso.
- Queries de claims siempre scoped por `userId` y `status`, con `limit`.
