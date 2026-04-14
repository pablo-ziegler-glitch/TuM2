# TuM2-0064 — Implementar módulo OWNER (actualización por claims)

Estado: IN_PROGRESS  
Prioridad: P0 (MVP)

## Objetivo
Consolidar OWNER-01 como home operativo, incorporando convivencia segura entre `owner_pending` y `OWNER` frente al nuevo dominio de claims de titularidad.

## Alcance IN (actualizado)
- Dashboard OWNER-01 para usuarios `OWNER`.
- Variante de experiencia para `owner_pending`:
  - estado de claim y próximos pasos,
  - bloqueos de funciones OWNER no habilitadas,
  - CTAs para completar evidencia o esperar revisión.
- Resumen de estado del comercio y visibilidad pública.
- Accesos rápidos a módulos operativos habilitados por rol efectivo.
- Banners de alertas priorizadas (perfil incompleto, revisión pendiente, conflicto, etc.).

## Alcance OUT
- Edición completa de productos (TuM2-0065).
- Resolución de disputas complejas multi-actor (TuM2-0133 extendida).
- Verificación telefónica fuerte (TuM2-0132 fase 2).

## Reglas de integración con claims
- Enviar claim no habilita automáticamente dashboard OWNER completo.
- `owner_pending` tiene acceso parcial y contextual, no operativo pleno.
- La transición a `OWNER` depende de aprobación backend/autorizada.
- Si existe conflicto o duplicado, priorizar vista de estado de claim sobre acciones operativas.

## Dependencias
- TuM2-0004 roles/segmentos.
- TuM2-0053 shell y navegación.
- TuM2-0054 auth.
- TuM2-0126 flujo claim.
- TuM2-0131 integración claim-roles.

## Guardrails de costo Firestore
- Resolver acceso OWNER con estado resumido (`role + claimState`) en lectura acotada.
- Evitar listeners permanentes de claims en dashboard.
- Queries siempre scoped por `merchantId`/`userId` y con `limit`.
- Cache TTL para estado de rol/claim en shell y owner home.

## UX / Microcopy
- Mensajes directos y accionables para estados intermedios.
- Evitar confusión entre “reclamando comercio” y “comercio ya aprobado”.
- Mantener tono cercano TuM2 sin lenguaje legalista en pantalla operativa.
