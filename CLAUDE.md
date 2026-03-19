# CLAUDE.md — Memoria persistente del proyecto TuM2

## Estado del backlog

El backlog maestro de TuM2 está estructurado en 15 épicas (ver sección abajo).
El usuario pasa las tarjetas de a una. Estado actual:

| ID     | Tarjeta                              | Épica                  | Estado      |
|--------|--------------------------------------|------------------------|-------------|
| 0001   | Definir propuesta de valor final     | Dirección del producto | ✅ Entregada |

---

## Backlog Maestro TuM2

### ÉPICA 1: Dirección del producto
- [0001] **Definir propuesta de valor final de TuM2** — P0 — `Producto, Fundacional` ✅
- [0002] **Definir claim principal de marca** — P1 — `Branding, Producto`
  - Opciones: "Lo que necesitás, en tu zona" / "Todo lo que pasa en tu metro cuadrado" / "Comercios reales, cerca tuyo"
- [0003] **Cerrar alcance real del MVP** — P0 — `Producto, Fundacional`
- [0004] **Cerrar segmentos principales** — P0 — `Producto, Seguridad`
  - OWNER, CUSTOMER y ADMIN con sus objetivos

### ÉPICA 2: Documentación maestra
- [0005] **Mantener actualizado VISION.md** — P0 — `Producto`
- [0006] **Mantener actualizado PRD-MVP.md** — P0 — `Producto`
- [0007] **Mantener actualizado ARCHITECTURE.md** — P0 — `Backend, Mobile, Web`
- [0008] **Mantener actualizado ROADMAP.md** — P1 — `Producto`
- [0009] **Mantener actualizado PROMPT-PLAYBOOK.md** — P1 — `Producto, Operaciones`

### ÉPICA 3: Branding de TuM2
- [0010] **Definir identidad visual base** — P0 — `Branding, UX/UI`
- [0011] **Diseñar logo principal** — P0 — `Branding`
- [0012] **Diseñar app icon** — P0 — `Branding, Mobile`
- [0013] **Definir sistema de sellos** — P1 — `Branding, Producto`
- [0014] **Definir tono de microcopy** — P1 — `Branding, UX/UI`

### ÉPICA 4: Research funcional
- [0015] **Relevar rubros prioritarios** — P0 — `Producto, Research`
  - Base sugerida: farmacias, kioscos, almacenes, veterinarias
- [0016] **Relevar caso farmacias de turno** — P0 — `Producto, Operaciones`
- [0017] **Relevar señales operativas por rubro** — P0 — `Producto, Data`
- [0018] **Relevar flujo real del dueño** — P1 — `Producto, UX/UI`

### ÉPICA 5: Modelo de datos
- [0019] **Diseñar modelo de usuarios** — P0 — `Data, Backend`
- [0020] **Diseñar modelo de comercios** — P0 — `Data, Backend`
- [0021] **Diseñar modelo de productos** — P0 — `Data, Backend`
- [0022] **Diseñar modelo de horarios** — P0 — `Data, Backend`
- [0023] **Diseñar modelo de señales operativas** — P0 — `Data, Backend`
- [0024] **Diseñar modelo de turnos/guardias** — P0 — `Data, Backend`
- [0025] **Diseñar modelo de propuestas y votos** — P1 — `Data, Backend`
- [0026] **Diseñar modelo de badges y branding snippets** — P2 — `Data, Branding`

### ÉPICA 6: UX / arquitectura de pantallas
- [0027] **Definir mapa completo de pantallas** — P0 — `UX/UI, Producto`
- [0028] **Diseñar navegación principal** — P0 — `UX/UI, Mobile`
- [0029] **Diseñar onboarding CUSTOMER** — P1 — `UX/UI`
- [0030] **Diseñar onboarding OWNER** — P0 — `UX/UI`
- [0031] **Diseñar pantalla Buscar** — P0 — `UX/UI`
- [0032] **Diseñar pantalla Mapa** — P0 — `UX/UI`
- [0033] **Diseñar ficha pública de comercio** — P0 — `UX/UI`
- [0034] **Diseñar ficha de producto** — P1 — `UX/UI`
- [0035] **Diseñar vista Farmacias de turno** — P0 — `UX/UI`
- [0036] **Diseñar vista Abierto ahora** — P0 — `UX/UI`
- [0037] **Diseñar panel Mi comercio** — P0 — `UX/UI, Owner`
- [0038] **Diseñar flujo carga de productos** — P0 — `UX/UI, Owner`
- [0039] **Diseñar flujo carga de horarios y señales** — P0 — `UX/UI, Owner`
- [0040] **Diseñar flujo carga de turnos de farmacia** — P0 — `UX/UI, Owner`
- [0041] **Diseñar board de propuestas y votos** — P1 — `UX/UI, Producto`

### ÉPICA 7: Backend / Firebase
- [0042] **Crear proyecto base Firebase** — P0 — `Backend, Fundacional`
- [0043] **Configurar Authentication** — P0 — `Backend, Seguridad`
- [0044] **Configurar Firestore base** — P0 — `Backend, Data`
- [0045] **Definir Firestore Rules iniciales** — P0 — `Seguridad, Backend`
- [0046] **Configurar Storage** — P1 — `Backend`
- [0047] **Implementar Cloud Functions base** — P1 — `Backend`
- [0048] **Implementar campos derivados operativos** — P0 — `Backend, Data`
  - isOpenNow, isOnDutyToday, etc.
