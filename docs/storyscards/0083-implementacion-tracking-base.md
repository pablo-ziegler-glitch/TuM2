# TuM2-0083 — Implementación tracking base (mobile + runtime web Flutter)

Fecha: 2026-04-24  
Estado: implementado (base operativa para 0084)

## 1. Alcance implementado

Se implementó tracking base sobre la capa central `AnalyticsService` existente, sin introducir listeners permanentes ni writes extra en Firestore para comportamiento general.

Prioridades aplicadas:
1. seguridad (guardrails de no-PII y allowlist estricta);
2. costo (Firebase Analytics con batching nativo; sin event-store en Firestore);
3. eficiencia operativa (dedupe/TTL ya existente + impresiones limitadas);
4. consistencia (taxonomía unificada en mobile/runtime web);
5. cobertura funcional (funnel vecino + claim separado + outdated híbrido mínimo).

## 2. Eventos 0083 instrumentados

### Contexto
- `session_started`
- `zone_resolved`
- `surface_viewed`

### Discovery / búsqueda
- `search_executed`
- `search_results_viewed`
- `search_filter_applied`
- `merchant_card_impression`
- `merchant_detail_opened`

### Acciones útiles generales
- `useful_action_clicked` (`action_type=whatsapp|call|directions`)

### Abierto ahora
- `open_now_viewed`
- `open_now_merchant_opened`
- `open_now_useful_action_clicked` (se emite cuando la acción útil se ejecuta en ficha abierta desde `open_now*`)

### Farmacias de turno
- `pharmacy_duty_list_viewed`
- `pharmacy_duty_detail_opened`
- `pharmacy_duty_useful_action_clicked`

### Información desactualizada (híbrido en 0083)
- `outdated_info_tapped`
- `outdated_info_confirmed`
- `outdated_info_report_submitted`

Persistencia operativa implementada:
- callable `submitOutdatedInfoReport` con payload mínimo y tipos cerrados (`reasonCode`);
- validación server-side (`merchant_public`, zona, categoría farmacia, fecha);
- rate limit por `ipHash` y ventana temporal;
- dedupe por `merchantId+zoneId+dateKey+reasonCode+ipHash`.

### Claim funnel (separado del funnel público)
- `claim_started`
- `claim_step_completed`
- `claim_submitted`
- `claim_abandoned`

## 3. Parámetros canónicos usados

Se incorporaron y validaron en allowlist:
- `surface`
- `zoneId`
- `categoryId`
- `merchantId`
- `action_type`
- `role`
- `platform`
- `source`
- `is_open_now_shown`
- `is_on_duty_shown`
- `results_count_bucket`
- `distance_bucket`
- `elapsed_time_bucket`

Reglas aplicadas:
- sin PII (`uid`, email, teléfono, texto libre, query cruda, coordenada fina, adjuntos);
- sin objetos/listas serializadas;
- buckets para cardinalidad baja;
- dedupe de emisión para evitar duplicados por re-render/taps repetidos.

## 4. Archivos principales modificados

- `mobile/lib/core/analytics/analytics_service.dart`
- `mobile/lib/core/providers/analytics_provider.dart`
- `mobile/lib/main.dart`
- `mobile/lib/core/router/app_routes.dart`
- `mobile/lib/core/router/app_router.dart`
- `mobile/lib/modules/search/analytics/search_analytics.dart`
- `mobile/lib/modules/search/providers/search_notifier.dart`
- `mobile/lib/modules/search/screens/search_results_screen.dart`
- `mobile/lib/modules/search/screens/search_map_screen.dart`
- `mobile/lib/modules/home/analytics/open_now_analytics.dart`
- `mobile/lib/modules/home/providers/open_now_notifier.dart`
- `mobile/lib/modules/home/screens/abierto_ahora_screen.dart`
- `mobile/lib/modules/pharmacy/analytics/pharmacy_duty_analytics.dart`
- `mobile/lib/modules/pharmacy/providers/pharmacy_duty_notifier.dart`
- `mobile/lib/modules/pharmacy/screens/pharmacy_duty_screen.dart`
- `mobile/lib/modules/pharmacy/screens/pharmacy_duty_detail_screen.dart`
- `mobile/lib/modules/merchant_detail/analytics/merchant_detail_analytics.dart`
- `mobile/lib/modules/merchant_detail/application/merchant_detail_controller.dart`
- `mobile/lib/modules/merchant_detail/presentation/merchant_detail_page.dart`
- `mobile/lib/modules/merchant_claim/application/merchant_claim_flow_controller.dart`
- `mobile/lib/modules/merchant_claim/screens/merchant_claim_flow_screens.dart`

## 5. Tests actualizados/validados

Se ajustaron contratos/fakes por cambios de interfaces y se validó:
- `mobile/test/core/analytics/analytics_service_test.dart`
- `mobile/test/modules/search/search_notifier_test.dart`
- `mobile/test/modules/search/search_analytics_test.dart`
- `mobile/test/modules/home/open_now_notifier_test.dart`
- `mobile/test/modules/pharmacy/pharmacy_duty_notifier_test.dart`
- `mobile/test/modules/pharmacy/pharmacy_duty_analytics_test.dart`
- `mobile/test/modules/merchant_detail/application/merchant_detail_controller_test.dart`
- `mobile/test/modules/merchant_detail/presentation/merchant_detail_page_test.dart`
- `mobile/test/modules/merchant_detail/analytics/merchant_detail_analytics_test.dart`

Resultado:
- suite focalizada en verde (37 tests).

## 6. Corrección aplicada post-auditoría

- Se corrigió sanitización en `AnalyticsService` para no descartar parámetros canónicos permitidos por coincidencia de fragmentos sensibles en el nombre de clave (`query_length_bucket`, `has_attachment`, etc.).
- Se mantiene protección no-PII con allowlist estricta + bloqueo explícito de claves sensibles + validación de valores.

## 7. Trade-offs y gaps reales

- Se removieron emisiones legacy no requeridas para 0083 en superficies públicas auditadas (`open_now_pull_to_refresh`, `open_now_distance_permission_denied`, `open_now_location_unavailable`, `map_recenter_tapped`, `map_search_this_area_tapped`, `claim_evidence_uploaded`) para reducir ruido y costo analítico.
- Web pública dedicada no está en este repo como app separada; la consistencia aplica al runtime web de la app Flutter mobile (misma capa y semántica).
