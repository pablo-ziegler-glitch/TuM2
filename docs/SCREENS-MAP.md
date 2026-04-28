# TuM2 — Mapa completo de pantallas y flujos v1.1

Define las pantallas mobile de TuM2, sus relaciones, visibilidad por segmento y reglas de navegación para el MVP.

> Decisión de producto vigente: TuM2 usa una experiencia **guest-first**. En el MVP no se fuerza login para descubrir comercios, ver farmacias de turno, buscar, abrir mapas ni consultar fichas públicas. El login se solicita **a demanda**, solo cuando el usuario intenta una acción protegida o personalizada.

---

## 1. Segmentos y contextos

| Segmento | Contexto de uso | Rol en Firebase |
|----------|----------------|-----------------|
| INVITADO | Vecino sin sesión que necesita resolver rápido | Sin sesión |
| CUSTOMER | Vecino autenticado que busca, guarda o participa | `customer` |
| OWNER | Dueño o encargado de un comercio aprobado | `owner` |
| OWNER PENDING | Usuario con claim/reclamo de comercio en revisión | `owner` + `owner_pending=true` |
| ADMIN | Equipo TuM2 con acceso de moderación | `admin` / `super_admin` |

### Principios de navegación

- El vecino debe poder abrir TuM2 y resolver sin registrarse.
- El onboarding CUSTOMER no bloquea el acceso al contenido público.
- El login aparece contextualizado cuando aporta valor o seguridad.
- Las rutas públicas no deben depender de claims ni lecturas privadas.
- Las rutas OWNER/ADMIN siempre requieren sesión y rol autorizado.
- El estado `owner_pending` no habilita operación OWNER plena.

---

## 2. Rubros MVP canónicos

Los rubros visibles del MVP son:

1. Farmacias
2. Kioscos
3. Almacenes
4. Veterinarias
5. Tiendas de comida al paso
6. Casas de comida / Rotiserías
7. Gomerías
8. Panaderías
9. Confiterías

Estos rubros pueden aparecer en onboarding, búsqueda, filtros, categorías rápidas, fichas públicas y documentación de producto.

---

## 3. Árbol de pantallas

```text
TuM2 App
├── AUTH / ENTRY
│   ├── AUTH-01  Splash / Loading
│   ├── AUTH-02  Onboarding CUSTOMER (carrusel 3 slides, salteable)
│   ├── AUTH-03  Login / Registro contextual (email magic link + Google)
│   ├── AUTH-04  Verificación de email (magic link)
│   └── AUTH-05  Micro-step displayName (solo si aplica)
│
├── CUSTOMER / INVITADO (tab bar principal)
│   ├── TAB: Inicio
│   │   ├── HOME-01  Home (feed zonal público)
│   │   ├── HOME-02  Abierto ahora (listado filtrado)
│   │   └── HOME-03  Farmacias de turno (listado + detalle)
│   │
│   ├── TAB: Buscar
│   │   ├── SEARCH-01  Buscar (input + categorías rápidas)
│   │   ├── SEARCH-02  Resultados de búsqueda (listado)
│   │   ├── SEARCH-03  Mapa (mapa full con pins de comercios)
│   │   ├── SEARCH-FARMACIAS  Especialidad Farmacias
│   │   └── SEARCH-UBICACION  Fallback de ubicación / selección manual
│   │
│   ├── TAB: Perfil
│   │   ├── PROFILE-01  Mi perfil / entrada a sesión
│   │   ├── PROFILE-02  Configuración y notificaciones
│   │   ├── PROFILE-HELP  Ayuda / Cómo funciona TuM2
│   │   └── PROFILE-03  Propuestas y votos [MVP+]
│   │
│   └── GUARDADO [MVP+]
│       └── FAV-01  Favoritos y comercios seguidos
│
├── CLAIM / RECLAMO DE COMERCIO
│   ├── CLAIM-01  Intro de reclamo
│   ├── CLAIM-02  Selección de comercio
│   ├── CLAIM-03  Datos del solicitante
│   ├── CLAIM-04  Evidencia
│   ├── CLAIM-05  Consentimiento
│   ├── CLAIM-06  Éxito de envío
│   └── CLAIM-07  Estado del reclamo
│
├── OWNER (módulo separado, accesible desde Perfil o deep link)
│   ├── OWNER-RESOLVE  Resolver contexto OWNER / multi-merchant
│   ├── OWNER-01  Panel "Mi comercio" (dashboard resumen)
│   ├── OWNER-02  Perfil del comercio (edición de datos)
│   ├── OWNER-03  Productos (listado)
│   │   ├── OWNER-04  Alta de producto
│   │   └── OWNER-05  Edición de producto
│   ├── OWNER-06  Horarios
│   ├── OWNER-08  Avisos de hoy / señales operativas
│   └── OWNER-09  Turnos de farmacia
│       ├── OWNER-10  Calendario de turnos
│       └── OWNER-11  Cargar / confirmar turno
│
├── DETALLE (públicas, accesibles desde múltiples contextos)
│   ├── DETAIL-01  Ficha pública de comercio
│   └── DETAIL-02  Ficha pública de producto
│
└── ADMIN (solo rol admin, acceso por deep link o perfil)
    ├── ADMIN-01  Panel de control
    ├── ADMIN-02  Listado de comercios
    ├── ADMIN-03  Detalle de comercio
    ├── ADMIN-04  Señales reportadas
    └── ADMIN-CLAIMS  Revisión manual de claims
```

