# TuM2 — Mapa completo de pantallas y flujos v1

Define todas las pantallas de la app mobile, sus relaciones y los flujos principales por segmento.

---

## 1. Segmentos y contextos

| Segmento | Contexto de uso | Rol en Firebase |
|----------|----------------|-----------------|
| CUSTOMER | Vecino que busca comercios | `customer` |
| OWNER    | Dueño o encargado de un comercio | `owner` |
| ADMIN    | Equipo TuM2 con acceso de moderación | `admin` |

---

## 2. Árbol de pantallas

```
TuM2 App
├── AUTH (sin sesión)
│   ├── AUTH-01  Splash / Loading
│   ├── AUTH-02  Onboarding CUSTOMER (carrusel 3 slides)
│   ├── AUTH-03  Login / Registro (email + Google)
│   └── AUTH-04  Verificación de email (magic link / OTP)
│
├── CUSTOMER (tab bar principal)
│   ├── TAB: Inicio
│   │   ├── HOME-01  Home (feed zonal)
│   │   ├── HOME-02  Abierto ahora (listado filtrado)
│   │   └── HOME-03  Farmacias de turno (listado + mapa mini)
│   │
│   ├── TAB: Buscar
│   │   ├── SEARCH-01  Buscar (input + categorías rápidas)
│   │   ├── SEARCH-02  Resultados de búsqueda (listado)
│   │   └── SEARCH-03  Mapa (mapa full con pins de comercios)
│   │
│   ├── TAB: Guardado  [MVP+]
│   │   └── FAV-01  Favoritos y comercios seguidos
│   │
│   └── TAB: Perfil
│       ├── PROFILE-01  Mi perfil CUSTOMER
│       ├── PROFILE-02  Configuración y notificaciones
│       └── PROFILE-03  Propuestas y votos  [MVP+]
│
├── OWNER (módulo separado, accesible desde Perfil o deep link)
│   ├── OWNER-01  Panel "Mi comercio" (dashboard resumen)
│   ├── OWNER-02  Perfil del comercio (edición de datos)
│   ├── OWNER-03  Productos (listado)
│   │   ├── OWNER-04  Alta de producto (formulario)
│   │   └── OWNER-05  Edición de producto (formulario)
│   ├── OWNER-06  Horarios y señales operativas
│   │   ├── OWNER-07  Edición de horarios regulares
│   │   └── OWNER-08  Señal operativa especial (modal)
│   └── OWNER-09  Turnos de farmacia
│       ├── OWNER-10  Ver calendario de turnos
│       └── OWNER-11  Cargar / confirmar turno
│
├── DETALLE (accesibles desde múltiples contextos)
│   ├── DETAIL-01  Ficha pública de comercio
│   │   └── DETAIL-02  Ficha de producto (bottom sheet / pantalla)
│   └── DETAIL-03  Perfil de onboarding OWNER (registro de comercio)
│       ├── ONBOARDING-OWNER-01  Tipo y nombre del comercio
│       ├── ONBOARDING-OWNER-02  Dirección y zona
│       ├── ONBOARDING-OWNER-03  Horarios iniciales
│       └── ONBOARDING-OWNER-04  Confirmación y activación
│
└── ADMIN (solo rol admin, acceso por deep link o perfil)
    ├── ADMIN-01  Panel de control (métricas rápidas)
    ├── ADMIN-02  Listado de comercios (moderación)
    ├── ADMIN-03  Detalle de comercio (revisión + acciones)
    └── ADMIN-04  Listado de señales reportadas
```

---

## 3. Fichas por pantalla

### AUTH-01 — Splash / Loading
- **Propósito:** inicializar Firebase Auth, detectar sesión activa.
- **Salida:** → HOME-01 si hay sesión válida, → AUTH-02 si es primer uso, → AUTH-03 si hay sesión caducada.
- **Datos:** ninguno (local).

### AUTH-02 — Onboarding CUSTOMER
- **Propósito:** explicar el valor de TuM2 en 3 slides antes del registro.
- **Slides sugeridos:**
  1. "Encontrá comercios abiertos ahora en tu cuadra"
  2. "Farmacias de turno al instante"
  3. "Seguí tus comercios favoritos"
