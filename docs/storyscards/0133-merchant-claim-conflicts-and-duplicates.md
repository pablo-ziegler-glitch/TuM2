# TuM2-0133 — Conflictos, duplicados y disputa de titularidad

Estado: TODO (MVP acotada)  
Prioridad: P0

## Objetivo
Resolver casos con claims duplicados o conflictivos sin aprobaciones inseguras.

## Alcance IN
- Detección de duplicado.
- Detección de conflicto.
- Rutas administrativas de resolución.
- Bloqueo de aprobaciones contradictorias.
- Estados: `duplicate_claim`, `conflict_detected`, `existing_owner_conflict`.
- Criterios para pedir más evidencia.

## MVP recomendado
- No exige automatización compleja.
- Sí exige detectar, congelar, derivar a revisión manual y evitar aprobación lineal insegura.

## Dependencias
- TuM2-0127 validación automática.
- TuM2-0128 admin claims.
- TuM2-0131 roles.
- TuM2-0130 seguridad de datos.

## Guardrails de costo Firestore
- Detección por claves normalizadas/indexadas; no scans globales.
- Consultas con `limit` estricto para encontrar conflictos inmediatos.
- Resolución manual por lotes paginados y scoped por zona/estado.
