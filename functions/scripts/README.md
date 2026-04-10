# Functions Scripts

Scripts operativos para tareas de datos y mantenimiento.

## `firestore_cost_guard.js`

Gate de regresión de costo para Firestore basado en métricas reales de Cloud Monitoring.

### Qué controla

- `firestore.googleapis.com/document/read_ops_count`
- `firestore.googleapis.com/document/write_ops_count`
- `firestore.googleapis.com/document/delete_ops_count`
- `firestore.googleapis.com/network/snapshot_listeners` (máximo de la ventana)
- `firestore.googleapis.com/rules/evaluation_count`

Compara contra umbrales por ambiente definidos en:
`docs/ops/firestore_cost_thresholds.json`.

### Ejecución

```bash
cd functions

# Staging (24h), falla solo en umbral crítico
npm run cost:guard -- \
  --project tum2-staging-45c83 \
  --env staging \
  --window-hours 24

# Prod (24h), falla en warning o critical
npm run cost:guard -- \
  --project tum2-prod-bc9b4 \
  --env prod \
  --window-hours 24 \
  --fail-on-warn \
  --out ../docs/ops/generated/cost-guard-prod.json
```

### Requisitos

- `gcloud` instalado y autenticado.
- Permiso para leer métricas de Monitoring del proyecto objetivo.

### Códigos de salida

- `0`: OK.
- `2`: se superó umbral crítico.
- `3`: se superó warning y se pasó `--fail-on-warn`.
- `1`: error de ejecución/configuración.

## `finops_summary.js`

Consolida resultados generados por `firestore_cost_guard.js` en una vista
operativa simple por ambiente.

Entrada esperada:

- `docs/ops/generated/cost-guard-*.json`

### Ejecución

```bash
cd functions

# Resumen por consola
npm run finops:summary -- \
  --input-dir ../docs/ops/generated

# Resumen JSON consolidado
npm run finops:summary -- \
  --input-dir ../docs/ops/generated \
  --out ../docs/ops/generated/finops-summary.json

# Resumen Markdown para reporte semanal
npm run finops:summary -- \
  --input-dir ../docs/ops/generated \
  --markdown \
  --out ../docs/ops/generated/finops-summary.md
```

## `finops_gate.js`

Evalúa el resumen consolidado y falla el proceso según política por ambiente.

### Ejecución

```bash
cd functions

# Política estándar: prod falla en warn/critical
npm run finops:gate -- \
  --summary ../docs/ops/generated/finops-summary.json \
  --fail-on-warn-envs prod

# Política estricta (release crítico): todos los ambientes fallan en warn
npm run finops:gate -- \
  --summary ../docs/ops/generated/finops-summary.json \
  --fail-on-warn-envs dev,staging,prod

# Evaluar solo un ambiente específico
npm run finops:gate -- \
  --summary ../docs/ops/generated/finops-summary.json \
  --only-envs staging \
  --fail-on-warn-envs prod
```

### Códigos de salida

- `0`: OK.
- `2`: al menos un ambiente en `critical`.
- `3`: `warn` detectado en un ambiente incluido en `fail-on-warn-envs`.

## `seed_zones_from_csv.js`

Carga/actualiza (`upsert`) documentos en `zones` desde un CSV de localidades.
Se diseñó para destrabar el flujo de import admin cuando el selector de zona no
tiene datos.

### CSV esperado

Columnas requeridas:

- `localidad_id`
- `localidad_nombre`
- `provincia_id`
- `provincia_nombre`
- `departamento_id`
- `departamento_nombre`
- `codloc`
- `codent`
- `cp`

### Ejecución

Dry-run (no escribe):

```bash
cd functions
npm run seed:zones:csv -- \
  --csv "../docs/storyscards/Copia de Base de datos Farmacias - datos.salud.gob.ar - a Enero 2026 - Copia de Base farmacias (1).csv" \
  --project tum2-dev-6283d
```

Aplicar escritura en Firestore:

```bash
cd functions
npm run seed:zones:csv -- \
  --csv "../docs/storyscards/Copia de Base de datos Farmacias - datos.salud.gob.ar - a Enero 2026 - Copia de Base farmacias (1).csv" \
  --project tum2-dev-6283d \
  --apply
```

### Parámetros

- `--csv <path>`: ruta al archivo CSV (requerido).
- `--project <projectId>`: Firebase project objetivo.
- `--collection <name>`: colección destino (default: `zones`).
- `--apply`: ejecuta escrituras (sin este flag, siempre dry-run).
- `--no-merge`: desactiva merge en `set()`.

### Notas operativas

- Deduplicación por `localidad_id` (1 documento por zona).
- Usa `status = public_enabled` y `launchPhase = mvp` por defecto.
- Si el CSV no trae coordenadas, marca `centroidMissing: true`.
- Recomendado: correr primero en `staging`, validar conteo y recién después en
  `prod`.