- **Acción CTA:** "Empezar" → AUTH-03.
- **Skip:** posible, va directo a AUTH-03.

### AUTH-03 — Login / Registro
- **Propósito:** autenticación unificada (CUSTOMER y OWNER usan la misma entrada).
- **Métodos:** email + magic link, Google Sign-In.
- **Flujo OWNER:** si email está en `pending_owners`, redirigir a DETAIL-03 (onboarding de comercio).
- **Salida:** → HOME-01.

### AUTH-04 — Verificación de email
- **Propósito:** confirmar email en flujo magic link.
- **Estado:** pantalla de espera + deep link callback.

---

### HOME-01 — Home (feed zonal)
- **Propósito:** mostrar valor en menos de 5 segundos.
- **Bloques UI:**
  - Barra de zona activa (con opción de cambiar zona).
  - Quick actions: Abierto ahora, Farmacias de turno, Kioscos cerca, Gomerías cerca.
  - Sección "Farmacias de turno hoy" (si hay turnos activos).
  - Feed principal: listado de comercios de la zona (`merchant_public`).
- **Ordenamiento:** `sortBoost desc` → `isOpenNow desc` → distancia.
- **Fallback zona vacía:** CTA "Sugerir un comercio" + resultados `review_pending` con badge.
- **Salidas:** → DETAIL-01, → HOME-02, → HOME-03, → SEARCH-01.

### HOME-02 — Abierto ahora ✅ diseñado e implementado
- **Propósito:** filtrar solo comercios con `isOpenNow = true` en la zona.
- **Fuente:** `merchant_public` con filtro `isOpenNow == true`.
- **UI implementada:**
  - Header: zona activa ("PALERMO") + título "Abierto ahora" + chip "En vivo" con indicador verde pulsante.
  - Barra de estado: ícono storefront + contador de resultados + hora actual.
  - Filtro por categoría: chips horizontales animados (Todos / Farmacias / Kioscos / Almacenes / Veterinarias / Comida al paso / Rotiserías / Gomerías).
  - Lista de comercios: `_CommerceCard` con thumbnail, nombre, tipo·zona, distancia, horario de cierre, rating, botón filled/outline.
  - Estado vacío: ícono + mensaje + CTA "Ver todos los rubros".
  - Barra inferior fija "Ver en el mapa" → SEARCH-03.
- **Archivo:** `modules/home/screens/abierto_ahora_screen.dart`
- **Salida:** → DETAIL-01, → SEARCH-03 (mapa).

### HOME-03 — Farmacias de turno ✅ diseñado e implementado
- **Propósito:** ver qué farmacia está de guardia hoy y cómo llegar.
- **Fuente:** `merchant_public` filtrado `isOnDutyToday == true` + colección `pharmacy_duties`.
- **UI implementada:**
  - Header: fecha formateada en español (ej: "MIÉRCOLES 24 DE MAR") + badge "HOY" verde.
  - Meta row: zona activa + cantidad de farmacias de turno.
  - Hero card farmacia activa: fondo azul oscuro, badge "ACTIVA AHORA" con punto pulsante, rating, nombre, dirección/horarios/distancia, botón "Cómo llegar" + ícono teléfono.
  - Sección "Resto del día": header con contador + lista `_PharmacyListItem` (ícono, nombre, dirección, horario, distancia, chevron).
  - Disclaimer: caja tertiary50 con ícono info y texto sobre actualización de turnos.
- **Archivo:** `modules/home/screens/farmacias_turno_screen.dart`
- **Salida:** → DETAIL-01, → mapa nativo (llamada / cómo llegar).

---

### SEARCH-01 — Buscar ✅ diseñado e implementado
- **Propósito:** descubrimiento activo por texto o categoría.
- **Estados:**
  1. **Initial** — header TuM2, barra tappable, accesos rápidos (Farmacias de turno / Kioscos 24h / Cerca de ti / Mi zona), sugerencias para ti (hero card + grid + lista).
  2. **Focused** — búsquedas recientes + BORRAR ALL, explorar categorías (grid íconos), barrios populares.
  3. **Typing** — autocompletado filtrado por query, tendencias del barrio (carousel).
