# TuM2-0064 — Plan de Pruebas de Transiciones OWNER

Estado: READY FOR QA  
Fecha: 2026-04-19  
Alcance: cierre UX/flujo de transiciones `owner_pending`, promoción a `owner` y salida a `customer`.

## 1. Objetivo

Validar end-to-end que el módulo OWNER:

- no deja residuos visuales de pending,
- redirige correctamente ante cambios de acceso en sesión activa,
- mantiene coherencia de permisos en rutas profundas,
- respeta la autoridad backend sobre rol/claims.

## 2. Cambios cubiertos por este plan

- Nueva ruta: `/access-updated`
- Nueva pantalla: `OwnerAccessUpdatedScreen` con 3 variantes:
  - `approved_transition`
  - `claim_closed`
  - `deep_route_access_changed`
- Guard de rutas owner actualizado para usuarios sin acceso owner.
- Refresh de sesión/claims sin relogin manual (`AuthNotifier.refreshSession`).
- Disparo de transición aprobada:
  - desde dashboard owner,
  - desde pantalla `claim/status`.

## 3. Precondiciones de ambiente

- App mobile apuntando al ambiente correspondiente (`tum2-staging-45c83` recomendado).
- Usuario A con claim en estado `owner_pending`.
- Usuario B con rol `customer` sin acceso owner.
- Herramienta para actualizar claim en backend/admin:
  - `approved`
  - `rejected`
- Datos base:
  - al menos 1 comercio candidato para claim.
  - owner con rutas profundas disponibles (`/owner/products`, `/owner/schedules`).

## 4. Matriz de escenarios críticos

| ID | Escenario | Origen | Evento backend | Resultado esperado |
|---|---|---|---|---|
| S1 | Promoción pending -> owner desde dashboard | `/owner/dashboard` pending | claim `approved` | Pantalla transición aprobada -> `/owner/resolve` -> dashboard owner pleno |
| S2 | Promoción pending -> owner desde claim status | `/claim/status` | claim `approved` + claims actualizados | Pantalla transición aprobada -> `/owner/resolve` |
| S3 | Cierre negativo | intento de acceso a `/owner/dashboard` sin rol owner | claim no activo / rechazado | Pantalla `claim_closed` -> CTA a `/home` |
| S4 | Guardrail ruta profunda | `/owner/products` con usuario customer | acceso inválido | Pantalla `deep_route_access_changed` -> `/home` |
| S5 | owner_pending en ruta owner hija | `/owner/products` con `ownerPending=true` | n/a | Redirect a `/owner/dashboard` (sin acceso operativo) |

## 5. Casos manuales detallados

### C1 — Transición aprobada desde OWNER dashboard

1. Iniciar sesión con usuario `owner_pending`.
2. Ir a `/owner/dashboard`.
3. Desde admin/backend, aprobar claim.
4. Forzar refresh de estado (o esperar actualización natural).
5. Verificar:
   - aparece pantalla de transición con copy: `Estamos preparando tu panel.`
   - no aparece copy técnico.
   - redirección automática a `Mi comercio`.
   - desaparecen banners pending.

Criterio PASS: no requiere relogin manual y no hay flicker de permisos inconsistentes.

### C2 — Transición aprobada desde claim status

1. Iniciar sesión con usuario pending.
2. Ir a `/claim/status`.
3. Aprobar claim en backend.
4. Verificar redirección a `/access-updated?...approved_transition...`.
5. Confirmar salida a owner flow (`/owner/resolve`).

Criterio PASS: transición clara, sin quedar bloqueado en claim status.

### C3 — Cierre negativo limpio

1. Partir de usuario que ya no tiene claim activo owner.
2. Intentar abrir `/owner/dashboard`.
3. Verificar:
   - aparece estado de cierre negativo.
   - copy operativo sin tecnicismos.
   - CTA principal vuelve a Home customer.
   - sin quick actions owner visibles.

Criterio PASS: limpieza total del carril owner pending.

### C4 — Guardrail de ruta profunda

1. Con usuario `customer`, abrir deep link `/owner/products`.
2. Verificar pantalla de acceso actualizado (`deep_route_access_changed`).
3. Presionar CTA principal.
4. Confirmar navegación a `/home`.

Criterio PASS: no loop, no crash, no acceso parcial.

### C5 — owner_pending restringido

1. Iniciar con `role=owner` + `ownerPending=true`.
2. Navegar a `/owner/products`, `/owner/schedules`, `/owner/signals`.
3. Verificar redirección a `/owner/dashboard` pending.

Criterio PASS: pending no opera módulos owner hijos.

## 6. Casos de regresión recomendados

- R1: customer en `/claim/*` sigue funcionando sin regresión.
- R2: admin en rutas `/owner/*` mantiene acceso como antes.
- R3: owner aprobado sin pending entra directo a `/owner/resolve`.
- R4: navegación pública (`/home`, `/search`, `/commerce/:id`) no afectada.

## 7. Pruebas automatizadas incluidas

Comandos ejecutados:

```bash
cd mobile
flutter test test/core/router/router_guards_test.dart
flutter test test/core/router/router_guards_claim_test.dart
flutter test test/modules/owner/owner_panel_screen_test.dart
flutter analyze lib/core/router/app_routes.dart \
  lib/core/router/router_guards.dart \
  lib/core/router/app_router.dart \
  lib/core/auth/auth_notifier.dart \
  lib/modules/owner/screens/owner_access_updated_screen.dart \
  lib/modules/owner/screens/owner_panel_screen.dart \
  lib/modules/merchant_claim/screens/merchant_claim_flow_screens.dart
```

Resultado esperado: PASS sin errores.

## 8. Criterios de aceptación (DoD)

- [ ] Estado `approved_transition` visible y entendible.
- [ ] Estado `claim_closed` sin residuos pending.
- [ ] Estado `deep_route_access_changed` redirige correctamente.
- [ ] Sin copy técnico (claims/token/etc) en UI.
- [ ] Sin relogin manual para promoción a owner.
- [ ] Guards owner consistentes con rol efectivo.
- [ ] Tests y análisis estático en verde.

## 9. Riesgos abiertos

- El refresco de claims depende de propagación backend + token refresh.
- En sesiones con latencia alta puede haber pequeño delay antes de transición.
- Se recomienda validar en staging con datos reales de claims y reviewer admin.
