# Firestore Cost Guardrails — TuM2

## Objetivo

Evitar regresiones de costo antes de llegar a producción, con controles automáticos y alertas operativas mínimas.

Ambientes válidos:

- `tum2-dev-6283d`
- `tum2-staging-45c83`
- `tum2-prod-bc9b4`

No usar `tum2-dev` (huérfano).

## 1) Gate automático de regresión (pre-release)

Script implementado:

- [functions/scripts/firestore_cost_guard.js](/home/pablo/IdeaProjects/TuM2/functions/scripts/firestore_cost_guard.js)

Umbrales por ambiente:

- [docs/ops/firestore_cost_thresholds.json](/home/pablo/IdeaProjects/TuM2/docs/ops/firestore_cost_thresholds.json)
- Baseline DAU para métrica `R/DAU`:
  [docs/ops/firestore_activity_baselines.json](/home/pablo/IdeaProjects/TuM2/docs/ops/firestore_activity_baselines.json)

Ejemplos de ejecución:

```bash
cd functions

# staging: falla solo en crítico
npm run cost:guard -- \
  --project tum2-staging-45c83 \
  --env staging \
  --window-hours 24

# prod: falla también en warning
npm run cost:guard -- \
  --project tum2-prod-bc9b4 \
  --env prod \
  --window-hours 24 \
  --fail-on-warn \
  --out ../docs/ops/generated/cost-guard-prod.json

# override opcional de DAU real del día para R/DAU
npm run cost:guard -- \
  --project tum2-prod-bc9b4 \
  --env prod \
  --window-hours 24 \
  --active-users 27310
```

Política recomendada:

- `dev`: no bloqueante (solo diagnóstico).
- `staging`: bloquea en `critical`.
- `prod`: bloquea en `warn` y `critical`.

## 2) Alertas operativas (Cloud Monitoring)

Configurar alertas sobre estas métricas:

- `firestore.googleapis.com/document/read_ops_count`
- `derived/read_ops_per_dau` (desde output del guardrail)
- `firestore.googleapis.com/document/write_ops_count`
- `firestore.googleapis.com/document/delete_ops_count`
- `firestore.googleapis.com/network/snapshot_listeners`
- `firestore.googleapis.com/rules/evaluation_count`

Recomendación práctica:

1. Crear una policy por métrica y ambiente.
2. Ventana de evaluación: 15 minutos para picos; 24h para presupuesto operativo.
3. Canales mínimos:
- Email de guardia técnica.
- Canal de incidentes (Slack/Webhook).
4. Severidad:
- `warning` al 80% del umbral diario.
- `critical` al 100% del umbral diario.

## 3) Budget alerts (facturación)

Definir 3 budgets separados (dev/staging/prod), con umbrales:

- 50%: info
- 80%: warning
- 100%: critical

Filtro recomendado:

- Servicio: Cloud Firestore
- Proyecto exacto del ambiente

Validación mensual:

- Revisar desvíos de costo vs baseline.
- Ajustar umbrales de [firestore_cost_thresholds.json](/home/pablo/IdeaProjects/TuM2/docs/ops/firestore_cost_thresholds.json) según tráfico real.

## 4) Dashboard mínimo por ambiente

Widgets obligatorios:

1. Read ops (sum 1h y 24h).
2. R/DAU (read ops / DAU diario).
3. Write ops (sum 1h y 24h).
4. Delete ops (sum 1h y 24h).
5. Snapshot listeners (max 15m / 1h).
6. Rules evaluations (sum 1h y 24h).
7. Top Cloud Functions por invocación y error.
8. Logs estructurados de jobs nocturnos:
- `nightlyRefreshOpenStatuses`
- `nightlyRefreshPharmacyDutyFlags`
- `nightlyCleanupExpiredDrafts`
9. Logs FinOps estructurados (`logType = finops.cost.v1`) por módulo:
- `jobs.refreshOpenStatuses`
- `coverage.zoneCoverage`
- `triggers.duties`
- `triggers.reports`

## 4.1) Eventos y logs concretos a seguir

- `guardrail.firestore_cost.readOps` (resultado métrica base `readOps`).
- `guardrail.firestore_cost.readOpsPerDau` (resultado métrica derivada `readOpsPerDau`).
- `guardrail.firestore_cost.snapshotListeners` (resultado métrica base `snapshotListeners`).
- `finops.cost.v1 / trigger_signals_projection` (deduplicación de eventos y writes evitados).
- `finops.cost.v1 / trigger_reports_threshold_eval` (evaluación de suppress thresholds).
- `finops.cost.v1 / trigger_duties_sync` (sync de proyección duty por evento).
- `finops.cost.v1 / job_refresh_open_statuses_window` (batch nocturno y drift control).
- `finops.cost.v1 / job_zone_coverage_window` (refresh por ventana de cobertura).

## 5) Gate de release (checklist)

Antes de promover `staging -> prod`:

- [ ] `npm run cost:guard` en `tum2-staging-45c83` sin `critical`.
- [ ] `npm run cost:guard -- --fail-on-warn` en `tum2-prod-bc9b4` sobre última ventana conocida.
- [ ] Sin alertas `critical` abiertas en Monitoring.
- [ ] Sin desvío >20% de read ops vs baseline semanal.
- [ ] Sin query amplia no scopeada (`zoneId`, `visibilityStatus`, `limit/paginación`).
- [ ] `readOpsPerDau` en `OK` para el ambiente objetivo.

## 6) Integración CI

Workflow incluido:

- [.github/workflows/firestore-cost-guard.yml](/home/pablo/IdeaProjects/TuM2/.github/workflows/firestore-cost-guard.yml)

Requisitos mínimos en GitHub:

- Secret `GCP_MONITORING_SA_KEY` con una service account que tenga permisos de lectura de Monitoring.

Modo de uso:

- `workflow_dispatch` para validar un ambiente puntual antes de release.
- `schedule` cada 6h como monitoreo continuo.
- El workflow ejecuta además:
  - `npm run finops:summary` (json + markdown)
  - `npm run finops:gate` para bloquear `critical` siempre y `warn` según política.

## 7) Notas de operación

- El guardrail usa métricas de Monitoring reales; no reemplaza revisión de Query Explain para casos puntuales.
- Si el guardrail falla por picos puntuales esperados (ej. backfill admin), ejecutar ventana acotada y documentar excepción operativa.

## 8) Resumen semanal FinOps

Después de ejecutar `cost:guard` en ambientes activos, consolidar resultados:

```bash
cd functions
npm run finops:summary -- \
  --input-dir ../docs/ops/generated \
  --markdown \
  --out ../docs/ops/generated/finops-summary.md
```

Checklist semanal mínimo:

- revisar `worst` por ambiente (`OK` esperado en dev/staging, `OK/WARN` justificado en prod).
- abrir incidente si aparece `CRITICAL`.
- registrar desvíos y acciones en el tablero operativo.
