# TuM2 — App Icon Pack V3 exact-source

## Fuente usada

- Archivo fuente: `logo final v2.png`
- Dimensión fuente normalizada: `1254x1254`
- Master generado: `master/tum2_icon_master_1024.png`
- SHA-256 master: `5038adb26ee331553204b60218b13c92dab1bdfbaddac91541c18438489ee56a`

## Decisión crítica

Este pack **NO reconstruye** la M, **NO redibuja** el check y **NO reubica** el `²`.
Todos los PNG finales de store, launcher, iOS y web se derivan por resize desde el logo fuente real.

## Colores canónicos

- Fondo: `#0F766E`
- Check: `#0E5BD8` según fuente visual
- Blanco/neutral: `#F9F8F6` según fuente visual

## Alcance

- App Store 1024 PNG sin alpha.
- Play Store 512 PNG.
- Android legacy launcher por density.
- Android adaptive foreground + background.
- iOS AppIcon.appiconset con Contents.json.
- Web favicons 16/32/48 + favicon.ico.
- PWA any + maskable 192/512.
- Variantes internas dev/staging/prod.

## Nota sobre adaptive icon

`android/adaptive/ic_launcher_foreground.png` extrae el símbolo real con transparencia para usarlo sobre `#0F766E`.
El asset `ic_launcher_foreground_full_reference.png` queda solo como referencia visual de extracción completa.

## Validación visual

Ver `preview/validation_grid.png`.

## Reglas de uso

- `store/` y `env/prod/` son los únicos assets aptos para publicación.
- `env/dev/` y `env/staging/` tienen badge interno y no deben subirse a stores.
- No mezclar este paquete con sistema de sellos, markers de mapa ni badges post-MVP.
