# TuM2 - Produccion - Runbook Critico

Checklist minimo para evitar bloqueos funcionales en lanzamiento.

## 1) Seed de `zones` (obligatorio antes del import admin)

Sin `zones`, el wizard de import no permite avanzar en "Zona destino".

Comando (primero dry-run):

```bash
cd functions
npm run seed:zones:csv -- \
  --csv "../docs/storyscards/Copia de Base de datos Farmacias - datos.salud.gob.ar - a Enero 2026 - Copia de Base farmacias (1).csv" \
  --project tum2-prod
```

Aplicar:

```bash
cd functions
npm run seed:zones:csv -- \
  --csv "../docs/storyscards/Copia de Base de datos Farmacias - datos.salud.gob.ar - a Enero 2026 - Copia de Base farmacias (1).csv" \
  --project tum2-prod \
  --apply
```

Validaciones posteriores:

- Confirmar que existe colección `zones` con documentos.
- Confirmar que en Admin Web se carga el dropdown de "Zona destino".
- Confirmar que una importación de prueba genera `import_batches` y
  `external_places` con `zoneId`.

Referencia script: `functions/scripts/seed_zones_from_csv.js`.

## 2) Reglas desplegadas en el project correcto

```bash
firebase deploy --only firestore:rules,storage --project tum2-prod
```

Verificar especialmente:

- `match /zones/{zoneId}` con `allow read`.
- Sintaxis válida de funciones en `firestore.rules`.

## 3) Backfill operativo de búsqueda

Ejecutar callable admin de backfill de `searchKeywords` en `merchant_public`
según el procedimiento en `docs/qa/SEARCH-CIERRE-TECNICO.md`.

## 4) Smoke test obligatorio

- Login admin web.
- Carga de zonas visible.
- Import batch de prueba completo.
- Vista pública y búsqueda por zona retornan resultados.
