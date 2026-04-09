# Functions Scripts

Scripts operativos para tareas de datos y mantenimiento.

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
