# TuM2 — PRD del MVP v1

Define el alcance funcional, los criterios de aceptación y las restricciones del MVP de TuM2.

---

## 1. Alcance del MVP

El MVP de TuM2 cubre **una zona piloto** con **rubros prioritarios**, con el objetivo de demostrar la propuesta de valor central: que un vecino puede encontrar qué comercio de su barrio está abierto y actualizado, en menos de 10 segundos.

### Zona piloto
- 1 barrio urbano de Buenos Aires (por definir en TuM2-0094).
- Objetivo: 30-100 comercios activos en el piloto.

### Rubros prioritarios en MVP

1. Farmacias (incluye turno de guardia)
2. Kioscos
3. Almacenes
4. Veterinarias
5. Tiendas de comida al paso
6. Casas de comida / Rotiserías
7. Gomerías

---

## 2. Segmentos y roles

| Rol | Descripción | Autenticación requerida |
|-----|-------------|------------------------|
| CUSTOMER | Vecino que busca comercios | No (lectura pública), Sí (guardar favoritos) |
| OWNER | Dueño o encargado de un comercio | Sí (siempre) |
| ADMIN | Equipo TuM2, moderación | Sí (siempre) |

---

## 3. Features del MVP por segmento

### 3.1 CUSTOMER — Descubrimiento

| ID | Feature | Prioridad | Notas |
|----|---------|-----------|-------|
| F-C01 | Ver feed de comercios de la zona | P0 | Home-01, ordenado por sortBoost |
| F-C02 | Filtrar "Abierto ahora" | P0 | isOpenNow en merchant_public |
| F-C03 | Ver farmacias de turno hoy | P0 | pharmacy_duties + isOnDutyToday |
| F-C04 | Buscar por categoría | P0 | Chips de categoría en SEARCH-01 |
| F-C05 | Buscar por texto libre | P0 | Client-side en MVP (searchKeywords) |
| F-C06 | Ver mapa de comercios | P1 | SEARCH-03, pins por estado |
| F-C07 | Ver ficha pública de comercio | P0 | DETAIL-01 |
| F-C08 | Ver ficha de producto | P1 | DETAIL-02, bottom sheet |
| F-C09 | Acción "Cómo llegar" | P0 | Link nativo a Maps |
| F-C10 | Acción "Llamar" | P0 | Link nativo tel: |
| F-C11 | Compartir comercio | P1 | Deep link |

### 3.2 CUSTOMER — Cuenta

| ID | Feature | Prioridad | Notas |
|----|---------|-----------|-------|
| F-C20 | Registro con email + magic link | P0 | Firebase Auth |
| F-C21 | Registro con Google Sign-In | P0 | Firebase Auth |
| F-C22 | Onboarding de 3 slides | P0 | AUTH-02 |
| F-C23 | Perfil básico (nombre, email) | P1 | PROFILE-01 |
| F-C24 | Configuración de notificaciones | P1 | PROFILE-02 |
| F-C25 | Favoritos y seguir comercio | P2 | MVP+ |

### 3.3 OWNER — Gestión del comercio

| ID | Feature | Prioridad | Notas |
|----|---------|-----------|-------|
| F-O01 | Registro y onboarding del comercio | P0 | DETAIL-03, 4 pasos |
| F-O02 | Dashboard operativo "Mi comercio" | P0 | OWNER-01 |
| F-O03 | Editar perfil del comercio | P0 | OWNER-02 |
| F-O04 | Cargar y editar horarios regulares | P0 | OWNER-07 |
| F-O05 | Cargar señal operativa temporal | P0 | OWNER-08 (modal) |
| F-O06 | Listar productos del comercio | P0 | OWNER-03 |
| F-O07 | Alta de producto | P0 | OWNER-04 |
| F-O08 | Edición de producto | P0 | OWNER-05 |
| F-O09 | Cargar turno de farmacia | P0 | OWNER-11 (solo farmacias) |
| F-O10 | Ver calendario de turnos | P0 | OWNER-10 (solo farmacias) |

### 3.4 ADMIN — Moderación

| ID | Feature | Prioridad | Notas |
|----|---------|-----------|-------|
| F-A01 | Panel de control con métricas | P1 | ADMIN-01 |
| F-A02 | Listado de comercios (filtrado) | P0 | ADMIN-02 |
| F-A03 | Revisión y aprobación de comercio | P0 | ADMIN-03 |
| F-A04 | Listado de señales reportadas | P1 | ADMIN-04 |
| F-A05 | Trigger de bootstrap por zona | P0 | Admin callable (Cloud Function) |

