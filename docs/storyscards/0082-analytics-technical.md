# TuM2-0082 — Definir eventos analytics (versión técnica canónica)

Estado: READY_FOR_QA  
Prioridad: P0 (MVP crítica)  
Área: Analytics / Producto / Arquitectura / Mobile / Web pública  
North Star: **% de sesiones con acción útil en < 3 min**

## 1. Objetivo
Definir y congelar el contrato analytics MVP para medir utilidad real en contexto local, sin PII, sin query crudo y sin costo extra en Firestore.

## 2. Decisiones cerradas
1. Se permite bootstrap geolocalizado inicial para farmacias de turno.
2. Ese bootstrap no contamina `search_performed`.
3. Feedback útil MVP explícito aplica a farmacias de turno.
4. Copy positivo default: `Me sirvió`.
5. Variante estacional permitida: `Messirve`.
6. El nombre del evento nunca cambia por copy.
7. Negativo se expresa como `Informar un problema`.
8. En reason `other` puede haber texto/foto en flujo de reporte, nunca en analytics.
9. En acciones sobre entidad manda `entity_zone_id` como dimensión territorial principal.
10. Mobile activo; Web pública con consentimiento liviano si analytics depende de cookies.
11. No se envían identificadores directos de entidad ni de usuario en payload analytics (snake_case ni camelCase).
12. `merchantId`/`productId`/`userId`/`deviceId` quedan explícitamente bloqueados en cliente analytics.
13. Para mapa MVP se conserva `map_viewed` + `map_pin_selected`; `map_recenter_tapped` y `map_search_this_area_tapped` quedan deprecados/no emitidos por costo/ruido.
14. Para claim MVP se conserva `claim_started` + `claim_submitted`; `claim_evidence_uploaded` queda deprecado/no emitido en runtime.

## 3. Reglas no negociables
- No usar Firestore como event store analytics.
- No enviar PII, texto libre, adjuntos, query crudo ni coordenadas finas.
- `merchant_public` no se escribe desde cliente.
- Separación estricta dev/staging/prod.
- Analytics real solo en `tum2-prod-bc9b4`.
- En `tum2-dev-6283d` y `tum2-staging-45c83`: debug/log local sanitizado.
- Admin Web queda fuera de esta tarjeta.
- Eventos publicados no se renombran; ambiguos se deprecan y documentan.

## 4. Arquitectura
```
UI
  -> Notifier/Controller/UseCase
  -> AnalyticsService (capa única)
  -> firebase_analytics
```

### 4.1 AnalyticsService obligatorio
- Sanitización de parámetros y eliminación de nulls.
- Validación de enums/buckets.
- Allowlist estricta de eventos y parámetros (drop por defecto).
- Bloqueo explícito de claves sensibles y de identificadores directos de entidad (snake_case + camelCase: `merchant_id/merchantId`, `product_id/productId`, `merchant_ref/merchantRef`, `user_id/userId`, `device_id/deviceId`) para minimizar riesgo de exfiltración.
- Gating por ambiente (real solo prod).
- Gating por consentimiento web.
- Dedupe simple para evitar doble emisión.
- Offline queue chica + TTL + drop seguro solo para eventos críticos permitidos.

### 4.2 Migración legacy en curso (sin romper histórico)
- Módulos legacy (auth, owner, open_now, merchant_claim legacy) migrados para emitir vía `AnalyticsService` en lugar de `FirebaseAnalytics` directo.
- Se preservan nombres de eventos legacy publicados para continuidad histórica.
- Parámetros fuera de contrato oficial o sensibles se descartan por sanitización (drop-by-default).

## 5. Taxonomía oficial MVP

### 5.1 Descubrimiento explícito
- `search_performed`
- `category_filtered`

### 5.2 Bootstrap geolocalizado
- `nearby_bootstrap_started`
- `nearby_bootstrap_completed`
- `nearby_bootstrap_failed`

### 5.3 Mapa (mínimo útil, sin tracking continuo pan/zoom)
- `map_viewed`
- `map_pin_selected`
- `map_recenter_tapped` (deprecado/no emitido en runtime)
- `map_search_this_area_tapped` (deprecado/no emitido en runtime)

### 5.4 Acciones core
- `operator_call_click`
- `whatsapp_chat_started`
- `directions_opened`
- `pharmacy_duty_view`

