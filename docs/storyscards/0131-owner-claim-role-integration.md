# TuM2-0131 — Integración de claim con roles OWNER / owner_pending / aprobación

Estado: TODO  
Prioridad: P0 (MVP crítica)

## Objetivo
Conectar el dominio de claim con el sistema de roles sin romper el modelo de seguridad.

## Alcance IN
- Definir cuándo un usuario pasa a `owner_pending`.
- Definir condiciones para transición a `OWNER` al aprobar claim.
- Definir manejo de claims rechazados.
- Definir visibilidad del estado del claim para usuario.
- Integrar con módulo OWNER actual/futuro.
- Manejar casos con comercio ya vinculado a otro owner.

## Regla clave
- Enviar claim no convierte automáticamente en OWNER.
- Durante revisión puede existir `owner_pending`.
- La transición de rol final es backend-only (Admin SDK/flujo autorizado).

## Dependencias
- TuM2-0004 arquitectura de roles.
- TuM2-0054 auth.
- TuM2-0064 módulo OWNER.
- TuM2-0128 resolución administrativa de claims.

## Guardrails de costo Firestore
- Resolver estado de acceso OWNER con documento resumido de pertenencia/estado, evitando múltiples lecturas en cascada.
- Sin listeners cruzados sobre claims + roles + merchants en splash.
- Cache TTL para estado de rol y claim en shell.
