# APP_ICON — TuM2

## Objetivo
Integrar el ícono productivo base definitivo de TuM2 como ícono activo por defecto.

## Estado
Aprobado / productivo principal.

## Fuente del asset
- Pack usado: `tum2_app_icon_pack_v3_exact_source.zip` (ingestado desde carpeta plana con `asset_manifest_flat.json`).
- Carpeta fuente operativa usada: `/home/pablo/Documentos/Tum2/logotipo/tum2_icon_assets_flat_single_folder/`.

## Rutas integradas
- Activo Android: `mobile/android/app/src/main/res/**` (`mipmap-*`, `mipmap-anydpi-v26`, `values/colors.xml`).
- Activo Web/PWA mobile: `mobile/web/**` (`favicon`, `apple-touch`, `manifest.json`, `site.webmanifest`, `icons`, `manifest-icons`).
- Versionado base: `mobile/assets/branding/icons/base/`.
- Documentación/artefactos fuente: `docs/branding/assets/base/`.
- Preview QA visual: `docs/branding/previews/validation_grid.png`.

## Tamaños incluidos
- App Store: 1024.
- Play Store: 512.
- Android densities: mdpi/hdpi/xhdpi/xxhdpi/xxxhdpi.
- Android adaptive: foreground + background + XML v26.
- iOS AppIcon: versionado en `mobile/assets/branding/icons/base/ios/AppIcon.appiconset/`.
- Web favicons: 16/32/48 + `favicon.ico`.
- PWA icons: 192/512 + maskable 192/512.

## Decisión
Este es el ícono activo por defecto en el proyecto (Android + Web/PWA del módulo mobile).

## Validación de legibilidad
| Tamaño | Uso | Criterio |
|---|---|---|
| 1024 | App Store master | Sin pixelado, sin blur |
| 512 | Play Store | Bordes limpios, composición centrada |
| 192 | Android xxxhdpi / PWA | M² reconocible |
| 180 | Apple touch icon | Correcto en iOS Safari |
| 96 | Launcher medio | Check visible |
| 48 | Launcher bajo | Silueta clara |
| 32 | Favicon | Reconocimiento mínimo de marca |
| 16 | Browser tab | Sobrevive como mancha/silueta |

## Checklist de producción
- Base activo en Android.
- Base activo en Web/PWA.
- `flutter_launcher_icons_base.yaml` agregado para regeneración futura.
- Sin cambios en backend/Firebase/rules/secrets.

## Rollback
1. Restaurar assets previos desde Git.
2. Revertir commit/PR.
3. Si se usa `flutter_launcher_icons`, regenerar con config base anterior.
4. Publicar nuevo build/release.

## Cómo regenerar
Desde `mobile/`:

```bash
dart run flutter_launcher_icons -f flutter_launcher_icons_base.yaml
```

Si `flutter_launcher_icons` no está instalado en el entorno, mantener la copia manual de assets ya versionada.

## Qué NO incluye
- Sistema de sellos (TuM2-0013).
- Markers de mapa (TuM2-0057).
- Badges/snippets post-MVP (TuM2-0026).

## Nota iOS
En este branch no existe carpeta `mobile/ios/`. Por eso el AppIcon iOS quedó versionado en assets/documentación para activación cuando el módulo iOS esté presente.
