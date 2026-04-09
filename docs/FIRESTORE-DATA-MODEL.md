# TuM2 — Modelo de datos Firestore

Documento de referencia del modelo lógico de datos de TuM2 sobre Firestore.
Cubre el MVP completo y deja guardrails explícitos para V1/V2/V3.

---

## Principios de diseño

1. **Espacio público único** — toda la experiencia pública se resuelve desde un conjunto central de entidades, sin duplicar modelos para mobile/web.
2. **Separación dato público / dato operativo** — el dato visible al usuario no se mezcla con logs, auditoría o colas de moderación.
3. **Scoring persistido** — el `confidenceScore` no se calcula solo al vuelo: se persiste, se versiona y alimenta ranking, badges y moderación.
4. **Versionado explícito** — toda entidad crítica permite historial.
5. **Evolución controlada** — el modelo deja lugar para staff, gamificación y disputas sin obligar a implementarlos ahora.

---

## Estrategia Firestore

**Colecciones top-level** por entidad principal, con subcolecciones para mensajes, historial y catálogos.

| Opción | Estado |
|--------|--------|
| Firestore puro | ✅ Recomendada — auth + realtime + reglas + bajo costo en MVP |
| Supabase / Postgres | ❌ Suma fricción sin ventaja decisiva para TuM2 en este momento |
| PostgreSQL propio | ❌ Demasiado peso operativo |

---

## Colecciones del MVP

### 1. `users/{userId}`

Identidad base del sistema. El `role` es controlado server-side.

| Campo | Tipo | Notas |
|-------|------|-------|
| `id` | string | UID de Firebase Auth |
| `email` | string | |
| `displayName` | string | Nombre visible |
| `username` | string \| null | Handle único |
| `role` | UserRole | customer / owner / moderator / admin / super_admin |
| `status` | UserStatus | active / pending / blocked |
| `trustScore` | number | 0–100, alimenta scoring comunitario |
| `trustLevel` | TrustLevel | new / contributor / trusted / verified |
| `gamificationEnabled` | boolean | Activado en V1.1+ |
| `isVerified` | boolean | |
| `primaryLocality` | string \| null | Ej: "Carlos Spegazzini" |
| `party` | string \| null | Ej: "Ezeiza" |
| `province` | string \| null | Ej: "Buenos Aires" |

**Subcolecciones:** `users/{userId}/favorites/{merchantId}`

---

### 2. `merchants/{merchantId}`

Entidad canónica de un comercio local. **No usar para lecturas públicas directas** — usar `merchant_public` en su lugar.

| Campo | Tipo | Notas |
|-------|------|-------|
| `name` | string | |
| `normalizedName` | string | Para búsqueda |
| `slug` | string \| null | URL-friendly |
| `categoryId` | string | |
| `ownershipStatus` | MerchantOwnershipStatus | unclaimed / claimed / disputed / restricted |
| `ownerDisplay` | OwnerDisplay \| null | Snapshot { userId, username, displayName } — solo si claimed |
| `confidenceScore` | number | 0–100, escrito solo por Cloud Functions |
| `confidenceLevel` | ConfidenceLevel | verified / community\_trusted / pending / under\_review |
| `badge` | string \| null | Label público del badge |
| `chatEnabled` | boolean | true solo si ownershipStatus = claimed |
| `status` | MerchantStatus | draft / pending\_review / active / inactive / archived / blocked |

**Campos mínimos para `visibilityStatus = 'visible'`:**
- `name`, `categoryId`, `zoneId`, `primaryLocation.lat/lng`
- `verificationStatus >= 'referential'`
- `status` not `inactive | archived | blocked`

**Subcolecciones relacionadas:**
- `merchant_schedules/{merchantId}` (doc separado, más limpio que embedded)
- `merchant_operational_signals/{merchantId}` (un doc con todas las señales, más eficiente que por señal)
- `merchant_products/{productId}` (top-level con merchantId, más flexible para queries cross-merchant)

---

### 3. `merchant_public/{merchantId}`

Vista desnormalizada de lectura pública. **Solo escrita por Cloud Functions.**

Campos clave: `isOpenNow`, `badges`, `sortBoost`, `searchKeywords`, `confidenceScore`, `hasPharmacyDutyToday`.

---

### 4. `merchant_schedules/{merchantId}`

Horario operativo. Un documento por merchant.

Campos clave: `weeklySchedule` (WeeklySchedule por día), `exceptions` (cierres/aperturas especiales), `timezone`.

**Precedencia para isOpenNow:**
1. `manualOpenOverride` (en merchant_operational_signals)
2. Turno/guardia especial
3. Cálculo por horario semanal

---

### 5. `merchant_operational_signals/{merchantId}`

Estado operativo en tiempo real. Un documento con todas las señales.

Tipos de señales MVP: `open_now`, `is_24h`, `on_duty`, `supports_orders`
Tipos V1.1+: `delivery`, `pickup`, `saturation_level`

