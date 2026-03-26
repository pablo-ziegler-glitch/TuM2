# TuM2 — Segmentos principales v1

Definición, permisos, ciclo de vida y journeys base de los tres segmentos de TuM2: CUSTOMER, OWNER y ADMIN.

**Derivado de:** TuM2-0004 · Bloqueante fundacional
**Dependencias resueltas:** TuM2-0001 ✅ · TuM2-0003 ✅
**Impacta:** TuM2-0027 · TuM2-0028 · TuM2-0030 · TuM2-0044 · TuM2-0045 · TuM2-0046

---

## 1. Decisiones de diseño cerradas

- **Rol compuesto OWNER ⊃ CUSTOMER:** un OWNER mantiene todas las capacidades de CUSTOMER más el acceso a su panel operativo. No hay cambio de sesión ni switch de contexto.
- **Asignación provisional de OWNER:** el rol `owner_pending` se asigna al completar el onboarding. El custom claim pasa a `owner` solo tras aprobación del ADMIN.
- **Comercios unclaimed:** un comercio puede existir sin `ownerUserId` asignado (especialmente los generados por bootstrap de Google Places).
- **Contribuciones anónimas:** un CUSTOMER anónimo puede sugerir un comercio y reportar uno existente. Toda contribución anónima nace con `verificationStatus = community_submitted` y requiere revisión.
- **Admin / super_admin:** la diferenciación existe en el schema y en las Firestore Rules, pero `super_admin` no se implementa funcionalmente en UI hasta Post-MVP.
- **Claim de comercio existente:** si un OWNER intenta registrar un comercio ya existente, se le muestra el registro y puede reclamarlo vía claim flow.
- **Un owner = un comercio en MVP:** un usuario con rol `owner` o `owner_pending` no puede iniciar el onboarding de un segundo comercio.

---

## 2. Custom claims de Firebase Auth

| Valor de `role` | Descripción |
|----------------|-------------|
| `customer` | Vecino registrado (default tras registro) |
| `owner_pending` | Owner durante revisión admin |
| `owner` | Owner confirmado (comercio aprobado) |
| `admin` | Operador del equipo TuM2 |
| `super_admin` | Acceso a `admin_configs` (preparado, inactivo en UI) |

**Regla crítica de seguridad:** ninguna transición de rol se realiza desde el cliente. Todas las actualizaciones de custom claims ocurren en Cloud Functions del lado servidor, con validación de identidad del llamador.

El `idToken` incluye el claim `role`. El cliente lo decodifica para routing. **La autorización real está en Firestore Rules y Cloud Functions, nunca solo en el cliente.**

---

## 3. Segmento CUSTOMER

### 3.1 Definición

| Campo | Valor |
|-------|-------|
| Custom claim | `role = "customer"` |
| Autenticación | No requerida para lectura pública · Requerida para favoritos, seguir, reportar (autenticado), sugerir (autenticado) |
| Superficies | CustomerTabs: Inicio · Buscar · Perfil |
| Entry | AUTH-01 (splash) → AUTH-02 (onboarding) → HOME-01 |

### 3.2 Capacidades

| Acción | Sin cuenta | Con cuenta |
|--------|-----------|------------|
| Ver feed de comercios | ✅ | ✅ |
| Ver ficha de comercio | ✅ | ✅ |
| Ver farmacias de turno | ✅ | ✅ |
| Sugerir comercio | ✅ (trust bajo) | ✅ (trust `community_submitted`) |
| Reportar comercio | ✅ | ✅ |
| Guardar favoritos | ❌ | ✅ |
| Seguir comercio | ❌ | ✅ |

### 3.3 Restricciones

- **Campos mutables en `users/{uid}`:** `displayName`, `photoURL`, `notificationPreferences`
- **Campos prohibidos:** `role`, `createdAt`, `merchantId`
- Un CUSTOMER anónimo que intenta guardar favoritos es redirigido a login con mensaje contextual (no bloqueado abruptamente).
- Contribución anónima: `createdBy = "anonymous"` + `ipHash` (no IP raw). Rate limiting: máximo 5 por IP por hora.

