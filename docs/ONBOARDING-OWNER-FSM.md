# TuM2 — Onboarding OWNER: FSM y especificación de flujo
### Tarjeta: TuM2-0030-01

Documento técnico del flujo de registro de comercio. Define los estados, transiciones y reglas de navegación del onboarding multi-paso (DETAIL-03 / ONBOARDING-OWNER-01 a 04).

---

## 1. Diagrama de estados

```
                         ┌──────────────────────────────┐
                         │           idle               │
                         │  (owner detectado, no        │
                         │   ha iniciado el flujo)      │
                         └──────────┬───────────────────┘
                                    │ START
                                    ▼
                         ┌──────────────────────────────┐
                    ┌───►│          step_1              │◄─── RESUME (desde abandoned)
                    │    │  ONBOARDING-OWNER-01         │
                    │    │  Tipo y nombre del comercio  │
                    │    └──────────┬───────────────────┘
                    │               │ SAVE_STEP_1
                    │               ▼
                    │    ┌──────────────────────────────┐
                    │    │          step_2              │
          BACK ─────┤    │  ONBOARDING-OWNER-02         │
                    │    │  Dirección y zona            │
                    │    └──────────┬───────────────────┘
                    │               │ SAVE_STEP_2
                    │               ▼
                    │    ┌──────────────────────────────┐
                    │    │          step_3              │
          BACK ─────┤    │  ONBOARDING-OWNER-03         │
                    │    │  Horarios iniciales          │
                    │    └──────────┬───────────────────┘
                    │               │ SAVE_STEP_3 o SKIP_STEP_3
                    │               ▼
                    │    ┌──────────────────────────────┐
                    │    │        confirmation          │
          BACK ─────┘    │  ONBOARDING-OWNER-04         │
                         │  Resumen + activación        │
                         └──────────┬───────────────────┘
                                    │ SUBMIT
                                    ▼
                         ┌──────────────────────────────┐
                         │         submitted            │
                         │  merchants/{id} creado con   │
                         │  visibilityStatus:           │
                         │    review_pending            │
                         └──────────┬───────────────────┘
                                    │ APPROVE (Cloud Function o auto-approve)
                                    ▼
                         ┌──────────────────────────────┐
                         │         completed            │
                         │  visibilityStatus: visible   │
                         │  → redirige a OWNER-01       │
                         └──────────────────────────────┘

    Desde cualquier estado activo:
    EXIT_APP ──► abandoned (progreso guardado, retomable)
```

---

## 2. Tabla de estados

| Estado | Pantalla | Descripción |
|--------|----------|-------------|
| `idle` | AUTH-03 | Owner detectado por email en `pending_owners`, aún no inició el flujo |
| `step_1` | ONBOARDING-OWNER-01 | Ingresa nombre del comercio y categoría principal |
| `step_2` | ONBOARDING-OWNER-02 | Ingresa dirección, se asigna `zoneId` automáticamente |
| `step_3` | ONBOARDING-OWNER-03 | Carga horarios iniciales (salteable) |
| `confirmation` | ONBOARDING-OWNER-04 | Revisa resumen antes de publicar |
| `submitted` | — (loading/splash) | `merchants/{id}` creado con `visibilityStatus: review_pending` |
| `completed` | OWNER-01 | Comercio aprobado y visible, flujo cerrado |
| `abandoned` | — | Usuario salió sin completar; progreso persistido para retomar |

---

## 3. Tabla de transiciones

| Desde | Evento | Hacia | Condición / Efecto |
|-------|--------|-------|--------------------|
| `idle` | `START` | `step_1` | Genera `draftMerchantId` (ULID), guarda en `users/{uid}.onboardingOwnerProgress` |
| `step_1` | `SAVE_STEP_1` | `step_2` | `name` (1–80 chars) + `categoryId` válidos. Persiste `step1` en progress. |
| `step_1` | `EXIT_APP` | `abandoned` | Guarda progress parcial |
| `step_2` | `SAVE_STEP_2` | `step_3` | `address` + `lat/lng` + `zoneId` asignado por geocoding. Persiste `step2`. |
| `step_2` | `BACK` | `step_1` | Mantiene `step1` guardado, vuelve sin borrar |
| `step_2` | `EXIT_APP` | `abandoned` | Guarda progress |
| `step_3` | `SAVE_STEP_3` | `confirmation` | Al menos 1 día con horario válido. Escribe `merchant_schedules/{draftId}`. |
| `step_3` | `SKIP_STEP_3` | `confirmation` | Setea `step3Skipped: true`. NO escribe schedules. |
| `step_3` | `BACK` | `step_2` | — |
| `step_3` | `EXIT_APP` | `abandoned` | Guarda progress (horarios parciales no se persisten hasta SAVE) |
| `confirmation` | `SUBMIT` | `submitted` | Escribe `merchants/{draftMerchantId}` con `status: draft`, `visibilityStatus: review_pending`, `sourceType: owner_created`. |
| `confirmation` | `BACK` | `step_3` | — |
| `submitted` | `APPROVE` (CF) | `completed` | `onClaimApprovedPromoteMerchant` o auto-approve flag activo en `admin_configs`. Limpia `onboardingOwnerProgress`. |
| `abandoned` | `RESUME` | paso guardado | Lee `onboardingOwnerProgress.currentStep`, redirige al paso correspondiente |

