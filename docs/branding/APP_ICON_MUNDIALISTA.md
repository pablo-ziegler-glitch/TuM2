# APP_ICON_MUNDIALISTA — TuM2

## Objetivo
Versionar la variante promocional Mundialista para activación eventual de campaña.

## Estado
Variante promocional eventual (no activa por defecto como launcher icon nativo).

## Fuente del asset
- Pack usado: `tum2_mundialista_icon_pack.zip` (ingestado desde carpeta plana con `asset_manifest_flat.json`).
- Carpeta fuente operativa usada: `/home/pablo/Documentos/Tum2/logotipo/tum2_icon_assets_flat_single_folder/`.

## Reglas
- Exactamente 3 estrellas.
- No activo por defecto en prod.
- No reemplaza automáticamente al ícono base.

## Cuándo usar
- Campaña temporal.
- Build promocional dedicado.
- Metadata eventual de store/campaña.

## Cuándo NO usar
- Release productivo regular.
- Favicon permanente.
- Identidad base canónica.

## Rutas guardadas
- Variante versionada: `mobile/assets/branding/icons/mundialista/`.
- Artefactos fuente/docs: `docs/branding/assets/mundialista/`.
- Preview QA visual: `docs/branding/previews/validation_grid_mundialista.png`.
- Config opcional: `mobile/flutter_launcher_icons_mundialista.yaml`.

## Activación manual
### Build promocional launcher icon (Android/Web/iOS cuando exista módulo)
Desde `mobile/`:

```bash
dart run flutter_launcher_icons -f flutter_launcher_icons_mundialista.yaml
```

Luego generar build/release promocional.

### Activación visual en Admin Web (config existente modo mundialista)
- El modo admin mundialista ya activa assets `worldcup`.
- Se actualizaron los assets mundialistas consumidos por ese modo en `web/assets/worldcup/logo/` y `web/assets/worldcup/app_icon/`.
- Activación: `?tema=mundialista` / `?theme=worldcup` o toggle de tema en la topbar.

## Rollback
1. Reaplicar pack base.
2. Regenerar launcher icons con config base.
3. Generar nuevo build Android/iOS/Web.
4. Publicar release normal.

## Checklist visual
| Criterio | Resultado esperado |
|---|---|
| Estrellas | Exactamente 3 |
| Recorte | No corta estrellas ni M |
| Check | Visible en 96/48 |
| ² | Legible en tamaños medianos |
| Uso | Promocional, no productivo permanente |

## Relación con campañas mundialistas
Esta variante es un asset de campaña temporal y no redefine la identidad base del producto.

## Aclaración de alcance
No reemplaza ni implementa:
- TuM2-0013 (sistema de sellos).
- TuM2-0057 (markers de mapa).
- TuM2-0026 (badges/snippets post-MVP).

## Restricción técnica importante
Remote Config o config admin no pueden cambiar launcher icons nativos ya instalados en Android/iOS; eso siempre requiere un build/release nuevo.
