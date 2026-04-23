# TuM2-0141 — Hardening de queries admin: paginación, filtros obligatorios y refresh manual

## 1. Estado y metadata
- **Estado:** TODO
- **Prioridad:** P0
- **Dependencia madre:** TuM2-0135
- **Dependencias funcionales:** TuM2-0077, TuM2-0122, TuM2-0128, TuM2-0133

## 2. Objetivo
Convertir el Admin Web en una superficie de lectura controlada y económica, evitando listeners globales, queries abiertas y cargas innecesarias de listados completos.

## 3. Problema
El admin es una trampa típica de costo:
- muchas tablas,
- filtros opcionales,
- ganas de ver “todo en vivo”,
- adjuntos y detalles costosos.

## 4. Alcance IN
- filtros obligatorios por módulo,
- paginación por cursor,
- `limit` estricto,
- refresh manual como default,
- auto-refresh opcional solo cuando agregue valor real,
- detalle y evidencia on-demand,
- sin listeners globales.

## 5. Alcance OUT
- dashboards realtime complejos,
- moderación masiva en vivo estilo SOC,
- exportaciones pesadas de todo el histórico.

## 6. Decisiones canónicas
- listado siempre con filtros mínimos obligatorios,
- default: refresh manual,
- opcional: cada 60 s solo si la vista está activa y el feature flag lo habilita,
- evidencia, timeline detallado y sensibles solo on-demand,
- snapshot prohibido como patrón general para listados admin grandes.

## 7. Arquitectura propuesta
```text
Admin list screen
    |
    v
Query builder con filtros mínimos
    |
    v
Firestore get() con limit + cursor
    |
    +--> detalle on-demand
    +--> evidencia on-demand
```

## 8. Frontend
- tabla sin autoload de páginas múltiples,
- paginación clara,
- filtros persistidos en sesión si ayuda UX,
- botón “Actualizar”,
- timestamp visible,
- auto-refresh opcional en pantallas específicas, no global,
- thumbnails o metadata de evidencia,
- descarga y reveal solo bajo acción explícita y permiso.

## 9. Backend
Todas las queries deben tener:
- filtros fuertes,
- índices correctos,
- `limit`,
- cursor,
- sin offset.

Claims admin:
- listado resumido,
- detalle separado,
- timeline separado si es necesario.

Imports / moderación:
- tabla liviana,
- detalle on-demand,
- nada de hidratar todo upfront.

## 10. Seguridad
- masking por defecto,
- reveal solo en detalle y auditado,
- nada sensible en listados,
- protección anti scraping interno/externo donde aplique.

## 11. UX / Producto
Admin no necesita “ver todo vivo” para todos los módulos.  
Necesita:
- foco,
- filtros útiles,
- tiempo de carga estable,
- y capacidad de refrescar cuando lo decida.

## 12. Datos impactados
- `merchant_claims`
- `reports`
- `import_batches`
- listados admin futuros
- módulos de moderación

## 13. APIs y servicios
- Firestore
- Cloud Functions solo si agregan valor de agregación o autorización
- Analytics admin
- Remote Config para auto-refresh opcional

## 14. Analytics
Eventos:
- `admin_list_loaded`
- `admin_list_manual_refresh`
- `admin_list_next_page_loaded`
- `admin_detail_opened`
- `admin_evidence_loaded`

## 15. Testing
- query builder,
- paginación,
- refresh manual,
- persistencia de filtros,
- queries acotadas,
- detalle on-demand,
- evidencia on-demand,
- E2E claims/imports/moderación.

## 16. DevOps
- índices listos,
- alertas por queries lentas/caras,
- flags para auto-refresh por módulo.

## 17. Riesgos
- filtros demasiado estrictos,
- tablas que queden demasiado “manuales”,
- tentación de reintroducir listeners al primer reclamo interno.

## 18. Definition of Done
- sin listeners globales en listados admin,
- filtros obligatorios donde corresponda,
- detalle/evidencia on-demand,
- refresh manual operativo,
- costo controlado por módulo.

## 19. Rollout
1. claims admin
2. import batches
3. moderación/reports
4. resto de tablas admin

## 20. Checklist final
- [ ] paginación por cursor
- [ ] sin offset
- [ ] filtros mínimos obligatorios
- [ ] refresh manual
- [ ] detalle on-demand
- [ ] evidencia on-demand
