# TuM2-0126 — Flujo de claim del comercio (usuario / owner claimant)

Estado: TODO  
Prioridad: P0 (MVP crítica)

## Objetivo
Diseñar e implementar el flujo principal del usuario que reclama un comercio.

## Alcance IN
- Inicio de claim desde experiencia mobile/web.
- Email del claim tomado de la sesión autenticada (sin campo alternativo).
- Teléfono opcional en MVP, sin verificación.
- Selección/identificación controlada del comercio reclamado.
- Formulario simple por pasos.
- Carga inicial de evidencia.
- Envío del claim.
- Estados visibles: `draft`, `submitted`, `under_review`, `needs_more_info`, `approved`, `rejected`, `conflict_detected`, `duplicate_claim`.

## Alcance OUT
- Verificación fuerte de teléfono (TuM2-0132).
- Scoring antifraude avanzado.
- Resolución automática compleja de disputas.
- Transferencias complejas entre owners ya aprobados.

## Reglas funcionales
- Formulario corto y de baja fricción.
- Si el comercio ya existe, identificación guiada (no alta libre sin control).
- Evidencia mínima/adicional depende de categoría (ver TuM2-0129).

## Dependencias
- TuM2-0054 auth/sesión.
- `merchant_claims`.
- TuM2-0129 evidencia por categoría.
- TuM2-0131 integración de roles.
- TuM2-0100 a 0104 legal actualizado.

## Guardrails de costo Firestore
- Draft con persistencia explícita por acción (sin autosave agresivo ni listeners continuos).
- Consultas del estado del claim del usuario con `limit` + orden por `updatedAt`.
- Sin polling corto; refresco por foco o acción del usuario.
- Reutilizar cache local con TTL para metadata estática de categorías/evidencia.