---

## 4. Fichas por pantalla

### AUTH-01 — Splash / Loading

- **Propósito:** inicializar la app, resolver sesión Firebase Auth, forzar refresh de token cuando hay usuario y decidir entrada inicial.
- **Tipo:** pantalla técnica + primera impresión de marca.
- **Salida sin sesión, primer uso:** → AUTH-02.
- **Salida sin sesión, usuario recurrente:** → HOME-01 en modo invitado.
- **Salida con sesión CUSTOMER:** → HOME-01.
- **Salida con sesión OWNER:** → OWNER-RESOLVE o HOME-01 según contexto y guards.
- **Salida con sesión OWNER PENDING:** → CLAIM-07 u OWNER-01 variante pendiente, según estado resumido.
- **Salida con sesión ADMIN:** → HOME-01, con entrada admin visible desde perfil.
- **Timeout/offline:** mostrar feedback amable y permitir continuar en modo invitado si no hay sesión confirmada.
- **Datos:** Auth local/Firebase token. No debe leer colecciones públicas ni hacer queries amplias.
- **Costo:** 0 Firestore reads para invitado; token refresh para sesión activa; lectura de resumen de usuario solo si hay sesión.

### AUTH-02 — Onboarding CUSTOMER

- **Propósito:** explicar el valor de TuM2 en 3 slides rápidos antes de entrar al home, sin bloquear la utilidad inmediata.
- **Regla crítica:** debe ser salteable desde el primer slide con botón `Omitir` visible y accesible.
- **Slides MVP:**
  1. `Encontrá comercios abiertos ahora en tu cuadra`
  2. `Farmacias de turno al instante`
  3. `Seguí tus comercios favoritos`
- **CTA último slide:** `Empezar` → HOME-01 en modo invitado.
- **Skip:** `Omitir` → HOME-01 en modo invitado.
- **Persistencia:** guardar `onboarding_seen=true` en SharedPreferences.
- **Acceso posterior:** PROFILE-HELP → `Cómo funciona TuM2` puede abrir el onboarding aunque ya esté visto.
- **Permisos:** no pedir permisos durante onboarding. Solo explicar que la ubicación sirve para mostrar comercios cercanos y que se puede elegir zona manualmente.
- **Analytics:** `auth_onboarding_started`, `auth_onboarding_skipped`, `auth_onboarding_completed`, opcional `auth_onboarding_slide_viewed`.
- **Costo:** sin Firestore, sin Storage, sin Functions.

### AUTH-03 — Login / Registro contextual

- **Propósito:** autenticar al usuario cuando intenta una acción que requiere identidad.
- **Métodos:** email magic link + Google Sign-In.
- **No se muestra obligatoriamente después del onboarding.**
- **Entradas típicas:**
  - tap en Perfil sin sesión,
  - reclamar comercio,
  - seguir/guardar comercio,
  - gestionar favoritos,
  - acceder a OWNER,
  - acceder a ADMIN,
  - acción futura que requiera identidad o auditoría.
