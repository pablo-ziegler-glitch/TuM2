# TuM2 — PRD MVP
### Tarjeta: TuM2-0006

Product Requirements Document para el lanzamiento del MVP. Define el alcance real, los criterios de aceptación y lo que explícitamente queda fuera.

---

## 1. Alcance del MVP

El MVP debe resolver **dos jobs-to-be-done** con suficiente calidad para generar valor real:

1. **CUSTOMER:** "Quiero saber si el comercio de la vuelta está abierto ahora y qué tiene disponible."
2. **OWNER:** "Quiero tener presencia digital en mi barrio sin necesitar un técnico."

Todo lo que no sirve directamente a estos dos jobs queda fuera del MVP.

---

## 2. Funcionalidades incluidas en MVP

### CUSTOMER

| Feature | Descripción | Prioridad |
|---------|-------------|-----------|
| Búsqueda de comercios | Por nombre, categoría, zona | P0 |
| Ficha de comercio | Nombre, categoría, dirección, horario, señales operativas | P0 |
| Abierto ahora | Listado de comercios con `isOpenNow: true` en la zona | P0 |
| Farmacias de turno | Vista dedicada con `isOnDutyToday: true` | P0 |
| Navegación por categorías | Filtro por rubro (farmacia, kiosco, almacén, etc.) | P0 |
| Mapa de comercios | Vista mapa con pins de comercios cercanos | P1 |
| Ficha de producto | Nombre, descripción, precio, stock | P2 |
| Favoritos | Guardar comercios | P2 |

### OWNER

| Feature | Descripción | Prioridad |
|---------|-------------|-----------|
| Registro de comercio | Onboarding en 4 pasos (nombre, dirección, horarios, confirmación) | P0 |
| Gestión de horarios | Carga semanal con días activos/inactivos y bloques horarios | P0 |
| Gestión de señales operativas | 24 hs, delivery, horario especial, etc. | P0 |
| Alta de productos | Nombre, descripción, precio, stock, imagen | P0 |
| Edición de perfil de comercio | Nombre, categoría, descripción, imagen | P0 |
| Carga de turnos de farmacia | Calendario mensual de guardias | P0 |

### ADMIN

| Feature | Descripción | Prioridad |
|---------|-------------|-----------|
| Revisión y aprobación de comercios | Moderar `visibilityStatus: review_pending` | P1 |
| Listado de comercios activos | Vista de gestión de plataforma | P2 |
| Moderación de contenido reportado | Revisar señales reportadas | P1 |

---

## 3. Funcionalidades explícitamente fuera del MVP

| Feature | Razón |
|---------|-------|
| Sistema de propuestas y votos | Complejidad de moderación; Post-MVP |
| Reputación y rankings | Requiere volumen de datos; Post-MVP |
| Promociones patrocinadas | Modelo de negocio a definir post-lanzamiento |
| Carga masiva de productos | Operacional; no crítico para piloto |
| Verificación avanzada de owners | Proceso manual por soporte en MVP |
| Links compartibles de comercio | MVP+ si entra tiempo |
| Onboarding CUSTOMER | Flujo de registro simplificado; nice-to-have |
| Notificaciones push activas | Infraestructura lista (FCM); activación post-piloto |

---

## 4. Criterios de aceptación por módulo

### Registro de comercio (OWNER)
- [ ] El owner puede completar el flujo en < 5 minutos en condiciones normales
- [ ] El formulario valida nombre, categoría y dirección antes de avanzar
- [ ] La dirección usa autocomplete con Google Places
- [ ] La zona se asigna automáticamente por geocoding
- [ ] Los horarios son opcionales (skip con "Completar después")
- [ ] El comercio queda en `review_pending` hasta aprobación manual
- [ ] Si el registro se interrumpe, el borrador se conserva 72 h
- [ ] El sistema detecta y maneja duplicados (soft warning / hard block)

### Ficha pública de comercio (CUSTOMER)
- [ ] Muestra nombre, categoría, dirección, zona, horarios semanales
- [ ] Muestra señales operativas activas con antigüedad del dato
- [ ] Muestra `isOpenNow` calculado en tiempo real
- [ ] Muestra `isOnDutyToday` para farmacias
- [ ] Muestra listado de productos si hay al menos 1 cargado

### Búsqueda
- [ ] El usuario puede buscar por nombre de comercio
- [ ] El usuario puede filtrar por categoría
- [ ] El resultado incluye distancia estimada al comercio

### Farmacias de turno
- [ ] Vista dedicada que lista las farmacias con `isOnDutyToday: true`
- [ ] Muestra horario de guardia del día
- [ ] Fallback claro si no hay datos de turno para ese día

### Señales operativas
- [ ] El owner puede activar/desactivar señales desde su panel
- [ ] Las señales se reflejan en la ficha pública en < 5 minutos
- [ ] Las señales tienen timestamp de última actualización visible para el CUSTOMER

---

## 5. Requisitos no funcionales

| Requisito | Criterio |
|-----------|---------|
| Performance | Listado de comercios carga en < 2 s en red 4G |
| Offline | La app muestra datos cacheados si se pierde la conexión; no rompe |
| Seguridad | Firestore Rules impiden que un owner edite datos de otro comercio |
| Disponibilidad | Firebase SLA: > 99.9 % uptime para Firestore y Auth |
| Escalabilidad | Los agregados públicos soportan hasta 10.000 comercios sin degradación |

---

## 6. Stack de MVP

Ver `docs/ARCHITECTURE.md` para el stack completo.

Resumen:
- Mobile: Flutter (iOS + Android)
- Web pública: Flutter Web o web dedicada
- Backend: Firebase (Auth, Firestore, Cloud Functions, Storage)

---

## 7. Supuestos del MVP

1. El piloto inicia en una zona geográfica acotada de CABA.
2. El volumen inicial de comercios es de 50–200 comercios registrados.
3. La aprobación de comercios es manual por el equipo de TuM2 en MVP.
4. No hay monetización en MVP — el foco es validación de uso.
5. Los owners del piloto son captados proactivamente por el equipo de TuM2.

---

## 8. Dependencias críticas

| Dependencia | Impacto si falla |
|-------------|-----------------|
| Google Places API | Sin autocomplete de dirección en el registro OWNER |
| Firebase Firestore | Sin base de datos operativa |
| Firebase Auth | Sin sistema de sesión y roles |
| Cloud Functions | Sin campos derivados (`isOpenNow`, `isOnDutyToday`) |

---

*Documento mantenido bajo TuM2-0006. Actualizar ante cambios en el alcance del MVP o incorporación de nuevas features al scope.*
