# TuM2 — Tabla de rutas (ROUTES.md)

Generado para TuM2-0053. Ver también `NAVIGATION.md` para la arquitectura de alto nivel.

---

## 1. Auth Stack (sin sesión)

| Path | Screen ID | Pantalla | Roles | Presentación |
|------|-----------|----------|-------|--------------|
| `/` | AUTH-01 | Splash | Todos | Stack root |
| `/onboarding` | AUTH-02 | Onboarding bienvenida | Todos | Stack push |
| `/login` | AUTH-03 | Login / Registro | Todos | Stack push |
| `/email-verification` | AUTH-04 | Verificación de email | Todos | Stack push |

---

## 2. CustomerTabs — Tab Inicio (HomeStack)

Tab bar visible. Estado del stack preservado al cambiar de tab.

| Path | Screen ID | Pantalla | Roles | Presentación |
|------|-----------|----------|-------|--------------|
| `/home` | HOME-01 | Inicio | customer, owner, admin | Tab root |
| `/home/abierto-ahora` | HOME-02 | Abierto ahora | customer, owner, admin | Stack push |
| `/home/farmacias-de-turno` | HOME-03 | Farmacias de turno | customer, owner, admin | Stack push |

---

## 3. CustomerTabs — Tab Buscar (SearchStack)

| Path | Screen ID | Pantalla | Roles | Presentación |
|------|-----------|----------|-------|--------------|
| `/search` | SEARCH-01 | Buscar | customer, owner, admin | Tab root |
| `/search/resultados` | SEARCH-02 | Resultados | customer, owner, admin | Stack push |
| `/search/mapa` | SEARCH-03 | Mapa | customer, owner, admin | Stack push |

---

## 4. CustomerTabs — Tab Perfil (ProfileStack)

| Path | Screen ID | Pantalla | Roles | Presentación |
|------|-----------|----------|-------|--------------|
| `/profile` | PROFILE-01 | Mi perfil | customer, owner, admin | Tab root |
| `/profile/settings` | PROFILE-02 | Configuración | customer, owner, admin | Stack push |
| `/profile/propuestas` | PROFILE-03 | Propuestas y votos | customer, owner, admin | Stack push (MVP+) |

---

## 5. OwnerStack (modal full-screen)

Presentado como modal sobre CustomerTabs. Tab bar oculto.
Guard: rol `owner` o `admin`. Customer → redirige a `/profile`.

| Path | Screen ID | Pantalla | Roles | Presentación |
|------|-----------|----------|-------|--------------|
| `/owner` | OWNER-01 | Panel de comercio | owner, admin | Modal fullscreen |
| `/owner/edit` | OWNER-02 | Editar perfil | owner, admin | Stack push |
| `/owner/products` | OWNER-03 | Productos | owner, admin | Stack push |
| `/owner/schedules` | OWNER-06 | Horarios y señales | owner, admin | Stack push |
| `/owner/pharmacy-duties` | OWNER-09 | Turnos de farmacia | owner, admin | Stack push |
| `/owner/duties` | OWNER-09 | Alias legado de turnos de farmacia | owner, admin | Stack push |

---

## 6. AdminStack (modal full-screen)

Presentado como modal sobre CustomerTabs. Tab bar oculto.
Guard: solo rol `admin`. Otros roles → redirigen a `/home`.

| Path | Screen ID | Pantalla | Roles | Presentación |
|------|-----------|----------|-------|--------------|
| `/admin` | ADMIN-01 | Panel admin | admin | Modal fullscreen |
| `/admin/merchants` | ADMIN-02 | Comercios (moderación) | admin | Stack push |
| `/admin/signals` | ADMIN-04 | Señales reportadas | admin | Stack push |

---

## 7. Shared Screens

Accesibles desde cualquier contexto vía `context.push()`.
Al estar fuera del `StatefulShellRoute`, el tab bar se oculta al navegar a estas pantallas.

| Path | Screen ID | Pantalla | Roles | Presentación |
|------|-----------|----------|-------|--------------|
| `/commerce/:id` | DETAIL-01 | Ficha de comercio | Todos (público) | Push sobre stack activo |
| `/onboarding/owner` | DETAIL-03 | Onboarding de comercio | owner | Full screen (redirect guard) |

---

## 8. Guards de navegación

| Condición | Ruta intentada | Redirect destino |
|-----------|---------------|-----------------|
| `AuthLoading` | Cualquiera | `/` (splash) |
| `AuthUnauthenticated` | Ruta protegida | `/login` + guarda pendingRoute |
| `AuthUnauthenticated` | Ruta pública | Permitir |
| `AuthAuthenticated` | Ruta auth (`/`, `/login`, etc.) | `/home` (o pendingRoute) |
| `owner` sin merchantId | Cualquiera (excepto `/onboarding/owner`) | `/onboarding/owner` |
| `customer` | `/owner` o sub-rutas | `/profile` |
| `customer` o `owner` | `/admin` o sub-rutas | `/home` |

---

## 9. Deep links

Scheme: `tum2://`

| Deep link | Ruta interna | Notas |
|-----------|-------------|-------|
| `tum2://commerce/{id}` | `/commerce/{id}` | Público, no requiere sesión |
| `tum2://home` | `/home` | Requiere sesión |
| `tum2://search` | `/search` | Requiere sesión |

**Flujo sin sesión activa:**
1. Deep link recibido → `redirect` guarda la ruta en `pendingRouteProvider`
2. Redirige a `/login`
3. Post-login → `_authenticatedHome()` lee `pendingRouteProvider` y navega al destino

---

## 10. Rutas públicas (no requieren sesión)

- `/` (splash)
- `/onboarding`
- `/login`
- `/email-verification`
- `/commerce/:id` (contenido visible sin login)

---

*Documento generado para TuM2-0053. Mantener actualizado al agregar nuevas pantallas.*