- **Salida CUSTOMER:** volver a la ruta pendiente si es permitida; si no, HOME-01.
- **Salida OWNER:** OWNER-RESOLVE.
- **Salida OWNER PENDING:** CLAIM-07 / estado del reclamo.
- **Salida ADMIN:** ruta pendiente admin si corresponde; si no, HOME-01.
- **Regla auth:** post-login siempre debe ejecutar `getIdTokenResult(forceRefresh: true)` para claims actualizados.

### AUTH-04 — Verificación de email

- **Propósito:** procesar magic link y resolver casos same-device / cross-device.
- **Salida exitosa:** ruta pendiente o HOME-01.
- **Salida con error:** AUTH-03 con error claro y opción de reenviar link.

### AUTH-05 — Micro-step displayName

- **Propósito:** pedir nombre visible solo cuando un usuario autenticado por magic link no tiene `displayName`.
- **Regla:** debe poder omitirse sin bloquear descubrimiento público.
- **Salida:** ruta pendiente o HOME-01.

---

## 5. Pantallas públicas CUSTOMER / INVITADO

### HOME-01 — Home (feed zonal público)

- **Propósito:** mostrar valor en menos de 5 segundos.
- **Disponible sin sesión:** sí.
- **Bloques UI:**
  - Barra de zona activa con opción de cambiar zona.
  - Quick actions: Abierto ahora, Farmacias de turno, Kioscos cerca, Panaderías cerca, Gomerías cerca.
  - Sección `Farmacias de turno hoy` si hay turnos activos.
  - Feed principal de comercios visibles de la zona desde `merchant_public`.
- **Ordenamiento:** `sortBoost desc` → `isOpenNow desc` → distancia si está disponible.
- **Fallback zona vacía:** CTA `Sugerir un comercio` y estados vacíos claros.
- **Salidas públicas:** DETAIL-01, HOME-02, HOME-03, SEARCH-01.
- **Salidas protegidas:** guardar/seguir/reclamar → AUTH-03 si no hay sesión.

### HOME-02 — Abierto ahora

- **Propósito:** filtrar comercios con `isOpenNow=true` en la zona.
- **Disponible sin sesión:** sí.
- **Fuente:** `merchant_public` con query acotada por `zoneId`, `visibilityStatus` y/o `isOpenNow`.
- **Filtros de categoría MVP:** Todos, Farmacias, Kioscos, Almacenes, Veterinarias, Comida al paso, Rotiserías, Gomerías, Panaderías, Confiterías.
- **Salida:** DETAIL-01, SEARCH-03.

### HOME-03 — Farmacias de turno

- **Propósito:** ver rápidamente qué farmacia está de guardia y cómo llegar.
- **Disponible sin sesión:** sí.
- **Fuente:** `pharmacy_duties` publicada + hidratación de `merchant_public`.
- **Regla UX:** mostrar disclaimer de actualización operativa y permitir reportar problema según alcance del módulo.
- **Salida:** DETAIL-01 / Pharmacy detail / mapa nativo / llamada.

### SEARCH-01 — Buscar

- **Propósito:** descubrimiento activo por texto, categoría o intención.
- **Disponible sin sesión:** sí.
- **Estados:** initial, focused, typing.
- **Categorías rápidas MVP:** Farmacias, Kioscos, Almacenes, Veterinarias, Comida al paso, Rotiserías, Gomerías, Panaderías, Confiterías.
- **Salida:** SEARCH-02, SEARCH-03, SEARCH-FARMACIAS, SEARCH-UBICACION.

### SEARCH-02 — Resultados de búsqueda

- **Disponible sin sesión:** sí.
- **Fuente:** `merchant_public` scoped por zona, con filtrado/ranking según implementación MVP.
- **Estados:** loading, results, openNow, verified, empty, error.
- **Salida:** DETAIL-01, SEARCH-03.

### SEARCH-03 — Mapa