---

## 4. Segmento OWNER

### 4.1 Definición

| Campo | Valor |
|-------|-------|
| Custom claim final | `role = "owner"` |
| Custom claim provisional | `role = "owner_pending"` (durante revisión admin) |
| Rol compuesto | OWNER ⊃ CUSTOMER: mantiene todas las capacidades de CUSTOMER |
| Entry al panel | PROFILE-01 → botón "Ir a mi comercio" → OwnerStack modal (OWNER-01) |
| Guard de navegación | `role = owner` ó `owner_pending` → muestra botón en PROFILE-01 · `role = customer` → botón oculto |

### 4.2 Estado provisional (owner_pending)

Durante la revisión del ADMIN:
- El owner ve su panel en modo "Tu comercio está en revisión".
- No puede editar campos críticos del comercio.
- El comercio tiene `visibilityStatus = review_pending` (no visible al público).
- El banner de revisión tiene CTA de contacto/soporte y tiempo estimado de respuesta (SLA 48h).

### 4.3 Capacidades

| Colección | Operaciones |
|-----------|------------|
| `merchants` | Read + Write su propio comercio (campos no protegidos) |
| `merchant_schedules` | Read + Write su propio comercio |
| `merchant_operational_signals` | Read + Write su propio comercio |
| `merchant_products` | Read + Write su propio comercio |
| `pharmacy_duties` | Write solo si `categoryId = pharmacy` |

### 4.4 Restricciones

**Campos inmutables desde cliente (owner):**
- `verificationStatus`
- `visibilityStatus`
- `sortBoost`
- `sourceType`
- `ownerUserId` (no puede reasignar)

### 4.5 Comercio unclaimed y claim flow

Si el comercio ya existe en el sistema con `isClaimable = true`:
1. El DuplicateCheckService detecta la coincidencia en Step 1 del onboarding.
2. Se muestra la pantalla de claim: "Este comercio ya está en TuM2 — ¿sos el dueño?"
3. El usuario puede elegir "Soy el dueño — reclamar" o "No es mi comercio — crear uno nuevo".
4. Si elige reclamar: se crea `merchant_claims/{id}` con `status = pending`.
5. El usuario ve confirmación de que el reclamo fue enviado.
6. El ADMIN ve el claim en su cola de revisión.

---

## 5. Segmento ADMIN

### 5.1 Definición

| Campo | Valor |
|-------|-------|
| Custom claim | `role = "admin"` (MVP) · `"super_admin"` (preparado, inactivo en UI) |
| Asignación | Manual: Firebase Console o CF restringida · **Nunca auto-asignado** |
| Superficies | AdminStack modal (web panel Flutter Web) + AdminStack mobile · CustomerTabs también disponible |
| Entry | Post-login → si `role = admin` → AppNavigator + acceso a `/admin` route |

### 5.2 Capacidades exclusivas

- Aprobar/rechazar comercios
- Validar claims de ownership
- Gestionar bootstrap Google Places
- Gestionar `pharmacy_duties`
- Leer todos los reportes
- Gestionar `admin_configs` (solo `super_admin` puede escribir)

### 5.3 Diferencia admin vs super_admin en Firestore Rules

| Colección | admin | super_admin |
|-----------|-------|-------------|
| Todas excepto `admin_configs` | R+W | R+W |
| `admin_configs/global` | Solo lectura | R+W |

### 5.4 Restricciones

- No puede modificar custom claims de usuarios sin usar CF específica.
- No puede acceder a datos de terceros sin reporte activo.

---

## 6. Ciclo de vida de roles y estados

