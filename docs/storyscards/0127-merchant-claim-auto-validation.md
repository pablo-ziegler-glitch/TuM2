# TuM2-0127 — Validación automática inicial de claims

Estado: TODO  
Prioridad: P0 (MVP crítica)

## Objetivo
Reducir carga manual, bloquear casos inválidos temprano y mejorar tiempo de respuesta.

## Alcance IN
- Validar autenticación del usuario.
- Forzar email autenticado como email del claim.
- Validación de completitud mínima.
- Validación de evidencia obligatoria.
- Consistencia básica claim-comercio.
- Deduplicación inicial.
- Detección de conflicto obvio.
- Decisiones: continuar, pedir más info, derivar a revisión manual, bloquear por duplicado/inconsistencia severa.

## Casos que pasan directo a revisión manual
- Comercio ya reclamado o con owner activo.
- Evidencia contradictoria o insuficiente.
- Categorías sensibles.
- Múltiples claims sobre mismo comercio.
- Señales de riesgo/fraude.

## Dependencias
- TuM2-0126 flujo base.
- TuM2-0129 reglas de evidencia por categoría.
- TuM2-0130 fingerprints/hash + protección de sensibles.
- TuM2-0128 handoff hacia Admin.

## Guardrails de costo Firestore
- Validación server-side en callable/trigger con lecturas acotadas por claim y comercio.
- Prohibido escanear colecciones completas para dedupe; usar claves normalizadas e índices.
- Consultas de dedupe/conflicto con `limit(1..N acotado)`.
- Escribir solo cambios de estado efectivos (evitar reescrituras sin cambios).