- **Archivos:** `modules/search/screens/search_screen.dart`, `modules/search/widgets/zone_selector_sheet.dart`, `modules/search/widgets/search_filters_sheet.dart`
- **Salida:** → SEARCH-02, → SEARCH-03, → SEARCH-farmacias.

### SEARCH-02 — Resultados de búsqueda ✅ diseñado e implementado
- **Fuente:** `merchant_public` filtrado por query/categoría (client-side en MVP).
- **Estados:** loading (skeletons) / results (lista) / openNow / verified / empty / error.
- **Barra inferior:** "Vista en mapa" → SEARCH-03.
- **Archivo:** `modules/search/screens/search_results_screen.dart`
- **Salida:** → DETAIL-01, → SEARCH-03.

### SEARCH-FARMACIAS — Especialidad Farmacias ✅ diseñado e implementado
- **Propósito:** vista dedicada a farmacias con énfasis en turno activo.
- **Bloques:** hero farmacia de turno (CTAs: Cómo llegar / Llamar), filtros (De Turno / Abierto / 24hs), grid 2×2 farmacias cercanas, sección confianza.
- **Archivo:** `modules/search/screens/pharmacy_results_screen.dart`

### SEARCH-UBICACION — Fallback de ubicación ✅ diseñado e implementado
- **Propósito:** cuando GPS no disponible o denegado. Selección manual de zona.
- **Bloques:** input manual, lista sugerencias, FAQ zona, mapa interactivo, "Explorar toda la ciudad".
- **Archivo:** `modules/search/screens/location_fallback_screen.dart`

### SEARCH-03 — Mapa ✅ implementado (Google Maps + marker system)
- **Propósito:** ver comercios de la zona en mapa interactivo.
- **Fuente:** misma query de SEARCH-02 o HOME-01 según contexto de entrada.
- **UI/estado operativo implementado:**
  - Markers con resolución de prioridad: `guardia > open24h > open > closed > default`.
  - Variantes visuales seleccionadas (`selected*`) para foco de comercio sin alterar estado de negocio.
  - Z-index consistente: guardia por encima del resto y markers seleccionados por encima de no seleccionados.
  - Clustering por grilla para densidad alta (más de 20 comercios visibles) con tap para zoom in automático.
  - Cache de bitmaps por `visualType + pixelRatio` para evitar regeneración en cada rebuild.
  - Fallback web para `BitmapDescriptor` cuando no aplica render custom.
- **Salida:** → DETAIL-01 desde bottom sheet.

---

### DETAIL-01 — Ficha pública de comercio
- **Propósito:** toda la información útil de un comercio en una pantalla.
- **Secciones:**
  - Header: nombre, categoría, estado (abierto/cerrado/turno), dirección, distancia.
  - Horarios: tabla de días + señal operativa activa si existe.
  - Productos destacados (si hay, máx 6 ítems).
  - Acciones rápidas: llamar, cómo llegar, compartir, seguir.
  - Sobre el comercio: descripción, redes sociales.
- **Fuente:** `merchant_public/{merchantId}` + `products/{merchantId}`.
- **Salida:** → DETAIL-02 (producto), → mapa nativo, → teléfono nativo.

### DETAIL-02 — Ficha de producto
- **Propósito:** detalle de un producto específico.
- **Presentación:** bottom sheet deslizable o pantalla completa según contexto.
- **Datos:** nombre, descripción, precio, disponibilidad, foto.
- **Fuente:** `products/{merchantId}/{productId}`.

---

### OWNER-01 — Panel "Mi comercio"
- **Propósito:** dashboard operativo del dueño.
- **Bloques:**
  - Estado del comercio ahora (abierto / cerrado / turno).
  - Señal operativa activa (si la hay).
  - Accesos rápidos: editar horario, agregar señal, ver productos.
  - Alertas: si falta completar datos del perfil.
- **Fuente:** `merchants/{merchantId}` (lectura directa, rol owner).
- **Salida:** → OWNER-02, OWNER-03, OWNER-06, OWNER-09.