---

### 6. `pharmacy_duties/{dutyId}`

Capa de turno/guardia para farmacias. Separada de `merchants` para no contaminar el modelo base con lógica temporal específica.

| Campo | Tipo | Notas |
|-------|------|-------|
| `merchantId` | string | FK a merchants |
| `zoneId` | string | Resuelto server-side desde merchant |
| `date` | string | YYYY-MM-DD |
| `startsAt` | timestamp | Inicio del turno |
| `endsAt` | timestamp | Fin del turno (puede cruzar medianoche) |
| `status` | PharmacyDutyStatus | draft / published / cancelled |
| `sourceType` | string | owner_created / admin_created / external_seed |
| `createdBy` | string | uid creador |
| `updatedBy` | string | uid último editor |
| `createdAt` | timestamp | serverTimestamp |
| `updatedAt` | timestamp | serverTimestamp |
| `notes` | string? | opcional |

**Escritura:** solo mediante Cloud Functions callables (`upsertPharmacyDuty`, `changePharmacyDutyStatus`) para ownership, conflicto y auditoría.

**Query pública típica:** comercios categoría farmacia cercanos → cruzar con `pharmacy_duties` `status=published` para priorizar turno vigente.

---

### 7. `merchant_products/{productId}`

Catálogo básico por comercio. Top-level con `merchantId` para queries cross-merchant.

Campos obligatorios mínimos: `name`, `availability`, `isPublished`
Campos de alta calidad: + `categoryId`, `referencePrice`, `stockStatus`, `images`

---

### 8. `merchant_claims/{claimId}`

Solicitudes de ownership. Solo rol owner en MVP. Staff y disputas complejas para V1.

| Estado | Descripción |
|--------|-------------|
| `pending` | Esperando revisión |
| `approved` | Aprobado — activa ownerDisplay y chatEnabled |
| `rejected` | Rechazado |
| `disputed` | Preparado para V1, no implementado |
| `cancelled` | Preparado para V1, no implementado |

---

### 9. `contributions/{contributionId}`

Contribuciones comunitarias. Separadas de reports (acción correctiva vs señal de problema).

**Reglas de auto-publicación (semi_auto):**

Solo aplicable si:
- el campo es de bajo riesgo
- el usuario no está penalizado (trustScore > umbral)
- no contradice un dato verificado reciente
- tiene evidencia adjunta

Nunca auto-aplicable en MVP:
- ownership, nombre, categoría principal
- farmacia de turno sin soporte
- cierre definitivo, datos sensibles conflictivos

---

### 10. `reports/{reportId}`

Reportes de información incorrecta o abusiva.

Tipos MVP: `incorrect_information`, `wrong_schedule`, `wrong_phone`, `wrong_address`, `closed_now`, `closed_permanently`, `not_on_duty`, `wrong_duty`, `duplicate`, `abusive_content`

---

### 11. `conversations/{conversationId}`

Chat 1 a 1 usuario ↔ dueño. **Solo existe si `merchant.chatEnabled = true`.**

- `participantIds: [userId, ownerUserId]` — para queries `array-contains`
- Subcolección: `conversations/{conversationId}/messages/{messageId}`
- Colección privada: nunca accesible sin autenticación

---

### 12. `users/{userId}/favorites/{merchantId}`

Subcolección simple. El ID del documento es el `merchantId` para lookups O(1).
El contador global se mantiene en `merchants.favoritesCount` via Cloud Functions.

---

### 13. `feedback/{feedbackId}`

Feedback in-app mínimo. Sin threading ni respuestas visibles al usuario.

---

### 14. `categories/{categoryId}` / `subcategories/{subcategoryId}`

Categorías core MVP: `pharmacy`, `veterinary`, `grocery`, `supermarket`, `prepared_food`, `fast_food`, `tire_shop`

---

### 15. `moderation_queue/{itemId}`

Cola explícita de moderación para el panel admin. Creada automáticamente por Cloud Functions.

---

### 16. `audit_logs/{logId}`

Auditoría general top-level. Solo accesible por admin/moderador.
**Escrito exclusivamente por Cloud Functions y backend admin.**

---

### 17. `entity_versions/{versionId}`

Historial de versiones de entidades críticas: `merchant`, `merchant_claim`, `pharmacy_duty`, `catalog_item`.

**Política:**
- Snapshot parcial para cambios menores
- Snapshot completo en hitos críticos (primera publicación, aprobación de claim, cambio de status)

---

## Sistema de scoring y confianza

### Escala ConfidenceLevel

| Score | Nivel | Badge público |
|-------|-------|---------------|
| 80–100 | `verified` | Verificado |
| 60–79 | `community_trusted` | Comunidad confiable |
| 30–59 | `pending` | Pendiente |
| 0–29 | `under_review` | En revisión |

### Factores que suman
- Alta/admin manual
- Ownership aprobado
- Evidencia válida
- Consistencia histórica
- Actualizaciones recientes
- Comunidad confiable

