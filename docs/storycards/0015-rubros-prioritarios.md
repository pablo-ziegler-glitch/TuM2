# TuM2-0015 — Relevar rubros prioritarios

**Estado real:** DONE (expansión documental cerrada + ajustes puntuales en mobile)  
**Fecha:** 2026-04-27  
**Prioridad:** P0  
**Épica:** Research funcional y operativo

## 1. Objetivo

Definir y congelar el set canónico de rubros MVP de TuM2 para el piloto, junto con señales operativas mínimas y restricciones técnicas para impedir que entren rubros fuera de scope en superficies públicas de salida.

## 2. Contexto

TuM2 prioriza utilidad inmediata hiperlocal. El catálogo de rubros debe sostener:

- respuesta útil en menos de 3 segundos;
- consultas Firestore acotadas por zona/visibilidad/categoría;
- consistencia entre `merchants` (privado) y `merchant_public` (público);
- eliminación de ruido de categorías decorativas o de baja urgencia.

## 3. User Story

Como vecino de una zona piloto, quiero encontrar rápidamente comercios útiles de cercanía con señales operativas simples (abierto ahora, de turno, urgencia) para resolver necesidades inmediatas sin fricción.

## 4. Alcance IN/OUT

### IN

- Definición canónica de rubros MVP cerrada.
- Matriz de señales operativas mínimas por rubro.
- Alineación documental transversal (`CLAUDE.md`, PRD, visión, arquitectura, roadmap).
- Hardening en UI móvil para excluir rubros fuera de MVP en flujos activos.

### OUT

- Migraciones masivas de datos.
- Refactor estructural de taxonomía global.
- Cambio de arquitectura dual-collection.
- Reescritura completa de docs históricas.

## 5. Checklist técnico Firestore / Rules / Functions

### Firestore

- [x] Se mantiene uso de `categoryId`, `zoneId`, `visibilityStatus` para serving público.
- [x] Se mantiene patrón de query acotada con `limit` en módulos de búsqueda/home.
- [x] Onboarding OWNER deja de leer catálogo completo y consulta categorías por IDs MVP candidatos (chunks `whereIn` + `limit`).
- [x] Se evita ampliar lecturas por listeners globales para este cambio.
- [x] Se refuerza filtrado por set MVP en capa cliente sin lecturas extra.

### Rules

- [x] `merchant_public` continúa en solo lectura cliente (`allow read: if true; allow write: if false;`).
- [x] No se habilitaron writes cliente para campos derivados.
- [x] No hubo cambios en reglas que agreguen reads de autorización costosos.

### Functions

- [x] Se mantiene derivación pública por backend/Cloud Functions.
- [x] No se agregaron triggers ni recomputes globales.
- [x] No se introdujo write amplification para esta tarjeta.

## 6. Checklist UX Microcopy / Stitches

- [x] Labels de rubros alineados en español para MVP.
- [x] Se alinea exposición de Panaderías/Confiterías como rubros incluidos en flujos activos tocados.
- [x] Tono de copy mantenido: cercano, útil, directo, sin lenguaje marketplace.
- [x] No se agregan pantallas nuevas ni dependencia de mocks para cierre.

## 7. Datos impactados

Modelo objetivo validado para este alcance:

```ts
// merchants (privado)
merchantId: string;
categoryId: string;
zoneId: string;
status: "draft" | "active" | "inactive" | "archived";
visibilityStatus: "hidden" | "review_pending" | "visible" | "suppressed";
verificationStatus: "unverified" | "referential" | "community_submitted" | "claimed" | "validated" | "verified";
sourceType: "external_seed" | "user_submitted" | "owner_created" | "admin_created" | "community_suggested";
```

```ts
// merchant_public (proyección pública)
merchantId: string;
categoryId: string;
zoneId: string;
displayName: string;
isOpenNow: boolean | null;
isOnDutyToday?: boolean;
hasPharmacyDutyToday?: boolean;
operationalStatusLabel?: string;
sortBoost?: number;
```

## 8. Riesgos

- Riesgo de drift de taxonomía si se intenta reintroducir IDs no canónicos.
- Riesgo de que seeds/admin incorporen categorías no-MVP y requieran curación posterior.
- Riesgo de inconsistencias puntuales entre labels internos y labels UX recomendados.

Mitigación aplicada:

- filtro allowlist MVP en superficies móviles críticas (`onboarding_owner`, `search`, `abierto_ahora`) incluyendo panaderías/confiterías;
- seed de categorías ES-LATAM acotado al set MVP y limpieza explícita de IDs no-MVP;
- definición documental explícita de canon y exclusiones;
- sin cambios destructivos sobre datos productivos.