- **Disponible sin sesión:** sí.
- **Propósito:** visualizar comercios en mapa.
- **Fuente:** misma fuente pública que búsqueda/home.
- **Permisos:** pedir ubicación solo cuando el usuario usa funciones de cercanía; siempre ofrecer selección manual de zona.
- **Salida:** DETAIL-01 desde bottom sheet.

### DETAIL-01 — Ficha pública de comercio

- **Disponible sin sesión:** sí.
- **Propósito:** mostrar información útil de un comercio.
- **Fuente:** `merchant_public/{merchantId}` + productos públicos si aplica.
- **Acciones públicas:** llamar, cómo llegar, compartir.
- **Acciones protegidas:** seguir, guardar, reclamar comercio, reportes sensibles.

### DETAIL-02 — Ficha pública de producto

- **Disponible sin sesión:** sí.
- **Propósito:** mostrar detalle de producto publicado.
- **Fuente:** producto público asociado al comercio.

---

## 6. Perfil, ayuda y login a demanda

### PROFILE-01 — Mi perfil / Entrada a sesión

- **Sin sesión:** mostrar entrada simple para iniciar sesión y explicar beneficios concretos: guardar comercios, reclamar comercio, gestionar perfil y recibir futuras alertas.
- **Con sesión CUSTOMER:** mostrar datos básicos, reclamo de comercio, ayuda, configuración y cerrar sesión.
- **Con OWNER:** mostrar entrada a Mi comercio.
- **Con ADMIN:** mostrar entrada a Admin.

### PROFILE-HELP — Ayuda / Cómo funciona TuM2

- **Propósito:** permitir revisar onboarding y mensajes de ayuda sin resetear la app.
- **Disponible sin sesión:** recomendado sí, si se expone desde una entrada pública; desde PROFILE puede requerir navegar por tab de perfil.
- **Contenido mínimo:**
  - Qué es TuM2.
  - Cómo se usa sin registrarse.
  - Para qué sirve iniciar sesión.
  - Por qué se puede pedir ubicación.
  - Cómo reclamar un comercio.
- **Acción:** `Ver bienvenida de TuM2` → AUTH-02 en modo ayuda (`source=help`, sin sobrescribir `onboarding_seen`).

---

## 7. CLAIM / Reclamo de comercio

- **Disponible sin sesión:** no para envío; sí puede existir intro pública.
- **Regla:** al tocar `Reclamar este comercio`, si no hay sesión → AUTH-03 con ruta pendiente.
- **Identidad:** email del claim = email autenticado actual.
- **Teléfono:** opcional sin verificación en MVP.
- **Estados visibles:** draft, submitted, under_review, needs_more_info, approved, rejected, conflict_detected, duplicate_claim.
- **Salida post envío:** CLAIM-07 estado del reclamo.
- **Seguridad:** datos sensibles protegidos, masking en Admin, reveal temporal y auditado.

---

## 8. OWNER

### OWNER-RESOLVE

- **Propósito:** resolver contexto owner, multi-merchant, owner_pending o restricciones.
- **Regla:** no permitir acceso OWNER pleno sin rol aprobado.

### OWNER-01 — Panel Mi comercio

- **Disponible sin sesión:** no.
- **Disponible CUSTOMER:** no.
- **Disponible OWNER PENDING:** variante limitada de estado de claim y próximos pasos.
- **Disponible OWNER:** sí, con acciones operativas.
- **Bloques:** estado actual, horarios, avisos de hoy, productos, turnos de farmacia cuando corresponda.

### OWNER-06 — Horarios

- **Fuente:** configuración privada del comercio.
- **Regla:** escritura privada; proyección pública vía Cloud Functions.

### OWNER-08 — Avisos de hoy / señales operativas

- **Fuente:** `merchant_operational_signals/{merchantId}`.
- **Regla:** cliente no escribe `merchant_public`.

### OWNER-09/10/11 — Turnos de farmacia

- **Visible solo para farmacia OWNER habilitada.**
- **Regla:** validaciones server-side y proyección pública por backend.

---

## 9. ADMIN

- **Disponible sin sesión:** no.
- **Disponible CUSTOMER/OWNER:** no.
- **Disponible ADMIN/SUPER_ADMIN:** sí.
- **Entrada:** perfil, deep link o URL interna según plataforma.
- **Módulos MVP:** listado de comercios, importación de datasets, revisión de señales/reportes, revisión manual de claims.

