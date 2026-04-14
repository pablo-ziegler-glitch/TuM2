# TuM2-0081 — Impacto de claims en revisión/edición de perfil de comercio

Estado: TODO (actualización por impacto cruzado)  
Prioridad: P1

## Objetivo
Evitar inconsistencias entre estado de claim y capacidades de edición/revisión del perfil de comercio.

## Alcance de actualización
- Definir qué campos puede editar un `owner_pending`.
- Definir qué campos quedan solo visibles hasta aprobación.
- Integrar señales de claim en revisiones administrativas del perfil.
- Evitar mezclar flujo operativo OWNER pleno con claim en revisión.

## Dependencias
- TuM2-0126, 0128, 0131.
- TuM2-0064 módulo OWNER.
- TuM2-0004 roles.

## Guardrails de costo Firestore
- Consultas de revisión de perfil siempre scoped por `merchantId` y estado.
- Sin listeners globales entre perfil + claims + señales.