| Evento | Transición de rol / estado |
|--------|---------------------------|
| Registro inicial | `role = customer` |
| Inicia onboarding Owner | `merchants/{id}` creado con `visibilityStatus = review_pending` · `role` sigue siendo `customer` |
| Submit onboarding completado | `merchants/{id}.status = draft → submitted` · `role = owner_pending` |
| ADMIN aprueba comercio | CF: `role = owner` · `merchants.verificationStatus = validated` · `visibilityStatus = visible` |
| ADMIN rechaza | `role` vuelve a `customer` · `merchants.visibilityStatus = suppressed` · notificación al usuario |
| ADMIN asigna admin | Manual Firebase Console o CF restringida · `role = admin` |
| ADMIN asigna super_admin | Manual Firebase Console únicamente · `role = super_admin` |

```
CUSTOMER
  │
  ├─ Completa onboarding ──→ owner_pending
  │                              │
  │                    ADMIN aprueba ──→ OWNER
  │                              │
  │                    ADMIN rechaza ──→ CUSTOMER (vuelve)
  │
  └─ Asignación manual ──→ ADMIN / super_admin
```

---

## 7. Matriz de permisos por colección Firestore

| Colección | Anónimo | CUSTOMER | OWNER | ADMIN | Notas clave |
|-----------|---------|----------|-------|-------|-------------|
| `merchant_public` | Read visible | Read visible | Read visible | Read all | Write solo CF |
| `merchants` | ❌ | Create suggest. | Read+Write own | Read+Write all | Owner = ownerUserId |
| `merchant_schedules` | ❌ | ❌ | R+W own | R+W all | |
| `merchant_operational_signals` | ❌ | ❌ | R+W own | R+W all | |
| `merchant_products` | ❌ | Read visible | R+W own | R+W all | |
| `pharmacy_duties` | Read published | Read published | Write si farmacia propia | R+W all | |
| `reports` | Create | Create | Create | R+W all | Auth requerida para Customer con cuenta |
| `merchant_claims` | ❌ | Create own | Create own | R+W all | |
| `zones` | Read público | Read | Read | R+W all | |
| `external_places` | ❌ | ❌ | ❌ | R+W all | Solo pipeline admin |
| `admin_configs` | ❌ | ❌ | ❌ | R (super_admin R+W) | Feature flags |
| `users` | ❌ | R+W propio (no rol) | R+W propio (no rol) | R+W all | Custom claim no editable desde cliente |

### Notas de implementación críticas

- **`merchant_public`:** escritura SOLO desde Cloud Functions. Nunca desde cliente.
- **`merchants`:** campos sensibles (`verificationStatus`, `visibilityStatus`, `sortBoost`, `sourceType`) son inmutables desde cliente. Las transiciones de estado van por CF callable.
- **`reports` anónimos:** `createdBy = "anonymous"` + `ipHash` (no IP raw). Rate limiting por IP en CF.
- **`merchant_claims`:** solo usuarios autenticados. El claim anónimo no existe — para reclamar hay que tener cuenta.
- **Consistencia:** `ownerUserId` en `merchants` debe coincidir con un `users/{uid}` con `role = owner` o `owner_pending`.

---

## 8. Sistema de confianza (verificationStatus)

| verificationStatus | sortBoost | Badge visible | Quién lo asigna |
|-------------------|-----------|---------------|-----------------|
| `verified` | 100 | Verificado ✅ | ADMIN manual |
| `validated` | 90 | Validado | ADMIN tras revisión |
| `claimed` | 80 | Reclamado | CF tras approve de claim |
| `referential` | 70 | (sin badge público) | Bootstrap Google Places |
| `community_submitted` | 40 | Pendiente revisión | Submit anónimo / customer |
| `unverified` | 20 | Sin verificar | Owner provisional sin confirmar |

### Reglas de degradación de confianza