## 9. Definition of Done

- [x] Existe este documento de expansión (`docs/storycards/0015-rubros-prioritarios.md`).
- [x] `CLAUDE.md` actualizado con estado real y decisión canónica.
- [x] Rubros MVP documentados como lista cerrada.
- [x] Exclusiones explícitas documentadas.
- [x] Panaderías/Confiterías incluidas en UI/filtros MVP tocados.
- [x] Matriz de señales por rubro documentada.
- [x] Patrón dual-collection preservado.
- [x] `merchant_public` sigue sin escritura cliente.
- [x] Sin listeners/polling nuevos ni queries amplias.
- [x] Cambios de código con tests de cobertura agregados en módulos impactados.

## 10. Matriz final de rubros MVP

Decisión canónica: se usa un único set de IDs canónicos en runtime y documentación.

| Canon de producto (0015) | ID canónico runtime | Label UI |
|---|---|---|
| `pharmacies` | `farmacia` | Farmacias |
| `kiosks` | `kiosco` | Kioscos |
| `grocery_stores` | `almacen` | Almacenes |
| `veterinaries` | `veterinaria` | Veterinarias |
| `food_on_the_go` | `comida_al_paso` | Comida al paso |
| `rotisseries` | `casa_de_comidas` | Rotiserías |
| `tire_shops` | `gomeria` | Gomerías |
| `bakeries` | `panaderia` | Panaderías |
| `confectioneries` | `confiteria` | Confiterías |

## 11. Matriz de señales operativas por rubro

| Rubro | Señales mínimas |
|---|---|
| Farmacias | `open_now`, `on_duty`, `twenty_four_hours`, `duty_confirmed` |
| Kioscos | `open_now`, `twenty_four_hours`, `accepts_whatsapp` |
| Almacenes | `open_now`, `has_delivery`, `accepts_whatsapp` |
| Veterinarias | `open_now`, `handles_urgent_cases`, `on_call` |
| Comida al paso | `open_now`, `pickup_available`, `accepts_whatsapp` |
| Rotiserías | `open_now`, `has_delivery`, `accepts_orders` |
| Gomerías | `open_now`, `handles_urgent_cases`, `patch_available` |
| Panaderías | `open_now`, `twenty_four_hours`, `accepts_whatsapp` |
| Confiterías | `open_now`, `pickup_available`, `accepts_whatsapp` |

## 12. Exclusiones explícitas

No hay exclusión específica para panaderías/confiterías en este estado de la tarjeta.
Siguen fuera rubros decorativos, de catálogo extensivo o sin señal operativa útil inmediata.

## 13. Impacto en costos Firestore

- No se agregan listeners nuevos.
- No se agregan escrituras ni recomputes de backend.
- El filtrado MVP se aplica en memoria sobre corpus ya limitado.
- Se mantiene query acotada por `zoneId` + `visibilityStatus` + `limit`.
- Se evita costo incremental por mostrar categorías fuera de alcance.

Impacto runtime: **bajo y favorable** (menos render de ruido; sin incremento de reads/writes).

## 14. Dependencias (TuM2-0017, TuM2-0095, TuM2-0121)

- **TuM2-0017:** usa esta matriz de señales como baseline operativo por rubro.
- **TuM2-0095:** toma esta lista cerrada como rubros de salida del piloto.
- **TuM2-0121:** bootstrap inicial debe priorizar exclusivamente este set MVP para serving público.

---

## Cambios ejecutables incluidos en esta tarjeta

- `mobile/lib/modules/brand/onboarding_owner/repositories/categories_repository.dart`
  - allowlist MVP + fallback sin rubros excluidos + lectura Firestore acotada por IDs candidatos MVP.
- `mobile/lib/modules/brand/onboarding_owner/widgets/category_chip.dart`
  - catálogo visual de categorías alineado al set MVP.
- `mobile/lib/modules/search/providers/search_notifier.dart`
  - filtro de corpus por allowlist MVP (más bloqueo explícito de rubros fuera del canon vigente).
- `mobile/lib/modules/home/providers/open_now_notifier.dart`
  - filtro MVP para resultados de abierto ahora/fallback sin lecturas adicionales.
- `functions/scripts/seed_categories_es_latam.js`
  - seed de colección `categories` acotado a rubros MVP + eliminación de IDs no canónicos/no-MVP.
- Tests:
  - `mobile/test/modules/search/search_notifier_test.dart`
  - `mobile/test/modules/home/open_now_notifier_test.dart`
