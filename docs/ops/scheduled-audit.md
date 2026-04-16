# Scheduled Audit (GitHub Actions + Gemini)

Auditoría incremental de TuM2 orientada a costo mínimo y trazabilidad.

## Qué hace

- Corre 4 veces por día (hora Buenos Aires): 06:00, 12:00, 16:00, 20:00.
- Audita siempre `origin/develop` aunque el workflow viva en default branch.
- Usa estado persistido en issue técnico `[audit-state] develop` (sin commits automáticos).
- Si no hay diff incremental: termina en verde, no consume Gemini y deja resumen.
- Si hay diff: construye contexto incremental acotado (`max files/chars`) y audita por dominios.
- Sube artifact markdown de auditoría cuando hubo auditoría efectiva.
- Abre/comenta issue solo si:
  - hay >=1 `CRITICO`, o
  - hay >=2 `ALTO`, o
  - conclusión `NO_APTO`.

## Archivos clave

- `.github/workflows/scheduled_audit.yml`
- `tools/audit/run-scheduled-audit.mjs`
- `tools/audit/build-audit-context.mjs`
- `tools/audit/github-state.mjs`
- `tools/audit/report-schema.mjs`

## Configuración en GitHub

### Secretos obligatorios

- `GEMINI_API_KEY`

### Variables opcionales

- `AUDIT_TARGET_BRANCH` (default: `develop`)
- `AUDIT_MODEL` (default: `gemini-2.5-flash`)
- `AUDIT_ARTIFACT_RETENTION_DAYS` (default: `30`)
- `AUDIT_MAX_FILES` (default: `25`)
- `AUDIT_MAX_INPUT_CHARS` (default: `220000`)

## Ejecución manual (workflow_dispatch)

Se puede forzar una auditoría amplia con `force_full_audit=true`.

Uso recomendado:

1. `force_full_audit=false` para operación normal incremental.
2. `force_full_audit=true` solo ante incidentes o drift significativo.

## Operación / troubleshooting

- Si Gemini falla, el pipeline genera artifact con diagnóstico y **no** actualiza `lastAuditedSha`.
- El estado solo se actualiza cuando la auditoría termina correctamente.
- Dedupe de issues por fingerprint de hallazgo para evitar ruido.

## Costo y seguridad

- No envía secretos al prompt (sanitización defensiva).
- Limita tamaño total de input y cantidad de archivos por batch.
- Evita auditoría completa por defecto.
- Evita consumo de API cuando no hay cambios.
