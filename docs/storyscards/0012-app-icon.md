# TuM2-0012 — Diseñar app icon

Estado: DONE  
Prioridad: P0  
Épica: Branding de TuM2

## Objetivo
Definir e integrar el app icon productivo de TuM2 y dejar versionada una variante promocional Mundialista.

## Resultado
- Ícono productivo base integrado como activo por defecto.
- Variante Mundialista guardada como asset promocional no activo.
- Android y Web/PWA cubiertos en el módulo mobile; iOS versionado en assets (sin carpeta iOS en este branch).
- Documentación en `docs/branding/APP_ICON.md` y `docs/branding/APP_ICON_MUNDIALISTA.md`.

## Decisiones
- El ícono normal es el ícono productivo principal.
- La variante Mundialista no reemplaza automáticamente el ícono base.
- La variante Mundialista requiere build/release específico para activarse como launcher icon.
- Remote Config no puede cambiar launcher icons nativos ya instalados.
- El modo admin mundialista existente activa los assets visuales mundialistas versionados en `web/assets/worldcup`.

## Fuera de alcance
- Sistema de sellos.
- Markers de mapa.
- Badges dinámicos.
- Branding snippets post-MVP.

## QA
- Validación visual por tamaños.
- Android adaptive icon.
- Web favicon/PWA.
- `flutter analyze`.

## Definition of Done
- Assets versionados.
- Ícono base activo.
- Variante Mundialista documentada.
- Documentación actualizada.
- CLAUDE.md actualizado.
