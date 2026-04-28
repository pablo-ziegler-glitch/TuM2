# TuM2 — App Icon Pack Mundialista

## Fuente usada

- Archivo fuente: `golden_m2_icon_with_checkmark_and_stars.png`
- Archivo recortado usado: `source/mundialista_source_cropped_used.png`
- Master generado: `master/tum2_mundialista_icon_master_1024.png`
- SHA-256 master: `4e1885fec18a0416d41c2c0ac54aca5961a86cd57d843394432847f1dcab54d7`

## Decisión crítica

Este pack mundialista **NO reconstruye** la M, **NO redibuja** el check y **NO modifica** las estrellas.
Todos los PNG finales se derivan del logo mundialista aprobado.

## Recorte aplicado

Se aplicó recorte óptico para reducir aire exterior y priorizar:
- M dorada.
- `²`.
- Check celeste/azul.
- Exactamente 3 estrellas superiores.

Se ignoraron rayos/fondo muy tenues cuando podían agrandar innecesariamente el canvas.

## Alcance

- App Store 1024 PNG sin alpha.
- Play Store 512 PNG.
- Android legacy launcher por density.
- Android adaptive foreground + background.
- iOS AppIcon.appiconset con Contents.json.
- Web favicons 16/32/48 + favicon.ico.
- PWA any + maskable 192/512.
- Variantes internas dev/staging/prod promocionales.
- Preview de validación.
- Checksums.

## Reglas de uso

- Esta variante es promocional/temporal.
- No reemplaza el app icon productivo base salvo decisión explícita de campaña.
- `env/dev_promo` y `env/staging_promo` son solo internos.
- No mezclar con TuM2-0013, TuM2-0057 ni TuM2-0026.
