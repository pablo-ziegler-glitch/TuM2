# TuM2-0011 — Sistema de Identidad y Assets (FINAL)

Estado: aprobado  
Versión operativa: `branding_v1`  
Fuente única de verdad: `design/branding_v1.json`

## 1) Principios

- El logo de TuM2 es infraestructura operativa de confianza.
- Este sistema aplica a mobile, web pública, admin panel y material físico.
- La paleta base está bloqueada y no acepta nuevos colores base sin revisión.

## 2) Core Logo

- Isotipo: octógono redondeado con fondo `#0E5BD8` y marca `M²` blanca.
- Regla crítica: el `²` es parte integrada de la marca.
- Wordmark:
  - `Tu` → `#0F766E`
  - `M²` → `#0E5BD8`

## 3) Reglas de Construcción

- Grid base: 8x8.
- Caja de construcción del isotipo: 1:1.
- Radio del octógono: `22%` del lado.
- Padding interno para marca `M²`: `22%` del lado.
- Safe area externo mínimo: `12%` del lado sobre cualquier fondo.

## 4) Variantes de Asset

Definidas en `mobile/assets/branding/`:

- `logo_core_filled.svg`
- `logo_core_outline.svg`
- `logo_core_mono_dark.svg`
- `logo_core_transparent.svg`
- `wordmark_primary.svg`
- `map_marker_normal.svg`
- `map_marker_selected.svg`
- `map_marker_guard.svg`

## 5) Tamaños Mínimos

- Favicon: `16px`
- Android mínimo UI: `24dp`
- Toolbar/headers: `48dp`
- Master store export: `1024px`

## 6) Sistema Operativo de Badges

Semántica obligatoria global:

- `Abierto` → `#0F766E`
- `24hs` → `#0E5BD8`
- `GUARDIA` → `#DC2626`
- `Cerrado` → gris neutro

Regla de jerarquía:

- En farmacia de turno, `GUARDIA` domina visualmente sobre cualquier otro badge.

## 7) Marker System (Mapa)

Estados oficiales implementados para SEARCH-03:

- Base: `guardia`, `open`, `open24h`, `defaultState`, `closed`
- Visual selected: `selectedGuardia`, `selectedOpen`, `selectedOpen24h`, `selectedDefaultState`, `selectedClosed`
- Prioridad de resolución: `guardia > open24h > open > closed > default`
- Regla de selección: no altera estado de negocio, solo variante visual

Clustering (desacoplado de marker):

- Activación: más de 20 comercios visibles
- Agrupación: por grilla (grid-based)
- Prioridad de cluster: guardia > open > default > closed
- Tap en cluster: zoom in + centrado

Condición de UX:

- Debe poder diferenciarse estado operativo en mapa sin leer texto.

## 8) App Icon Compliance

- Android adaptive icon:
  - inset recomendado: `18%`
  - respetar máscara del launcher.
- iOS app icon:
  - inset recomendado: `16%`
  - sin transparencia en export final.

## 9) Motion mínimo

- Splash: fade + scale del logo (`320ms`).
- Badges: aparición rápida (`180ms`).
- Sin animaciones complejas por fuera de estos mínimos.

## 10) Integración en Flutter

- Tokens operativos centralizados en:
  - `mobile/lib/core/theme/app_brand.dart`
- Widgets base:
  - `mobile/lib/core/widgets/tum2_brand_widgets.dart`
- Uso requerido: referenciar `AppBrand` y no hardcodear colores semánticos.

## 11) DevOps y gobernanza

- Versionado semántico de branding: `branding_v1`.
- Cualquier cambio de assets o paleta:
  1. actualizar `design/branding_v1.json`
  2. actualizar assets en `mobile/assets/branding/`
  3. registrar cambio en PR con revisión de diseño/producto.

## 12) Definition of Done (TuM2-0011)

- [x] SVG master con variantes operativas
- [x] Sistema de marker de mapa definido e integrado en SEARCH-03
- [x] Sistema de clustering base integrado en SEARCH-03
- [x] Reglas de safe area / grid / tamaños mínimos documentadas
- [x] Integración base en Flutter (`AppBrand` + widgets)
- [x] Semántica de badges aplicada en vistas críticas
- [ ] Export PNG multi-tamaño (pendiente de pipeline de export)
- [ ] Empaquetado final de app icon iOS/Android (pendiente de build release)
