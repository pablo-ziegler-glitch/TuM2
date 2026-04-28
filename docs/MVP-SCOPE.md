# MVP-SCOPE.md — Alcance real del MVP de TuM2

> Tarjeta TuM2-0003 — Estado: ✅ CONGELADO
> Última actualización: 2026-03-24

---

## Objetivo

Definir, documentar y congelar el alcance real del MVP de TuM2, asegurando:

- Foco en utilidad inmediata (< 3–5s a resultado útil)
- Cobertura profunda en una zona acotada (Ezeiza / Spegazzini)
- Diferenciación basada en señales + confianza + proximidad
- Base técnica y de datos escalable sin sobreingeniería
- Evitar explícitamente el scope creep

---

## Regla clave

> **Tiempo al primer resultado útil < 3 segundos (máximo 5)**

---

## User stories

### Usuario final
Como usuario, quiero encontrar rápidamente comercios o farmacias de turno cercanas y confiables, con información actualizada, para resolver una necesidad inmediata.

### Comercio
Como dueño, quiero reclamar mi negocio y mantenerlo actualizado para que los usuarios encuentren información correcta.

### Administrador
Como operador, quiero validar y moderar información para garantizar calidad sin frenar la escalabilidad.

---

## ✅ IN (MVP 1)

### Búsqueda y descubrimiento
- Búsqueda por: comercio, categoría, producto (catálogo básico), farmacia de turno
- Ranking por: cercanía, confianza, estado operativo
- Mapa solo como apoyo visual (NO core)

### Farmacias de turno (vertical core)
- Listado prioritario en home
- Ficha con: nombre, dirección, geolocalización, teléfono, horarios, cómo llegar, estado de turno, última validación, nivel de confianza, distancia estimada
- Doble capa: comercio general + estado "de turno"

### Ficha de comercio
- Nombre, ubicación, teléfono / WhatsApp, horarios, señales operativas, imágenes, medios de pago, estado de verificación, nivel de confianza, quién reclamó el negocio

### Catálogo básico por comercio
- Carga manual simple
- Pocos productos
- Opcional (no obligatorio)
- Usado para mejorar búsqueda

### Señales operativas (MUST)
- Abierto ahora
- 24 hs
- Guardia
- Recibe pedidos

> **Regla:** manual override > cálculo automático

### Sistema de confianza (core diferencial)
Modelo con:
- `confidenceScore`
- `confidenceLevel`
- `verificationStatus`

Badges visibles:
- Verificado
- Comunidad confiable
- Pendiente
- En revisión

### Comunidad
- Sugerir comercio (con evidencia)
- Sugerir ediciones
- Reportar errores
- Votar contribuciones

Moderación (modelo semi-automático B):
- Cambios menores → auto
- Cambios críticos → admin

### Chat interno
- Solo si comercio reclamado
- 1 a 1
- Asincrónico
- Con notificaciones
- Sin multimedia compleja

### Owner (mobile)
- Reclamar ficha
- Editar datos básicos
- Cargar horarios
- Marcar abierto / cerrado
- Responder reportes
- Chat

### Admin / BO (web)
- Moderación
- Carga manual y masiva
- Versionado
- Auditoría
- Gestión de farmacias
- Analytics

### Feedback
- Botón simple
- Sin sistema de propuestas votables

### Roles
- Visitante
- Usuario
- Comercio (usuario con permisos)
- Admin
- Moderador

Login requerido para: chat, contribuciones, acciones de owner
Guest-first: home/búsqueda/mapa/fichas públicas y farmacias de turno disponibles sin sesión; onboarding CUSTOMER persiste localmente en `SharedPreferences` (`onboarding_seen`).

---

## ❌ OUT (bloqueado explícitamente)

- Marketplace transaccional
- Pagos (MercadoPago, etc.)
- Cupones / promociones
- IA conversacional
- Mapa como experiencia principal
- Catálogo masivo completo
- Logística / delivery
- Reseñas / opiniones
- Gamificación avanzada
- Propuestas votables
- Integraciones pagas intensivas (Google Places full)

---

## ⚠️ SHOULD (MVP 1.1)

- Gamificación mínima: puntos, badges
- Mejoras en chat
- Mejoras owner
- Señales adicionales: entrega, retiro

---

## Roadmap

| Versión | Contenido |
|---|---|
| **MVP 1** | Búsqueda funcional, farmacias de turno, fichas, confianza, comunidad básica, chat básico, owner básico, admin BO |
| **MVP 1.1** | Gamificación mínima, mejoras UX, mejoras señales |
| **V2** | Catálogo más robusto, propuestas votables, automatización moderación |
| **V3** | Monetización, transaccional, IA, expansión geográfica |