---

## 4. Reglas de navegación

### 4.1 Detección de owner pendiente
Al autenticar exitosamente en AUTH-03:
1. Leer `users/{uid}.role`.
2. Si `role == 'owner'` Y `onboardingOwnerProgress.currentStep` existe y no es `completed`:
   → navegar a DETAIL-03 con el paso guardado.
3. Si `role == 'owner'` Y no hay progress:
   → navegar a DETAIL-03, iniciar desde `idle`.

### 4.2 Re-entrada y retoma
- El progress se guarda en Firestore en cada transición exitosa.
- Al relanzar la app con sesión activa, el guard de navegación detecta `currentStep != 'completed'` y redirige al paso guardado.
- El usuario puede salir en cualquier momento; al volver, retoma desde donde lo dejó.

### 4.3 Botón X (salir del flujo)
- Visible en todos los pasos.
- Dispara `EXIT_APP` → estado `abandoned`.
- Muestra confirmación: *"¿Querés salir? Podés retomar después desde donde dejaste."*
- Al confirmar: navega a HOME-01 (si es CUSTOMER también) o AUTH-03.

### 4.4 Botón Atrás
- Disponible en step_2, step_3, confirmation.
- NO disponible en step_1 (es el primer paso).
- No borrar datos del paso actual al hacer BACK; los datos se mantienen cargados al volver.

### 4.5 Idempotencia del SUBMIT
- `draftMerchantId` se genera una sola vez en `START` y se reutiliza en todos los intentos.
- Si el usuario hace SUBMIT y la app se cierra antes de recibir confirmación, al retomar se detecta que `merchants/{draftMerchantId}` ya existe → saltar directo a `submitted`.

---

## 5. Validaciones por paso

### Paso 1 — Tipo y nombre
| Campo | Validación |
|-------|-----------|
| `name` | Requerido. Min 2 chars, max 80 chars. |
| `categoryId` | Requerido. Debe existir en colección `categories`. |

### Paso 2 — Dirección y zona
| Campo | Validación |
|-------|-----------|
| `address` | Requerido. Debe haberse seleccionado de autocomplete (no texto libre sin geocodificar). |
| `lat` / `lng` | Requerido. Deben ser coordenadas válidas. |
| `zoneId` | Asignado automáticamente por reverse geocoding. Si no se puede asignar: mostrar error *"No pudimos identificar la zona. Intentá con otra dirección."* |

### Paso 3 — Horarios (si no se skipea)
| Campo | Validación |
|-------|-----------|
| Por día activo: `open` | Formato HH:mm, requerido si el día está activo. |
| Por día activo: `close` | Formato HH:mm, debe ser posterior a `open`. |
| Al menos 1 día | Requerido para habilitar "Guardar y continuar" (si no se quiere skipear). |

### Paso 4 — Confirmación
- Solo lectura. CTA "Publicar" siempre habilitado (los datos fueron validados en pasos anteriores).

---

## 6. Efectos en Firestore por transición

| Transición | Escrituras Firestore |
|------------|---------------------|
| `START` | `users/{uid}` → setea `onboardingOwnerProgress` con `currentStep: step_1`, `draftMerchantId` |
| `SAVE_STEP_1` | `users/{uid}.onboardingOwnerProgress.step1` + `currentStep: step_2` |
| `SAVE_STEP_2` | `users/{uid}.onboardingOwnerProgress.step2` + `currentStep: step_3` |
| `SAVE_STEP_3` | `merchant_schedules/{draftId}` (draft) + `users/{uid}.onboardingOwnerProgress.currentStep: confirmation` |
| `SKIP_STEP_3` | `users/{uid}.onboardingOwnerProgress.step3Skipped: true` + `currentStep: confirmation` |
| `SUBMIT` | `merchants/{draftId}` (nuevo doc) + `users/{uid}.onboardingOwnerProgress.currentStep: submitted` |
| `APPROVE` (CF) | `merchants/{id}.visibilityStatus: visible` + `users/{uid}.onboardingOwnerProgress.currentStep: completed` |
| `EXIT_APP` | `users/{uid}.onboardingOwnerProgress.currentStep: abandoned` |

---

## 7. Dependencias del documento

| Dep | Tarjeta | Estado |
|-----|---------|--------|
| Modelo de comercios | TuM2-0020 | ✅ |
| Modelo de horarios | TuM2-0022 | ✅ |
| Modelo de señales operativas | TuM2-0023 | ✅ |
| Arquitectura de pantallas | TuM2-0027 | ✅ |
| Navegación principal | TuM2-0028 | ✅ |
| Firestore Rules | TuM2-0046 | ✅ |

---

*Documento generado para TuM2-0030-01. Ver SCREENS-MAP.md para las fichas de pantalla y NAVIGATION.md para los guards de navegación.*