- [0049] **Implementar agregados públicos** — P1 — `Backend, Data`

### ÉPICA 8: Mobile app
- [0050] **Crear proyecto mobile base** — P0 — `Mobile`
- [0051] **Implementar shell de app** — P0 — `Mobile`
- [0052] **Implementar login / registro** — P0 — `Mobile, Auth`
- [0053] **Implementar home CUSTOMER** — P0 — `Mobile`
- [0054] **Implementar búsqueda de comercios** — P0 — `Mobile`
- [0055] **Implementar mapa** — P1 — `Mobile, Maps`
- [0056] **Implementar ficha de comercio** — P0 — `Mobile`
- [0057] **Implementar ficha de producto** — P1 — `Mobile`
- [0058] **Implementar vista Abierto ahora** — P0 — `Mobile`
- [0059] **Implementar vista Farmacias de turno** — P0 — `Mobile`
- [0060] **Implementar favoritos** — P1 — `Mobile`
- [0061] **Implementar seguir comercio** — P1 — `Mobile`
- [0062] **Implementar módulo OWNER** — P0 — `Mobile, Owner`
- [0063] **Implementar alta/edición de productos** — P0 — `Mobile, Owner`
- [0064] **Implementar carga de horarios** — P0 — `Mobile, Owner`
- [0065] **Implementar carga de señales operativas** — P0 — `Mobile, Owner`
- [0066] **Implementar carga de turnos farmacia** — P0 — `Mobile, Owner`
- [0067] **Implementar módulo de propuestas y votos** — P1 — `Mobile, Producto`

### ÉPICA 9: Web pública
- [0068] **Crear web pública base** — P1 — `Web`
- [0069] **Implementar landing principal** — P1 — `Web, Branding`
- [0070] **Implementar ficha pública de comercio web** — P0 — `Web`
- [0071] **Implementar ficha pública de producto web** — P1 — `Web`
- [0072] **Implementar landing Farmacias de turno web** — P0 — `Web`
- [0073] **Implementar landing Abierto ahora web** — P0 — `Web`
- [0074] **Implementar links compartibles** — P1 — `Web, Growth`

### ÉPICA 10: Admin / Moderación
- [0075] **Diseñar panel admin mínimo** — P1 — `Admin, Producto`
- [0076] **Implementar listado de comercios** — P1 — `Admin`
- [0077] **Implementar listado de propuestas** — P1 — `Admin`
- [0078] **Implementar moderación de contenido** — P1 — `Admin, Seguridad`
- [0079] **Implementar revisión de señales reportadas** — P1 — `Admin, Operaciones`

### ÉPICA 11: Analytics
- [0080] **Definir eventos analytics** — P0 — `Analytics, Producto`
- [0081] **Implementar tracking base** — P0 — `Analytics, Mobile, Web`
- [0082] **Crear dashboard MVP** — P1 — `Analytics`
- [0083] **Medir activación OWNER** — P1 — `Analytics`
- [0084] **Medir activación CUSTOMER** — P1 — `Analytics`
- [0085] **Medir uso de señales operativas** — P0 — `Analytics`

### ÉPICA 12: Seguridad / calidad
- [0086] **Configurar App Check** — P1 — `Seguridad`
- [0087] **Configurar Crashlytics** — P1 — `Seguridad, Analytics`
- [0088] **Crear checklist QA MVP** — P0 — `QA`
- [0089] **Testear permisos por rol** — P0 — `QA, Seguridad`
- [0090] **Testear edge cases operativos** — P0 — `QA`

### ÉPICA 13: Lanzamiento
- [0091] **Definir piloto geográfico** — P0 — `Lanzamiento, Producto`
- [0092] **Definir rubros iniciales de salida** — P0 — `Lanzamiento`
- [0093] **Armar material de onboarding para comercios** — P1 — `Growth, Operaciones`
- [0094] **Armar material para captar primeras farmacias** — P0 — `Growth, Operaciones`
- [0095] **Preparar publicación beta** — P1 — `Lanzamiento, Mobile, Web`

### ÉPICA 14: Growth / comunidad
- [0096] **Diseñar sistema de propuestas y votos usable** — P1 — `Growth, Producto`
- [0097] **Implementar links compartibles de propuestas** — P1 — `Growth`
- [0098] **Definir loop de invitación** — P2 — `Growth`
- [0099] **Diseñar badges comunitarios** — P2 — `Branding, Growth`

### ÉPICA 15: Post-MVP (no priorizar hasta validar el núcleo)
- Carga masiva de productos
- Carga masiva de calendarios
- Mejor discover geográfico
- Verificación avanzada
- Promociones patrocinadas
- Monetización no invasiva
- Rankings por zona
- Reputación de comercios
- Más automatización operativa

---

## Orden real de ejecución recomendado
1. Dirección del producto
2. Documentación maestra
3. Branding base
4. Modelo de datos
5. UX de pantallas
6. Backend base
7. Mobile base
8. Web pública mínima
9. Admin mínimo
10. Analytics
11. QA
12. Lanzamiento piloto

---

## Reglas operativas
- Máximo 1-3 tareas grandes activas simultáneamente
- Máximo 3-5 tareas chicas activas simultáneamente
- Pasar a "Listo para hacer" solo lo que corresponde a la fase actual