### OWNER-02 — Perfil del comercio (edición)
- **Campos:** nombre, dirección, teléfono, descripción, categorías, redes sociales, logo/foto.
- **Validación:** dirección obligatoria, nombre obligatorio.
- **Guardado:** actualiza `merchants/{merchantId}` + trigger recalcula `merchant_public`.

### OWNER-03 — Productos (listado)
- **Lista:** todos los productos del comercio con estado (activo/inactivo).
- **Acciones:** agregar (+), editar, archivar.
- **Fuente:** `products/{merchantId}`.
- **Salida:** → OWNER-04 (alta), → OWNER-05 (edición).

### OWNER-04 — Alta de producto
- **Campos:** nombre, descripción, precio, categoría, foto, disponibilidad.
- **Guardado:** crea `products/{merchantId}/{productId}`.

### OWNER-05 — Edición de producto
- **Mismos campos que OWNER-04**, precargados.
- **Acción adicional:** archivar (soft delete).

### OWNER-06 — Horarios y señales operativas
- **Secciones:**
  - Horarios regulares por día (lunes a domingo).
  - Señal operativa activa actual (si existe).
  - Historial de señales recientes.
- **Acciones:** editar horarios → OWNER-07, agregar señal → OWNER-08.

### OWNER-07 — Edición de horarios regulares
- **UI:** selector de horario por día + opción "cerrado ese día".
- **Guardado:** actualiza `schedule/{merchantId}` + trigger recalcula `isOpenNow`.

### OWNER-08 — Señal operativa especial (modal)
- **Propósito:** indicar estado temporal (vacaciones, cierre por feriado, demora, etc.).
- **Campos:** tipo de señal, mensaje corto (max 80 chars), fecha/hora inicio, fecha/hora fin (opcional).
- **Tipos de señal:** `vacation`, `temporary_closure`, `delay`, `special_hours`, `custom`.
- **Guardado:** crea `operative_signals/{merchantId}/{signalId}`.

### OWNER-09 — Turnos de farmacia
- **Solo visible si** `merchant.categoryTags` incluye `pharmacy`.
- **Secciones:** próximos turnos, historial, estado de confirmación.

### OWNER-10 — Ver calendario de turnos
- **UI:** calendario mensual con días de turno marcados.
- **Fuente:** `pharmacy_duties/{zone}/{year-month}`.

### OWNER-11 — Cargar / confirmar turno
- **Flujo:** seleccionar fecha → confirmar guardia → guardado en `pharmacy_duties`.
- **Validación:** solo un turno activo por fecha por zona.

---

### DETAIL-03 — Onboarding OWNER (registro de comercio)
Flujo multi-paso para registrar un comercio nuevo.

#### ONBOARDING-OWNER-01 — Tipo y nombre
- Nombre comercial, tipo/rubro principal.

#### ONBOARDING-OWNER-02 — Dirección y zona
- Dirección con autocompletado (Google Places).
- Asignación automática de `zoneId`.

#### ONBOARDING-OWNER-03 — Horarios iniciales
- Horarios típicos de apertura/cierre por día.
- Puede saltearse con "Completar después".

#### ONBOARDING-OWNER-04 — Confirmación y activación
- Resumen de datos ingresados.
- CTA: "Publicar mi comercio" → crea `merchants/{merchantId}` con `visibilityStatus: review_pending`.
- Mensaje: "Tu comercio será visible una vez revisado" (o visible inmediato si auto-approve activo).

---

### ADMIN-01 — Panel de control
- Métricas: nuevos comercios pendientes, señales reportadas, votos recientes.
- Accesos rápidos a flujos de moderación.

### ADMIN-02 — Listado de comercios
- Filtros: zona, estado, categoría, fecha de alta.
- Acciones masivas: aprobar, rechazar, marcar revisión.

### ADMIN-03 — Detalle de comercio (revisión)
- Vista completa del comercio + historial de cambios.
- Acciones: aprobar (`visible`), rechazar (`rejected`), pedir corrección.

### ADMIN-04 — Señales reportadas
- Listado de `operative_signals` o datos reportados por usuarios.
- Acciones: validar, eliminar, notificar al owner.

---

## 4. Deep links