- 3 reportes abiertos no resueltos en 7 días → `sortBoost` reducido en 15 puntos automáticamente (CF scheduled).
- Reporte validado por admin → puede bajar `verificationStatus` un nivel.
- Dato contradictorio con fuente `referential` (Google Places) → va a `review_pending` automático.

---

## 9. Campos impactados en Firestore

| Colección | Campos nuevos / modificados |
|-----------|-----------------------------|
| `users` | `role: string` · `merchantId: string \| null` · `onboardingOwnerProgress: map \| null` |
| `merchants` | `ownerUserId: string \| null` · `verificationStatus` (enum ampliado) · `isClaimable: bool` |
| `merchant_claims` | Colección completa: `claimId`, `userId`, `merchantId`, `status`, `evidenceType`, `reviewedBy`, etc. |
| `reports` | `createdBy: string \| "anonymous"` · `ipHash: string` (solo si anónimo) |
| `admin_configs/global` | `featureFlags.enableClaims` · `featureFlags.enableProposals` (super_admin write only) |

---

## 10. Cloud Functions requeridas

| Función | Tipo | Propósito |
|---------|------|-----------|
| `setOwnerRole(uid, merchantId)` | Callable | Valida merchant, actualiza custom claim a `owner` |
| `approveOwnerClaim(claimId)` | Callable admin | Transiciona claim a approved, actualiza custom claim, `verificationStatus` |
| `rejectOwnerClaim(claimId, reason)` | Callable admin | Rechaza claim, revierte rol a `customer`, suprime comercio |
| `submitAnonymousSuggestion(data)` | Callable | Crea `merchants/{id}` anónimo con sanitización y rate limiting |
| `onMerchantClaimApproved` | Trigger Firestore | Sincroniza `merchant_public` tras aprobación |
| `onReportThresholdExceeded` | Trigger + Scheduled | Reduce `sortBoost` si hay 3+ reportes sin resolver en 7 días |

### Validaciones de setOwnerRole

- `merchant` existe en Firestore.
- `ownerUserId` no está asignado o coincide con `uid`.
- `uid` está autenticado.
- El usuario no tiene ya un comercio activo (un owner = un comercio en MVP).

---

## 11. Edge cases documentados

- **Owner con comercio en review_pending intenta registrar un segundo comercio:** bloqueado con mensaje "Ya tenés un comercio en revisión. Un owner = un comercio en MVP."
- **CF setCustomClaim falla tras aprobación:** usuario queda en `owner_pending`. Retry automático cada 5 min por 1 hora. Alert al admin si persiste.
- **Comercio bootstrapeado de Google Places tiene mismo nombre normalizado + geohash que uno `community_submitted`:** se mantiene el `referential`, el `community_submitted` se marca como `merge_candidate` para revisión.
- **OWNER cambia su email en Firebase Auth:** custom claims se mantienen atados al `uid`, no al email. Sin impacto.
- **ADMIN elimina un comercio cuyo OWNER tiene claim activo:** CF notifica al owner, custom claim vuelve a `customer`, `merchants/{id}` archivado.
- **Usuario anónimo sugiere un comercio que ya existe (visible):** el sistema detecta duplicado y redirige al formulario de reporte, no crea un nuevo `merchants`.
- **OWNER intenta cargar `pharmacy_duties` sin `categoryId = pharmacy`:** Firestore Rules rechazan con `PERMISSION_DENIED`. La UI no debe mostrar esa opción (guard de UI en OWNER-09).
- **Token de custom claim expirado durante sesión activa:** la app Flutter debe forzar refresh del `idToken` antes de llamadas sensibles. Implementar token refresh middleware en el repositorio de auth.

---

## 12. Criterios de aceptación clave (BDD)

### Rol compuesto OWNER