### 5.5 Farmacias de turno / confianza del dato
- `pharmacy_duty_feedback_positive`
- `pharmacy_duty_feedback_negative_started`
- `pharmacy_duty_feedback_negative_reason_selected`
- `report_started`
- `report_submitted`

### 5.6 Claim funnel
- `claim_started`
- `claim_evidence_uploaded` (deprecado/no emitido en runtime)
- `claim_submitted`

## 6. User properties mínimas
- `role`
- `active_zone_id`
- `is_verified_owner`

## 7. Parámetros transversales
- `surface`
- `entry_point`
- `source`
- `entity_type`
- `active_zone_id`
- `entity_zone_id`
- `distance_bucket`
- `resolved_locally`
- `result_count_bucket`
- `permission_state`
- `network_state`
- `reason_code`
- `has_free_text`
- `has_attachment`
- `copy_variant`

## 8. Buckets obligatorios
`distance_bucket`: `0_500m`, `500m_1km`, `1_3km`, `3_10km`, `10km_plus`, `unknown`  
`result_count_bucket`: `0`, `1_3`, `4_10`, `11_plus`  
`query_length_bucket`: `0`, `1_3`, `4_8`, `9_plus`  
`evidence_count_bucket`: `1`, `2`, `3_plus`

## 9. Política territorial
- `active_zone_id`: zona funcional actual.
- `entity_zone_id`: zona de la entidad accionada.
- En outcomes de entidad, priorizar `entity_zone_id`.

## 10. Política de copy
- Positivo default: `Me sirvió`
- Positivo estacional permitido: `Messirve`
- Negativo: `Informar un problema`
- Evento no cambia por copy; opcional `copy_variant`:
  - `default_me_sirvio`
  - `seasonal_messirve`

## 11. Política offline
Persistir localmente solo:
- `operator_call_click`
- `whatsapp_chat_started`
- `directions_opened`
- `pharmacy_duty_view`
- `claim_started`
- `claim_submitted`
- `pharmacy_duty_feedback_positive`
- `report_submitted` (sin contenido sensible)

No persistir offline:
- `search_performed`
- `category_filtered`
- eventos de mapa

## 12. Deprecaciones / adaptación retroactiva
Eventos legacy detectados y declarados como deprecados para 0083:
- `search_query_submitted` -> `search_performed`
- `search_filter_applied` -> `category_filtered` (cuando aplica categoría)
- `search_map_toggled` -> `map_viewed` (`map_search_this_area_tapped` deprecado/no emitido)
- `search_result_opened` -> deprecado (reemplazo por `map_pin_selected` si corresponde)
- `pharmacy_duty_view_opened` -> `pharmacy_duty_view`
- `pharmacy_duty_call_tap` -> `operator_call_click`
- `pharmacy_duty_directions_tap` -> `directions_opened`
- `merchant_claim_started` -> `claim_started`
- `merchant_claim_evidence_uploaded` -> deprecado/no emitido
- `merchant_claim_submitted` -> `claim_submitted`
- `merchant_detail_call_click` -> `operator_call_click`
- `merchant_detail_directions_click` -> `directions_opened`

## 13. Impacto cruzado obligatorio
- 0035: copy y CTA de feedback (`Me sirvió` / `Informar un problema` + variante `Messirve`).
- 0056: `search_performed` solo búsqueda explícita, sin query crudo.
- 0057: mapa alineado a taxonomía nueva, sin tracking continuo.
- 0061: feedback útil + reason + report analytics sin texto/foto.
- 0100: privacidad alineada a analytics funcional, no-PII.
- 0101: términos alineados a tratamiento de reportes/claims sin fuga sensible.
- 0083: implementación de tracking base sobre este contrato congelado.

## 14. Testing obligatorio
- Unit: sanitización, no-PII, enums/buckets, `copy_variant`, dedupe.
- Integration: notifiers/controllers + gating mobile/web + offline queue permitida.
- E2E: bootstrap, búsqueda explícita, mapa mínimo útil, feedback positivo/negativo, reportes sin fuga, claim funnel.
- Security: jamás enviar texto libre, teléfonos, emails, archivos, query crudo, coordenadas finas.

## 15. Constraints de costo
- No lecturas Firestore para analytics.
- No snapshots como fuente analítica.
- No colecciones auxiliares analytics en Firestore.
- No tracking granular de mapa.
- User properties mínimas, sin inflación.
