# TuM2-0128 — Revisión manual de claims en Admin Web

Estado: TODO  
Prioridad: P0 (MVP crítica)

## Objetivo
Crear el módulo Admin para revisar, comparar y resolver claims (aprobar, rechazar o pedir más información).

## Alcance IN
- Listado de claims.
- Filtros por estado, categoría, fecha, zona, conflicto y prioridad/riesgo.
- Vista detalle claim por claim.
- Timeline del caso.
- Evidencia cargada.
- Acciones: aprobar, rechazar, pedir más info, marcar conflicto, derivar/escalar.
- Masking por defecto y reveal temporal auditado de sensibles.

## Reglas funcionales
- Sensibles no se muestran completos en listados.
- Reveal solo en vista de detalle.
- Reveal solo con permiso por rol y auditoría.
- No prometer “imposible copiar”: minimizar exposición y trazabilidad obligatoria.

## Dependencias
- TuM2-0126 base del claim.
- TuM2-0127 preclasificación automática.
- TuM2-0130 seguridad de sensibles.
- TuM2-0131 integración de aprobación con roles.
- TuM2-0133 conflictos/duplicados.

## Guardrails de costo Firestore
- Tabla admin paginada por cursor, siempre con `limit`.
- Filtros obligatorios por `status` + `zoneId` para evitar queries amplias.
- Sin listeners permanentes sobre todo `merchant_claims`; refresco manual o intervalo amplio controlado.
- Cargar detalle/evidencia on-demand, no en listado.