| Deep link | Pantalla destino |
|-----------|-----------------|
| `tum2://comercio/{merchantId}` | DETAIL-01 |
| `tum2://producto/{merchantId}/{productId}` | DETAIL-02 |
| `tum2://farmacias-turno/{zoneId}` | HOME-03 |
| `tum2://abierto-ahora/{zoneId}` | HOME-02 |
| `tum2://owner/comercio/{merchantId}` | OWNER-01 |
| `tum2://owner/turno` | OWNER-09 |
| `tum2://admin` | ADMIN-01 |

---

## 5. Estados de visibilidad por segmento

| Pantalla | Sin sesión | CUSTOMER | OWNER | ADMIN |
|----------|-----------|----------|-------|-------|
| HOME-01 | ✅ | ✅ | ✅ | ✅ |
| HOME-02 | ✅ | ✅ | ✅ | ✅ |
| HOME-03 | ✅ | ✅ | ✅ | ✅ |
| SEARCH-01/02/03 | ✅ | ✅ | ✅ | ✅ |
| DETAIL-01 | ✅ | ✅ | ✅ | ✅ |
| DETAIL-02 | ✅ | ✅ | ✅ | ✅ |
| FAV-01 | ❌ (pide login) | ✅ | ✅ | ✅ |
| PROFILE-01 | ❌ | ✅ | ✅ | ✅ |
| OWNER-* | ❌ | ❌ | ✅ | ✅ |
| DETAIL-03 | ❌ (solo al registrarse) | ❌ | ✅ | ✅ |
| ADMIN-* | ❌ | ❌ | ❌ | ✅ |

---

## 6. Flujos principales end-to-end

### Flujo 1: CUSTOMER busca farmacia de turno
```
HOME-01 → tap "Farmacias de turno" → HOME-03 → tap farmacia → DETAIL-01 → tap "Cómo llegar"
```

### Flujo 2: CUSTOMER busca almacén abierto
```
HOME-01 → tap "Abierto ahora" → HOME-02 (filtrado) → tap comercio → DETAIL-01
```
o
```
HOME-01 → tap Buscar tab → SEARCH-01 → tap "Almacenes" → SEARCH-02 → tap comercio → DETAIL-01
```

### Flujo 3: OWNER activa señal de vacaciones
```
OWNER-01 → tap "Agregar señal" → OWNER-08 (modal) → selecciona "Vacaciones" + fechas → Guardar → vuelve a OWNER-01 con señal activa visible
```

### Flujo 4: OWNER carga turno de farmacia
```
OWNER-01 → tap "Turnos" → OWNER-09 → OWNER-10 (calendario) → selecciona fecha → OWNER-11 → Confirmar → vuelve a OWNER-10 con día marcado
```

### Flujo 5: OWNER nuevo se registra
```
AUTH-03 → (email detectado como owner pendiente) → DETAIL-03 → ONBOARDING-OWNER-01 → 02 → 03 → 04 → OWNER-01
```

### Flujo 6: CUSTOMER nuevo descubre app
```
AUTH-01 (splash) → AUTH-02 (onboarding 3 slides) → AUTH-03 (registro) → HOME-01
```

### Flujo 7: ADMIN aprueba comercio nuevo
```
ADMIN-01 → badge "2 pendientes" → ADMIN-02 (filtro: pendientes) → tap comercio → ADMIN-03 → tap "Aprobar" → vuelve a ADMIN-02
```

---

## 7. Pantallas MVP vs Post-MVP

### En MVP
- AUTH-01, AUTH-02, AUTH-03, AUTH-04
- HOME-01, HOME-02, HOME-03
- SEARCH-01, SEARCH-02, SEARCH-03
- DETAIL-01, DETAIL-02
- DETAIL-03 + ONBOARDING-OWNER-01 a 04
- OWNER-01 a 11
- ADMIN-01 a 04
- PROFILE-01, PROFILE-02

### Post-MVP (MVP+)
- FAV-01 — Favoritos y seguidos (TuM2-0062, 0063)
- PROFILE-03 — Propuestas y votos (TuM2-0069)
- Módulo de propuestas completo (TuM2-0041)

---

*Documento generado para TuM2-0027. Ver NAVIGATION.md para la arquitectura de navegación y stacks.*