```gherkin
Scenario: OWNER accede a su panel sin cerrar sesión
  Given un usuario autenticado con role = "owner" y merchantId asignado
  When navega a /profile (PROFILE-01)
  Then ve el botón "Ir a mi comercio"
  And puede navegar a /owner (OwnerStack modal) sin re-autenticarse
  And el tab bar de CustomerTabs sigue visible al volver del panel

Scenario: OWNER ve contenido público como CUSTOMER
  Given un usuario con role = "owner"
  When navega a HOME-01, SEARCH-01 o cualquier ficha pública
  Then ve exactamente el mismo contenido que un CUSTOMER
  And no ve datos privados de otros comercios
```

### Asignación provisional de rol OWNER

```gherkin
Scenario: rol provisional al completar onboarding
  Given un usuario con role = "customer" que completó los 4 pasos del onboarding
  When toca "Publicar mi comercio" en ONBOARDING-OWNER-04
  Then merchants/{id}.visibilityStatus = "review_pending"
  And el custom claim del usuario pasa a role = "owner_pending"
  And OWNER-01 muestra el estado "Tu comercio está en revisión"
  And el usuario NO puede editar campos críticos del comercio

Scenario: ADMIN aprueba el comercio
  Given un comercio con visibilityStatus = "review_pending"
  When el ADMIN aprueba desde el panel admin
  Then CF ejecuta: custom claim → "owner", verificationStatus → "validated", visibilityStatus → "visible"
  And el usuario recibe notificación FCM de aprobación
  And OWNER-01 muestra el estado operativo normal

Scenario: ADMIN rechaza el comercio
  Given un comercio en review_pending
  When el ADMIN rechaza con motivo
  Then el custom claim vuelve a "customer"
  And merchants.visibilityStatus → "suppressed"
  And el usuario recibe notificación con el motivo del rechazo
  And PROFILE-01 ya no muestra el botón "Ir a mi comercio"
```

### Restricciones de campos críticos

```gherkin
Scenario: OWNER no puede modificar campos protegidos
  Given un usuario con role = "owner" intentando escribir en merchants/{su_merchantId}
  When el payload incluye verificationStatus, visibilityStatus, sortBoost o sourceType
  Then Firestore rechaza la escritura con PERMISSION_DENIED
  And ningún campo del payload es aplicado parcialmente

Scenario: CUSTOMER no puede publicar un comercio como verified
  Given un usuario con role = "customer" creando un merchants/{id}
  When el payload incluye verificationStatus = "verified" o "validated"
  Then Firestore Rules rechazan la escritura
  And el comercio solo puede nacer con verificationStatus = "community_submitted"
```

### Rate limiting de contribuciones anónimas

```gherkin
Scenario: rate limiting de contribuciones anónimas
  Given un visitante anónimo que ya realizó 5 sugerencias en la última hora
  When intenta realizar una 6ta sugerencia
  Then la CF rechaza la request con error 429
  And el cliente muestra mensaje de "Demasiadas solicitudes, intentá más tarde"
```

---

## 13. Analytics a medir

| Evento | Propiedades clave |
|--------|-------------------|
| `segment_role_assigned` | `role`, `previousRole`, `source` (onboarding \| admin \| claim) |
| `onboarding_owner_submitted` | `step3Skipped`, `categoryId`, `zoneId`, `draftAgeMinutes` |
| `onboarding_owner_approved` | `merchantId`, `reviewDurationHours`, `adminId` |
| `onboarding_owner_rejected` | `merchantId`, `rejectReason`, `reviewDurationHours` |
| `claim_submitted` | `merchantId`, `evidenceType`, `existingVerificationStatus` |
| `claim_approved` | `merchantId`, `claimDurationHours` |
| `anonymous_suggestion_submitted` | `categoryId`, `zoneId`, `hasAddress`, `hasPhone` |
| `anonymous_report_submitted` | `merchantId`, `reportType`, `hasDescription` |
| `duplicate_detected_in_onboarding` | `matchScore`, `merchantId`, `userAction` (claim \| ignore \| new) |
| `permission_denied_attempt` | `collection`, `operation`, `role` |
