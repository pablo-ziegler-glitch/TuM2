# TuM2-0068 — Revisión de seguridad y refactor

Fecha: 2026-04-13  
Alcance: `pharmacy_duties` (Functions, Rules, Mobile OWNER, documentación)

## Resumen ejecutivo

Se auditó el flujo de carga de turnos de farmacia con foco en:

- control de acceso (ownership + rol),
- integridad de datos (conflictos, timezone, estado),
- superficie de ataque en cliente y backend,
- consistencia documental.

Resultado general:

- Riesgos críticos: 0 abiertos.
- Riesgos altos: 0 abiertos.
- Riesgos medios: 3 abiertos (deuda controlada, sin bloqueo de release MVP).

## Hallazgos resueltos

1. Escritura directa de `pharmacy_duties` desde cliente.
- Estado: RESUELTO.
- Acción: rules actualizadas para negar mutación OWNER directa; mutación por callable server-side.

2. Validaciones sensibles dispersas en cliente.
- Estado: RESUELTO.
- Acción: `upsertPharmacyDutiesBatch` centraliza ownership, rubro farmacia, conflicto y timestamps server-side.

3. Superposición de turnos publicados.
- Estado: RESUELTO.
- Acción: validación de solapamiento temporal en backend con ventana `date-1/date/date+1`.

4. Inconsistencia de estado en triggers/jobs (`isActive` legado).
- Estado: RESUELTO.
- Acción: `duties.ts` y `refreshDuties.ts` migrados a `status == published`.

5. Desfase de alcance: carga masiva visible sin backend seguro.
- Estado: RESUELTO (scope hardening).
- Acción: ruta y accesos rápidos de carga masiva retirados de navegación productiva; documentación marcada `DEFERRED`.

6. TOCTOU en resolución de merchant para upsert.
- Estado: RESUELTO.
- Acción: lectura de merchant movida dentro de transacción.

7. Writes redundantes en publicación mensual.
- Estado: RESUELTO.
- Acción: callable batch con detección de filas sin cambios (`unchangedRows`) para evitar escrituras innecesarias.

## Riesgos abiertos (no bloqueantes MVP)

1. Rate limiting de callables de turnos.
- Severidad: Media.
- Riesgo: spam de mutaciones y toggle de estado.
- Mitigación actual: auth obligatoria + ownership + App Check.
- TODO: límite por `uid+merchantId` por ventana temporal.

2. Pruebas de integración en emulador para callables de turnos.
- Severidad: Media.
- Riesgo: regresiones en edge cases de reglas/transacciones.
- Mitigación actual: tests unitarios de utilidades + build/lint.
- TODO: suite integration para conflicto/ownership/edición concurrente.

3. App Check end-to-end en cliente.
- Severidad: Media.
- Riesgo: callable rechazada en entornos si App Check no inicializa correctamente.
- Mitigación actual: callables con `enforceAppCheck: true`.
- TODO: validar bootstrap App Check por entorno (`dev/staging/prod`) y fallback DX.

## Refactors aplicados

- Centralización de reglas de dominio en `functions/src/lib/pharmacyDuties.ts`.
- Mapeo explícito de errores de conflicto/concurrencia en repositorio móvil.
- Estados visuales de conflicto y confirmación conectados a respuestas reales de backend.
- Alineación de documentación de rutas/permisos/modelo de datos con implementación real.

## TODOs priorizados

P0 (siguiente sprint):
- Agregar test de integración de callable batch (`upsertPharmacyDutiesBatch`) en emulator suite.
- Agregar observabilidad por acción: `action`, `result`, `conflictReason`, `merchantId`, `dutyId`.

P1:
- Implementar rate limiting de mutaciones por `uid+merchantId`.
- Exponer feature flag explícito para edición de fechas pasadas (`owner_pharmacy_duties_edit_past_enabled`) también en backend.

P2:
- Preparar OWNER-12 (bulk) con backend dedicado y seguridad por fila antes de reactivar navegación.