---

## 10. Deep links

| Deep link | Pantalla destino | Sesión requerida |
|-----------|------------------|------------------|
| `tum2://comercio/{merchantId}` | DETAIL-01 | No |
| `tum2://producto/{merchantId}/{productId}` | DETAIL-02 | No |
| `tum2://farmacias-turno/{zoneId}` | HOME-03 | No |
| `tum2://abierto-ahora/{zoneId}` | HOME-02 | No |
| `tum2://claim/{merchantId}` | CLAIM-01/AUTH-03 contextual | Sí para enviar |
| `tum2://owner` | OWNER-RESOLVE | Sí |
| `tum2://owner/comercio/{merchantId}` | OWNER-01 | Sí + OWNER |
| `tum2://owner/turno` | OWNER-09 | Sí + OWNER farmacia |
| `tum2://admin` | ADMIN-01 | Sí + ADMIN |

---

## 11. Estados de visibilidad por segmento

| Pantalla | Invitado | CUSTOMER | OWNER PENDING | OWNER | ADMIN |
|----------|----------|----------|---------------|-------|-------|
| AUTH-01 | ✅ | ✅ | ✅ | ✅ | ✅ |
| AUTH-02 | ✅ | ✅ desde ayuda | ✅ desde ayuda | ✅ desde ayuda | ✅ desde ayuda |
| AUTH-03 | ✅ contextual | ✅ si reauth | ✅ si reauth | ✅ si reauth | ✅ si reauth |
| HOME-01 | ✅ | ✅ | ✅ | ✅ | ✅ |
| HOME-02 | ✅ | ✅ | ✅ | ✅ | ✅ |
| HOME-03 | ✅ | ✅ | ✅ | ✅ | ✅ |
| SEARCH-01/02/03 | ✅ | ✅ | ✅ | ✅ | ✅ |
| DETAIL-01 | ✅ | ✅ | ✅ | ✅ | ✅ |
| DETAIL-02 | ✅ | ✅ | ✅ | ✅ | ✅ |
| PROFILE-01 | Entrada a login | ✅ | ✅ | ✅ | ✅ |
| PROFILE-HELP | ✅ recomendado | ✅ | ✅ | ✅ | ✅ |
| CLAIM-* | Intro sí / envío no | ✅ | ✅ estado propio | ✅ si aplica | ✅ revisión admin separada |
| FAV-01 | ❌ pide login | ✅ | ✅ | ✅ | ✅ |
| OWNER-* | ❌ pide login | ❌ | ✅ limitado | ✅ | ✅ si rol admin permitido |
| ADMIN-* | ❌ | ❌ | ❌ | ❌ | ✅ |

---

## 12. Flujos principales end-to-end

### Flujo 1: Primer uso guest-first

```text
AUTH-01 Splash → AUTH-02 Onboarding → Empezar/Omitir → HOME-01 modo invitado
```

### Flujo 2: Usuario recurrente sin sesión

```text
AUTH-01 Splash → HOME-01 modo invitado
```

### Flujo 3: Login a demanda desde acción protegida

```text
DETAIL-01 → tap "Reclamar este comercio" → AUTH-03 → AUTH-04 si magic link → CLAIM-01/CLAIM-02
```

### Flujo 4: CUSTOMER busca farmacia de turno

```text
HOME-01 → Farmacias de turno → HOME-03 → farmacia → DETAIL-01 / Cómo llegar
```

### Flujo 5: CUSTOMER busca comercio abierto

```text
HOME-01 → Abierto ahora → HOME-02 → comercio → DETAIL-01
```

O:

```text
HOME-01 → Buscar → SEARCH-01 → categoría/query → SEARCH-02 → comercio → DETAIL-01
```

### Flujo 6: CUSTOMER consulta mapa sin sesión

```text
SEARCH-01/SEARCH-02 → Ver en mapa → SEARCH-03 → marker/bottom sheet → DETAIL-01
```

### Flujo 7: Usuario revisa onboarding desde ayuda

