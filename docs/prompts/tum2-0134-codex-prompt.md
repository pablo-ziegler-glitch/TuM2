# Prompt de ejecución Codex — TuM2-0134

Actuá como Staff Software Engineer / Principal Architect del proyecto TuM2 (Tu metro cuadrado), con foco en arquitectura productiva, seguridad, costo Firebase/Firestore, UX, testing y release readiness.

Quiero que implementes COMPLETA la tarjeta propuesta:

# TuM2-0134 — Modo Selección Argentina + tarjeta pineada de próximo partido

## Misión
Implementar un feature estacional, apagable por feature flags, que agregue:

1. un look and feel temático sutil “Modo Selección Argentina” en superficies públicas relevantes;
2. una tarjeta especial pineada del próximo partido de Argentina;
3. un módulo Admin Web para cargar/editar/desactivar partidos;
4. una proyección pública backend-only compacta, costo-eficiente y segura;
5. analytics, tests y documentación;
6. una post-auditoría obligatoria al final, corrigiendo lo detectado antes de cerrar.

## Restricciones clave
- No modelar la card como merchant.
- No escribir desde cliente en colecciones públicas.
- No agregar cron para refrescar estados temporales.
- Usar `seasonal_public/argentina_banner` como resumen público único.
- Minimizar costo Firestore: TTL, sin listeners globales, sin scans amplios, no-op write avoidance.
- Rollback sin redeploy por Remote Config.

## Datos y colecciones
- Privado: `seasonal_events/{eventId}`, `seasonal_configs/world_mode`
- Público: `seasonal_public/argentina_banner`
- Backend-only projection por Cloud Functions.

## Funciones objetivo
- `upsertSeasonalEvent` (callable admin-only)
- `toggleWorldMode` (callable admin-only)
- `rebuildArgentinaBannerProjection` (callable admin-only)
- triggers: `onSeasonalEventWrite`, `onSeasonalConfigWrite`

## Flags obligatorias
- `world_mode_enabled`
- `world_mode_theme_enabled`
- `world_mode_pinned_card_enabled`
- `world_mode_dismiss_enabled`
- `world_mode_refresh_minutes`
- `world_mode_live_refresh_minutes`

## Criterio de costo
- La UI pública debe leer 1 documento resumen con cache + TTL.
- Evitar listeners permanentes y polling agresivo.
- Evitar writes redundantes en la proyección.

## Criterio de Done
- Feature end-to-end implementado (Admin + Backend + Mobile/Web pública).
- Tests críticos de lógica temporal, integración y rules.
- Seguridad y App Check contemplados para callables admin.
- Documentación actualizada.
- Post-auditoría ejecutada con correcciones incluidas.
