# TuM2-0130 — Seguridad y protección de datos sensibles en claims

Estado: TODO  
Prioridad: P0 (MVP crítica)

## Objetivo
Aplicar un modelo de protección de sensibles específico para el dominio de claims.

## Alcance IN
- Clasificación de datos.
- Cifrado reversible para datos revisables por humanos.
- Fingerprint/hash para matching, dedupe y antifraude.
- Masking por defecto en UI.
- Reveal temporal en Admin con permisos.
- Auditoría de accesos a sensibles.
- Restricciones de exposición/descarga.

## Reglas centrales
- Cifrado reversible: nombre/apellido, teléfono, email visible de revisión, documentos adjuntos, identificatorios visibles.
- Fingerprint/hash: email normalizado, teléfono normalizado, huellas de documentos, `ipHash` y señales antifraude.
- Admin: masking por defecto + reveal temporal + trazabilidad.

## Dependencias
- TuM2-0128 Admin review.
- TuM2-0127 validación automática.
- TuM2-0100/0104 marco legal de retención/acceso.

## Guardrails de costo Firestore
- Evitar duplicar blobs o metadatos pesados en múltiples colecciones.
- Guardar derivados de matching compactos y versionados para consultas selectivas.
- Auditoría de reveal append-only con payload mínimo.
