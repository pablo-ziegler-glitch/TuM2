# TuM2-0104 — Retención, acceso interno y resguardo de datos sensibles (claims)

Estado: TODO  
Prioridad: P0

## Objetivo
Definir conservación, acceso interno y controles de seguridad para datos sensibles de claims.

## Debe incluir
- Criterios de conservación y eliminación.
- Auditoría de reveal interno de datos sensibles.
- Acceso segmentado por roles/permisos.
- Minimización de exposición y descarga.
- Tratamiento de evidencia documental en repositorio seguro.

## Dependencias
- TuM2-0130 seguridad de sensibles.
- TuM2-0128 admin review.
- TuM2-0100 privacidad.

## Guardrails de costo Firestore
- Retener metadatos necesarios y purgar datos no requeridos por política.
- Evitar replicar sensibles en proyecciones públicas o colecciones de alta lectura.
- Logs de auditoría append-only, acotados y con TTL/política de archivo.
