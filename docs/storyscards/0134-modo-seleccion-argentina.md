# TuM2-0134 — Modo Selección Argentina + tarjeta pineada de próximo partido

Estado propuesto: TODO  
Prioridad propuesta: P1 condicional / MVP+ de lanzamiento estacional  
Tipo: Producto + Branding estacional + Mobile/Web pública + Admin Web + Backend  
Ventana objetivo: habilitable para junio 2026 si el MVP núcleo ya está estable  
Depende de: TuM2-0056, TuM2-0053, TuM2-0077, TuM2-0082, TuM2-0083, TuM2-0051  
No bloquea: release MVP core  
Feature flags obligatorias: sí

## 1) Objetivo
Implementar un feature estacional apagable por flags para:

- aplicar look & feel temático sutil en superficies públicas;
- mostrar una tarjeta especial pineada del próximo partido de Argentina;
- administrar partidos manualmente desde Admin Web;
- actualizar estado visible por timestamps (sin cron de refresco continuo);
- desaparecer automáticamente cuando no corresponda;
- mantener intacta la arquitectura de comercios y proyecciones públicas.

## 2) Decisiones cerradas
- La tarjeta **no** se modela como comercio.
- La UI pública lee un solo resumen: `seasonal_public/argentina_banner`.
- La proyección pública la escribe backend-only (Cloud Functions/Admin SDK).
- El estado temporal (`faltan_dias`, `faltan_horas`, `hoy_juega`, `en_juego`, `finalizado`, `hidden`) se deriva mayormente en cliente desde timestamps.
- Sin cron para cambiar estados cada minuto/hora.
- Todo con feature flags para rollback sin redeploy.

## 3) Modelo de datos propuesto
### Privado (admin-only)
- `seasonal_events/{eventId}`
- `seasonal_configs/world_mode`

### Público (read-only)
- `seasonal_public/argentina_banner`

### Regla de costo
No exponer listados públicos completos de eventos. Consumir 1 documento resumen cacheable con TTL.

## 4) Reglas de arquitectura y costo (obligatorias)
- Minimizar lecturas Firestore y eliminar listeners innecesarios.
- Evitar polling agresivo.
- Queries siempre con scope + `limit`/paginación real donde aplique.
- No-op write avoidance en la proyección pública.
- Sin writes redundantes en Cloud Functions.
- Respeto de patrón dual-collection existente (`merchants` + `merchant_public`) sin contaminación del dominio estacional.

## 5) Alcance funcional IN
- Flags: `world_mode_enabled`, `world_mode_theme_enabled`, `world_mode_pinned_card_enabled`, `world_mode_dismiss_enabled`, `world_mode_refresh_minutes`, `world_mode_live_refresh_minutes`.
- Admin Web: listado, alta/edición, publicar/despublicar/desactivar, toggles de modo/theme/pinned card, preview de estados.
- Mobile/Web pública: card pineada encima de resultados de búsqueda, no participa de ranking ni mapa.
- Backend: callables admin-only + triggers para construir proyección pública compacta.
- Rules: privado admin-only, público solo lectura.
- Analytics base de impresiones/click/dismiss/estado visible.
- Testing unitario, integración, reglas y widget/integration para superficies públicas.

## 6) Alcance OUT
- Marcador en vivo, minuto a minuto o API deportiva externa.
- Múltiples cards simultáneas.
- Motor genérico completo de campañas.
- Push notifications del partido.
- Uso de branding oficial FIFA/torneo.

## 7) Comportamiento temporal esperado
Ejemplo: kickoff 2026-06-16 22:00 (America/Argentina/Buenos_Aires).

- visible desde 2026-06-11 22:00 (pin lead 5 días);
- estado `faltan_n_dias` / `faltan_n_horas` / `hoy_juega` según cercanía;
- `en_juego` desde kickoff hasta `liveUntilAt` (default 110 min);
- `finalizado` hasta `finalizedUntilAt` (default 24h) si no existe próximo partido válido;
- desaparece al vencer TTL final;
- si existe nuevo partido en ventana activa, se pinea el nuevo.

## 8) Entregables obligatorios de cierre
- Implementación end-to-end (Admin + Backend + Mobile/Web pública).
- Rules + tests críticos en verde.
- Documentación actualizada (`CLAUDE.md` y esta storycard).
- Rollback por flags probado.
- Post-auditoría técnica con correcciones aplicadas antes de cerrar.

## 9) Prompt de arranque para Codex
El prompt operativo de implementación para esta tarjeta quedó versionado en:

- `docs/prompts/tum2-0134-codex-prompt.md`

Debe usarse como base de ejecución al iniciar la implementación de TuM2-0134.
