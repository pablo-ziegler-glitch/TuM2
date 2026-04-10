# Stage 5 — Production Hardening (2026-04-10)

## Objetivo

Cerrar la optimización de costo con verificación operativa continua y gating
automático pre-release.

## Cambios implementados

- `nightlyRefreshOpenStatuses` ahora escanea incrementalmente solo
  `visibilityStatus == visible` (menor volumen de lectura).
- Workflow de guardrail extiende salida con:
  - `finops-summary.json`
  - `finops-summary.md`
- Nuevo gate automático (`finops:gate`) sobre el resumen consolidado.
  - política estándar: `prod` falla en `warn` y `critical`.
  - política estricta opcional: `dev,staging,prod` fallan en `warn`.

## Plan de verificación (14 días)

1. Ventana inicial (Día 0-2)
- confirmar que `firestore-cost-guard` se ejecuta cada 6h sin errores de script.
- revisar artifacts `finops-summary.*` en cada corrida.

2. Estabilización (Día 3-7)
- comparar contra baseline previo:
  - read ops/día
  - write ops/día
  - snapshot listeners max
  - rules evaluations/día
- validar que `refreshOpenStatuses` reduce scans respecto al baseline.

3. Cierre (Día 8-14)
- recalibrar umbrales de `firestore_cost_thresholds.json` con datos reales.
- congelar política de gate para releases de producción.

## Criterios de aceptación

- Sin `critical` en prod por 7 días consecutivos.
- Sin desvío >20% en read ops diarios sin causa documentada.
- Gate `finops:gate` habilitado en workflow y efectivo en branch de release.

## Riesgos y mitigación

- Riesgo: picos por backfills manuales.
  - Mitigación: documentar excepción operativa y ejecutar ventana de guard acotada.
- Riesgo: warnings recurrentes en staging durante pruebas de carga.
  - Mitigación: mantener fail-on-warn estricto solo para prod en operación normal.