```text
PROFILE-01/PROFILE-HELP → Cómo funciona TuM2 → AUTH-02 source=help → volver a HOME-01 o Perfil
```

### Flujo 8: OWNER aprobado entra a Mi comercio

```text
AUTH-03 → post-login forceRefresh → OWNER-RESOLVE → OWNER-01
```

### Flujo 9: OWNER PENDING consulta estado

```text
AUTH-03 → post-login forceRefresh → CLAIM-07 / OWNER-01 variante pendiente
```

### Flujo 10: ADMIN entra a panel

```text
AUTH-03 → post-login forceRefresh → PROFILE-01 → Panel de administración → ADMIN-01
```

---

## 13. Pantallas MVP vs Post-MVP

### En MVP

- AUTH-01, AUTH-02, AUTH-03, AUTH-04, AUTH-05 si aplica.
- HOME-01, HOME-02, HOME-03.
- SEARCH-01, SEARCH-02, SEARCH-03, SEARCH-FARMACIAS, SEARCH-UBICACION.
- DETAIL-01, DETAIL-02.
- PROFILE-01, PROFILE-HELP, PROFILE-02 básico.
- CLAIM-01 a CLAIM-07 si el dominio claim entra en la fase MVP activa.
- OWNER-RESOLVE, OWNER-01, OWNER-03 a OWNER-11 según rubro/capacidad.
- ADMIN-01 a ADMIN-04 y ADMIN-CLAIMS según fase activa.

### Post-MVP / MVP+

- FAV-01 — Favoritos y seguidos si no entra en MVP funcional.
- PROFILE-03 — Propuestas y votos.
- Módulo completo de propuestas y votos.
- Rankings, reputación avanzada y monetización.

---

## 14. Guardrails técnicos

- `merchant_public` es la única fuente pública para listados/fichas públicas y nunca se escribe desde cliente.
- No usar login como requisito para discovery público.
- No pedir ubicación en splash ni onboarding.
- Ubicación debe tener fallback manual de zona.
- Onboarding usa SharedPreferences (`onboarding_seen`) y no Firestore.
- Splash no debe abrir listeners costosos.
- Login debe preservar ruta pendiente cuando la acción protegida lo dispara.
- Acciones OWNER/ADMIN deben pasar por guards de rol y claims actualizados.
- Custom claims solo se actualizan vía Cloud Functions Admin SDK.
- Toda pantalla pública debe tolerar sesión nula.

---

## 15. Analytics mínimos asociados

### Onboarding

- `auth_onboarding_started`
- `auth_onboarding_slide_viewed`
- `auth_onboarding_skipped`
- `auth_onboarding_completed`

Parámetros mínimos:

- `slide_index`
- `slide_id`
- `source`
- `result`

### Login contextual

- `auth_login_prompt_shown`
- `auth_login_started`
- `auth_magic_link_sent`
- `auth_magic_link_verified`
- `auth_google_sign_in`

Parámetros mínimos:

- `entry_point`
- `pending_route_type`
- `source_screen`

### Discovery público

- `home_viewed`
- `search_started`
- `search_result_opened`
- `merchant_detail_opened`
- `pharmacy_duty_viewed`

---

## 16. Checklist de consistencia para cierre

- [ ] AUTH-02 no redirige automáticamente a AUTH-03.
- [ ] El primer uso puede terminar en HOME-01 sin sesión.
- [ ] El usuario recurrente sin sesión entra directo a HOME-01.
- [ ] Login se dispara solo por acciones protegidas.
- [ ] Perfil sin sesión funciona como entrada clara a login, no como bloqueo genérico.
- [ ] Ayuda permite volver a ver la bienvenida.
- [ ] Panaderías y Confiterías figuran como rubros MVP.
- [ ] Rubros MVP están alineados entre Home, Search, filtros, docs y analytics.
- [ ] Onboarding persiste `onboarding_seen` localmente.
- [ ] Analytics de onboarding existen.
- [ ] No hay Firestore reads extra por onboarding.
- [ ] Splash no bloquea discovery público ante fallas no críticas.

---

*Documento actualizado para reflejar estrategia guest-first del MVP y login a demanda. Ver NAVIGATION.md para arquitectura de navegación y guards.*
