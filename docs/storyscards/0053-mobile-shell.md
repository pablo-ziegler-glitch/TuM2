# TuM2-0053 — Shell mobile (actualización por estado de claim)

Estado: DONE (actualizado)  
Prioridad: P0

## Objetivo de esta actualización
Incorporar entry points y navegación contextual para usuarios en `owner_pending` y claims en revisión.

## Alcance de actualización
- Entry point a estado de claim desde shell/post-login.
- Ruteo contextual según estado del claim (`submitted`, `under_review`, `needs_more_info`, etc.).
- Guardas para impedir acceso pleno OWNER sin aprobación final.
- Placeholders/CTAs para completar evidencia o esperar revisión.

## Reglas de navegación
- Si usuario está `owner_pending`, la shell debe priorizar pantalla de estado de claim antes del panel OWNER completo.
- Si claim está `needs_more_info`, mostrar CTA directo para completar documentación.
- Si claim está `approved`, habilitar transición hacia experiencia OWNER.
- Si claim está `rejected` o `conflict_detected`, mostrar estado y canal de soporte/revisión.

## Dependencias
- TuM2-0004 roles/segmentos.
- TuM2-0054 auth.
- TuM2-0126 flujo claim.
- TuM2-0131 integración de roles.

## Guardrails de costo Firestore
- Resolver estado claim/rol con una lectura inicial y cache TTL en shell.
- Evitar listeners continuos para navegación; usar refresh por foco o acción.
- No consultar listados amplios de claims para usuario final; solo claim activo o últimos N con `limit`.