---

## 4. Features excluidas del MVP

| Feature | Razón de exclusión |
|---------|--------------------|
| Favoritos / seguir comercio | MVP+ (TuM2-0062, 0063) |
| Propuestas y votos | MVP+ (TuM2-0069) |
| Notificaciones push | Complejidad, post-MVP |
| Reseñas / calificaciones | Fuera del scope por decisión de producto |
| Ficha de producto web | MVP+ (TuM2-0073) |
| Links compartibles | MVP+ (TuM2-0076) |
| Carga masiva de datos | Post-MVP (TuM2-0112) |
| Verificación avanzada | Post-MVP (TuM2-0115) |

---

## 5. Plataformas cubiertas en MVP

| Plataforma | Incluida | Notas |
|------------|---------|-------|
| App mobile iOS | ✅ | Flutter |
| App mobile Android | ✅ | Flutter |
| Web pública | ✅ | Fichas, farmacias de turno, abierto ahora |
| Panel admin web | ✅ | Moderación básica |
| API pública | ❌ | Post-MVP |

---

## 6. Restricciones de MVP

### Técnicas
- Firebase (Auth, Firestore, Functions, Storage) como backend exclusivo.
- No hay búsqueda full-text server-side en MVP (se usa `searchKeywords` en cliente).
- Mapas: google_maps_flutter (Google Maps SDK) en mobile, embed estático en web en MVP.
- Sin pagos, sin carrito, sin checkout.

### De negocio
- Solo 1 zona piloto al lanzar.
- El bootstrap inicial de comercios usa Google Places como fuente semilla (admin-only, controlado).
- Los turnos de farmacia los carga el owner o el admin; no hay automatización de fuentes externas en MVP.
- No hay SLA de actualización; la información es best-effort.

### De UX
- Mobile-first. La app nativa es la experiencia primaria.
- La web pública en MVP es mayormente de lectura (no se puede gestionar el comercio desde la web).

---

## 7. Criterios de aceptación del MVP

### Para lanzar beta cerrada
- [ ] Al menos 20 comercios activos en la zona piloto con datos completos.
- [ ] Farmacias de turno funcionando para la zona piloto.
- [ ] Flujo CUSTOMER completo: buscar → ver ficha → llamar / cómo llegar.
- [ ] Flujo OWNER completo: registrar comercio → cargar horarios → señal operativa.
- [ ] Flujo ADMIN completo: revisar → aprobar → ver en la app.
- [ ] App publicada en TestFlight (iOS) y APK interno (Android).
- [ ] Web pública accesible con al menos: ficha de comercio, farmacias de turno, abierto ahora.
- [ ] Reglas Firestore cubren todos los accesos por rol.
- [ ] Política de privacidad y términos disponibles en la app.

### Para lanzar beta abierta
- [ ] 50+ comercios en zona piloto.
- [ ] QA completo de permisos por rol.
- [ ] Crashlytics + Analytics base funcionando.
- [ ] Disclaimer legal para información operativa visible al usuario.
- [ ] Material de onboarding para comercios disponible.

---

## 8. Dependencias críticas

| Dependencia | Bloquea |
|-------------|---------|
| TuM2-0094 Zona piloto definida | Bootstrap, farmacias de turno |
| TuM2-0095 Rubros de salida | Bootstrap, categorías de la app |
| TuM2-0097 Material farmacias | Activación OWNER |
| TuM2-0100/0101 Legal | Publicación en stores |
| TuM2-0121 Estrategia bootstrap | Cobertura inicial de comercios |

---

## 9. Stack técnico confirmado

| Capa | Tecnología |
|------|-----------|
| Mobile | Flutter |
| Navegación | go_router |
| Backend | Firebase (Firestore, Auth, Functions) |
| Functions | Node.js 20 + TypeScript |
| Web | Flutter Web |
| Storage | Firebase Storage |
| Analytics | Firebase Analytics + Crashlytics |
| Mapas mobile | react-native-maps (Google Maps) |
| Mapas web | Google Maps Embed API |

---

*Documento para TuM2-0006. Ver VISION.md para contexto estratégico y ARCHITECTURE.md para decisiones técnicas.*
