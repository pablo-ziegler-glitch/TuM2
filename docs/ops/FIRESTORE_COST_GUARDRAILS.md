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
```

Política recomendada:

- `dev`: no bloqueante (solo diagnóstico).
- `staging`: bloquea en `critical`.
- `prod`: bloquea en `warn` y `critical`.

## 2) Alertas operativas (Cloud Monitoring)

Configurar alertas sobre estas métricas:

- `firestore.googleapis.com/document/read_ops_count`
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
2. Write ops (sum 1h y 24h).
3. Delete ops (sum 1h y 24h).
4. Snapshot listeners (max 15m / 1h).
5. Rules evaluations (sum 1h y 24h).
6. Top Cloud Functions por invocación y error.
7. Logs estructurados de jobs nocturnos:
- `nightlyRefreshOpenStatuses`
- `nightlyRefreshPharmacyDutyFlags`
- `nightlyCleanupExpiredDrafts`

## 5) Gate de release (checklist)

Antes de promover `staging -> prod`:

- [ ] `npm run cost:guard` en `tum2-staging-45c83` sin `critical`.
- [ ] `npm run cost:guard -- --fail-on-warn` en `tum2-prod-bc9b4` sobre última ventana conocida.
- [ ] Sin alertas `critical` abiertas en Monitoring.
- [ ] Sin desvío >20% de read ops vs baseline semanal.
- [ ] Sin query amplia no scopeada (`zoneId`, `visibilityStatus`, `limit/paginación`).

## 6) Integración CI

Workflow incluido:

- [.github/workflows/firestore-cost-guard.yml](/home/pablo/IdeaProjects/TuM2/.github/workflows/firestore-cost-guard.yml)

Requisitos mínimos en GitHub:

- Secret `GCP_MONITORING_SA_KEY` con una service account que tenga permisos de lectura de Monitoring.

Modo de uso:

- `workflow_dispatch` para validar un ambiente puntual antes de release.
- `schedule` cada 6h como monitoreo continuo.

## 7) Notas de operación

- El guardrail usa métricas de Monitoring reales; no reemplaza revisión de Query Explain para casos puntuales.
- Si el guardrail falla por picos puntuales esperados (ej. backfill admin), ejecutar ventana acotada y documentar excepción operativa.
