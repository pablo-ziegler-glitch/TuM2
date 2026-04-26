# TuM2-0125 — Épica: Reclamo de titularidad de comercio

Estado: READY_FOR_QA
Prioridad: P0 (MVP crítica)

## Estado real de implementación (corte 2026-04-16)
### Hecho
- Backend MVP de claims en producción inicial: drafts, submit, evaluación automática, resolución manual, reveal sensible y listados paginados (`functions/src/callables/merchantClaims.ts`).
- Integración de rol intermedio `owner_pending` y promoción a OWNER aprobada en backend (`functions/src/callables/merchantClaims.ts`, `functions/src/triggers/claims.ts`).
- Mobile claim flow operativo (CLAIM-01..07) y estado de reclamo consumiendo callables reales (`mobile/lib/modules/merchant_claim/...`).
- Seguridad base activa: `merchant_claims` bloqueado a escritura/lectura cliente directa y storage privado de evidencia (`firestore.rules`, `storage.rules`).

### Falta para cerrar
- Cerrar tarjetas hijas aún abiertas/no iniciadas: TuM2-0129, TuM2-0132 y legales TuM2-0100..0104.
- Implementar UI Admin Web de revisión completa (cola, detalle, acciones y reveal) consumiendo callables ya disponibles.
- Completar trazabilidad de KPIs operativos en tableros (conversión, tiempos de decisión, falsos duplicados/conflictos).
- Ejecutar validación E2E final multi-módulo con foco en costo Firestore (filtros, `limit`, paginación real, cero listeners globales).

## Objetivo
Formalizar el dominio completo de reclamo de titularidad para que un usuario autenticado pueda reclamar un comercio existente o identificable, aportar evidencia, pasar validación automática y, si aplica, revisión manual en Admin.

## Decisiones canónicas cerradas
- El email del claim es el email de la cuenta autenticada.
- En MVP, el teléfono es opcional y sin verificación.
- La verificación de teléfono no bloquea MVP y se mueve a TuM2-0132 (fase 2).
- Todo claim pasa primero por validación automática.
- Casos con dudas, conflicto, inconsistencia o riesgo se derivan a revisión manual.
- Sensibles para revisión humana: cifrado reversible con acceso controlado.
- Datos para matching/antifraude/deduplicación: fingerprint/hash derivado.
- Admin: masking por defecto, reveal temporal y auditado, exposición restringida.
- Legal obligatorio: Privacidad, Términos y consentimientos específicos del flujo claim.

## Qué consolida
- Flujo de claim y estados.
- Evidencia por categoría.
- Validación automática inicial.
- Revisión manual en Admin Web.
- Seguridad de datos sensibles.
- Integración con roles CUSTOMER / owner_pending / OWNER.
- Manejo de duplicados y conflictos de titularidad.

## Estructura hija
- TuM2-0126 flujo de claim.
- TuM2-0127 validación automática inicial.
- TuM2-0128 revisión manual en Admin.
- TuM2-0129 evidencia por categoría.
- TuM2-0130 seguridad de sensibles.
- TuM2-0131 integración con roles OWNER/owner_pending.
- TuM2-0132 verificación de teléfono fase 2.
- TuM2-0133 conflictos y duplicados.

## Dependencias conceptuales
- `merchant_claims` (modelo de claim).
- TuM2-0004 (roles/segmentos).
- TuM2-0054 (auth).
- TuM2-0064 (módulo OWNER).
- TuM2-0100 a 0104 (legal).

## Guardrails de costo Firestore (obligatorio)
- Sin listeners globales de claims en mobile/admin; usar consultas paginadas y acciones manuales.
- Toda query de claims debe ir scoped por `zoneId`, `status`, `riskLevel` o filtros equivalentes.
- Listados admin con `limit` y paginación por cursor.
- Preferir cache con TTL para catálogos de estados/reglas por categoría.
- Evitar writes redundantes en triggers/functions (no-op write avoidance).

## Resultado esperado al cierre
- Claims válidos recibidos.
- Casos simples filtrados automáticamente.
- Casos complejos escalados a revisión manual.
- Protección de sensibles operativa.
- Transición segura hacia OWNER cuando corresponda.