### Factores que restan
- Reportes repetidos
- Contradicción con dato reciente verificado
- Baja recencia
- Múltiples rechazos
- Disputa abierta

### Entidades con scoring
`merchants`, `pharmacy_duties`, `merchant_operational_signals`, `contributions`

---

## Campos públicos vs privados

### Públicos
- Nombre, categoría, dirección, localidad/partido/provincia
- Teléfono/WhatsApp si aplica
- Horarios, señales operativas públicas
- Badge y confidenceLevel
- ownerDisplay (username + displayName)
- Catálogo publicado, farmacia de turno
- Imágenes públicas

### Privados (nunca exponer)
- Email del owner
- Evidencia de reclamo
- Audit logs
- Moderation queue
- Metadata interna de scoring
- Datos raw del chat
- Notas internas admin
- Reportes sin resolver en detalle completo

---

## Relaciones principales

```
users/{userId}
  └── favorites/{merchantId}

merchants/{merchantId}
  ├── ownerUserId → users/{userId}
  ├── ownerDisplay (snapshot denormalizado)
  ├── merchant_schedules/{merchantId}
  ├── merchant_operational_signals/{merchantId}
  └── merchant_products/{productId}  (top-level con merchantId)

pharmacy_duties/{dutyId}
  └── merchantId → merchants/{merchantId}

conversations/{conversationId}
  ├── merchantId → merchants/{merchantId}
  ├── userId → users/{userId}
  ├── ownerUserId → users/{userId}
  └── messages/{messageId}

contributions/{contributionId}
  └── targetId → merchants/{merchantId} | pharmacy_duties/{dutyId}

reports/{reportId}
  └── targetId → merchants/{merchantId} | pharmacy_duties/{dutyId}

merchant_claims/{claimId}
  └── merchantId → merchants/{merchantId}

entity_versions/{versionId}
  └── entityId → merchants/{merchantId} | merchant_claims | pharmacy_duties

audit_logs/{logId}
  └── entityId → cualquier entidad auditada
```

---

## Índices recomendados

### `merchants`
- `status + categoryId + locality`
- `status + categoryId + confidenceScore desc`
- `status + isOpenNow + locality`
- `status + isOnDuty + locality`
- `status + ownerUserId`
- `status + geohash` (estrategia de proximidad)

### `pharmacy_duties`
- `status + date`
- `status + startsAt`
- `merchantId + status`

### `merchant_products`
- `merchantId + isPublished + normalizedName`
- `merchantId + availability + isPublished`

### `contributions`
- `targetId + status`
- `submittedByUserId + status`
- `contributionType + status`

### `conversations`
- `participantIds array-contains + updatedAt desc`

---

## Guardrails por versión

### MVP — implementar
- Todas las colecciones listadas arriba
- scoring básico persistido
- versionado parcial en hitos críticos
- chat solo si ownershipStatus = claimed

### MVP — preparado pero NO implementar
- `commerce_staff` (subcolección de personal por comercio)
- disputas complejas de ownership
- gamificación visible avanzada
- proposals/voting
- catálogo maestro global

### V1.1
- Puntos y badges comunitarios básicos
- Ranking de colaboradores mínimo
- `delivery` / `pickup` como señales operativas
- Staff funcional

### V2
- Ownership disputes completas
- Catálogo más completo
- Automatización mayor de scoring
- Reglas sofisticadas de confianza

### V3
- Monetización y transacciones
- Features avanzadas comunitarias
- Marketplace

---

## Cloud Functions recomendadas

| Función | Trigger |
|---------|---------|
| Recalcular `confidenceScore` | Write en contributions / reports / claims |
| Recalcular `isOpenNow` / `isOnDuty` | Write en schedules / signals / pharmacy_duties |
| Sincronizar badge | Write en confidenceScore |
| Crear audit/version snapshot | Write en merchants / claims / pharmacy_duties |
| Activar/desactivar `chatEnabled` | Aprobación de merchant_claim |
| Construir `merchant_public` | Write en merchants / signals / schedules |

---

## Decisiones de modelado cerradas

| Decisión | Resolución |
|----------|-----------|
| Naming de colección | `merchants` (no `commerces`) |
| Turnos de farmacia | `pharmacy_duties` (no `pharmacy_turns`) |
| Catálogo | `merchant_products` top-level (no subcolección) |
| Señales | `merchant_operational_signals` doc único (no por señal) |
| Horarios | `merchant_schedules` doc separado (no embedded) |
| Owner visible | snapshot `ownerDisplay` en merchant (no join) |
| Auditoría | `audit_logs` top-level (no subcolecciones dispersas) |
| Archive vs delete | Siempre archive con `archivedAt` |
| Chat | Solo si ownershipStatus = claimed + chatEnabled = true |
| Scoring | Persistido en modelo, no calculado solo al vuelo |