---

## Supuestos

- Zona inicial acotada → alta calidad
- Operación manual inicial viable
- Comunidad aporta valor progresivo
- Confianza > volumen

---

## Checklist técnico

- [ ] Colecciones mínimas definidas: `commerces`, `pharmacies`, `signals`, `contributions`, `users`
- [ ] Sistema de scoring persistido
- [ ] Versionado activo
- [ ] Override manual de señales
- [ ] Search optimizada (no full-text complejo)
- [ ] Reglas Firestore con tenant + roles
- [ ] Cloud Functions mínimas: recalcular confianza, normalizar datos
- [ ] Caché de resultados

---

## Checklist UX

- [ ] Resultado útil en < 3s
- [ ] Home con pre-búsqueda
- [ ] Placeholders claros ("Farmacia", "Algo abierto…")
- [ ] Badges visibles
- [ ] No sobrecarga de filtros
- [ ] Mapa secundario
- [ ] Lenguaje estándar

---

## Datos impactados

- Comercios
- Farmacias
- Señales
- Contribuciones
- Usuarios
- Ownership
- Historial / versiones
- Confianza / scoring

---

## APIs / Servicios

| Estado | Servicio |
|---|---|
| ✅ Permitido | Geolocalización básica |
| ✅ Permitido | Mapas (solo navegación) |
| ✅ Permitido | Storage imágenes |
| ✅ Permitido | Auth |
| ✅ Permitido | Notificaciones |
| ❌ Bloqueado | Pagos |
| ❌ Bloqueado | APIs pagas intensivas |
| ❌ Bloqueado | IA avanzada |

---

## Criterios BDD

**Búsqueda**
```
Given un usuario sin login
When busca "farmacia"
Then ve farmacias cercanas en menos de 3 segundos
```

**Farmacia de turno**
```
Given una farmacia marcada como de turno
When el usuario entra
Then ve dirección, contacto y cómo llegar
```

**Reclamo**
```
Given un comercio existente
When un usuario lo reclama
Then puede editarlo tras validación
```

**Chat**
```
Given un comercio reclamado
When un usuario logueado entra a la ficha
Then puede iniciar chat
```

**Comunidad**
```
Given una sugerencia con evidencia
When cumple requisitos
Then se publica o entra a revisión
```

---

## Analytics

**North Star:** % de sesiones con acción útil en < 3 min

**Eventos clave:**
- Búsqueda realizada
- CTR a ficha
- Clic en WhatsApp / Llamar / Cómo llegar
- Farmacia vista
- Contribución enviada
- Comercio reclamado
- Tiempo a primer resultado útil
- Frescura de datos

---

## Riesgos

| Riesgo | Tipo |
|---|---|
| Baja diferenciación | Producto |
| Datos desactualizados | Operativo |
| Sobrecarga operativa | Operativo |
| UX confusa | UX |

### Edge cases
- Farmacia cerrada reportada
- Comercio duplicado
- Conflicto de ownership (futuro "careo")
- Datos contradictorios
- Abuso de contribuciones

---

## QA

- Test de búsqueda en < 3s
- Consistencia de scoring
- Validación de señales
- Flujo de reclamo
- Moderación
- Fallback sin datos

---

## Definición de Done

- Scope congelado ✅
- MUST implementado
- Métricas instrumentadas
- BO operativo
- Datos iniciales cargados
- UX validada en campo

---

## Plan de rollout

| Fase | Acciones |
|---|---|
| **Fase 1** | Carga manual intensiva, farmacias de turno correctas, testing interno |
| **Fase 2** | Apertura controlada (zona), monitoreo métricas |
| **Fase 3** | Activación comunidad, optimización UX |

---

## Guardrails (CRÍTICO)

**NO hacer sin revalidar:**
- Pagos
- Marketplace
- IA
- Catálogo masivo complejo
- Features sociales complejas
- Sobrecargar UX

---

## Decisiones clave cerradas

| Decisión | Resolución |
|---|---|
| Mapa | NO es core — solo apoyo visual |
| Vertical principal | Farmacias de turno |
| Núcleo del sistema | Confianza |
| Moderación | Comunidad moderada (semi-automática) |
| Catálogo | Básico, opcional |
| Chat | Limitado (solo con comercio reclamado, asincrónico) |
| Plataforma | Mobile-first + Web BO |

---

## Decisiones abiertas (futuro)

- Resolución de disputas de ownership
- Gamificación avanzada
- Catálogo global
- Monetización
