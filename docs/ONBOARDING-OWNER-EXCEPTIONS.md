# TuM2 — Onboarding OWNER: Estados de excepción
### Tarjeta: TuM2-0030-03

Especificación de los 14 estados de excepción del flujo de registro de comercio (EX-01 a EX-14), agrupados por categoría funcional. Complementa `ONBOARDING-OWNER-FSM.md`.

---

## Tokens de color para estados de excepción

Los tokens base están en `design/tokens.json`. Para los estados de excepción se usan las siguientes combinaciones:

| Semántica | Token | Hex | Uso |
|-----------|-------|-----|-----|
| Error / destructivo | — | `#DC2626` | Bordes de campo inválido, banner de error crítico, botón "Descartar" |
| Error bg | — | `#FEF2F2` | Fondo de banners de error |
| Warning / advertencia | `tertiary.500` | `#FF8D46` | Bordes de warning en campo, barra de TTL por vencer, badge "Pendiente" |
| Warning bg | `tertiary.50` | `#FFF3EB` | Fondo de banners de advertencia |
| Éxito | `secondary.500` | `#0F766E` | Ícono de check en success, barra de TTL saludable |
| Éxito bg | `secondary.50` | `#E6F5F4` | Fondo de banners de éxito |
| Info neutral | `primary.50` | `#EBF1FD` | Fondo de banners informativos |
| Texto deshabilitado | `neutral.500` | `#B0AE9F` | CTA en estado disabled, placeholder de mapa sin conexión |

---

## Grupo A — Interrupción y borrador (EX-01 a EX-04)

### EX-01 · Modal de salida

**Disparador:** botón X en cualquier paso del flujo (step_1 a confirmation).

**Componente:** bottom sheet (no alert nativo). El alert del SO no soporta tres opciones con jerarquía visual diferente; acá la jerarquía es crítica.

**Contenido del sheet:**

| Elemento | Texto | Estilo |
|----------|-------|--------|
| Título | "¿Salir del registro?" | `heading/md`, neutral-900 |
| Descripción | "Tenés información ingresada. Guardamos un borrador por 72 hs para que puedas retomar después." | `body/sm`, neutral-700 |
| CTA principal | "Guardar borrador y salir" | Botón outline `primary.500` — acción promovida por el sistema |
| CTA secundario | "Descartar y salir" | Botón con bg `#FEF2F2`, texto `#DC2626` — visible pero sin prominencia |
| Tertiary | "Seguir completando" | Texto puro `primary.500` — menor peso: el usuario ya decidió irse |

**Lógica:**
- "Guardar borrador y salir" → dispara `SAVE_DRAFT` + `EXIT_APP` → estado `abandoned` con TTL 72 h.
- "Descartar y salir" → dispara `DISCARD` + `EXIT_APP` → borra draft de `SharedPreferences` y Firestore, navega a HOME-01 o AUTH-03.
- "Seguir completando" → cierra el sheet, no cambia estado.

---

### EX-02 · Bienvenida con borrador reciente

**Condición:** usuario abre el flujo y existe un draft con `ttlRemainingHours > 6`.

**Pantalla:** pre-step (antes de step_1), reemplaza la welcome genérica.

| Elemento | Detalle |
|----------|---------|
| Header | "Registrá tu comercio" / subtítulo: "TuM2 para dueños" |
| Tagline | "Conectá tu comercio con los vecinos de tu zona." |
| Card de borrador | Tono informativo, sin urgencia |
| Barra de progreso | Teal (`secondary.500`), porcentaje = `ttlRemainingHours / 72 * 100` |
| Badge de paso | "Paso N de 4" en esquina superior derecha de la card |
| Progreso de pasos | Lista de steps completados (ej. "Nombre y categoría listos") |
| Timestamp | "Guardado hace X hs · expira en ~Y hs" |
| CTA primario | "Retomar registro" (`primary.500`, full width) |
| CTA secundario | "Empezar de cero" (outline, full width) |
| Footer note | "Al retomar, el borrador se restablece por otras 72 hs." — **crítico comunicarlo**: el usuario puede no saber que retomar extiende el TTL |

---

### EX-03 · Bienvenida con borrador por vencer

**Condición:** draft existe con `ttlRemainingHours <= 6`.

Misma estructura que EX-02, con los siguientes cambios:

| Elemento | Cambio vs EX-02 |
|----------|-----------------|
| Barra de progreso | Naranja (`tertiary.500`) |
| Tono de la card | Warning (borde y fondo `tertiary.50`) |
| Header de card | "Tu borrador está por vencer" |
| Timestamp | "Guardado hace 66 hs · expira en ~6 hs" |
| CTA primario | "Retomar ahora" (mayor urgencia en el label) |
| Footer note | Se mantiene igual — reforzar que retomar extiende el TTL |

---

### EX-04 · Borrador expirado

**Condición:** draft existe pero `Date.now() > draft.expiresAt`.

| Elemento | Detalle |
|----------|---------|
| Banner rojo | "Tu borrador venció" — bg `#FEF2F2`, borde `#DC2626` |
| Card de borrador | Nombre del comercio con texto tachado + badge "Expirado" |
| Info de expiración | "Venció hace X hs · datos eliminados" |
| Texto explicativo | "Los borradores se guardan por 72 hs. Podés registrar tu comercio cuando quieras." — sin dramatismo, el dato está limpio |
| CTA primario | "Registrar mi comercio" (`primary.500`, full width) — framing positivo, no "volver a intentar" |
| Footer | "El proceso toma menos de 5 minutos." — reduce barrera de re-entrada |

**Lógica:** al mostrar EX-04, el sistema ya habrá eliminado el draft de `SharedPreferences`. El backend maneja el TTL server-side; `SharedPreferences` actúa solo como caché local.

---

## Grupo B — Publicando, éxito y error de red en submit (EX-05 a EX-07)

### EX-05 · Loading — publicando comercio

**Disparador:** usuario confirma "Publicar mi comercio" en step_4. Inicia la escritura en Firestore.

| Elemento | Detalle |
|----------|---------|
| Fondo | Pantalla completa, sin stepper ni X |
| Spinner | Circular, `primary.500`, centrado |
| Título | "Publicando tu comercio..." |
| Subtítulo | "Esto tarda solo unos segundos" |
| Skeleton card | Debajo del spinner — 3 líneas de placeholder grises. Técnica de percepción de progreso: el usuario ve que algo está siendo procesado y el tiempo de espera se siente más corto que pantalla vacía |
| Footer | "No cerrés la app mientras procesamos" — previene el error más frecuente: usuario que cierra y pierde el submit |

**Navegación:** no hay back ni X. Es un estado de transición no interrumpible.

---

### EX-06 · Éxito — comercio enviado

**Disparador:** Firestore confirma la escritura de `merchants/{draftId}` con `visibilityStatus: review_pending`.

| Elemento | Detalle |
|----------|---------|
| Ícono | Checkmark en círculo, `secondary.500` — grande, central |
| Título | "¡Comercio enviado!" |
| Subtítulo | "{merchantName} está en revisión. Te avisamos cuando esté visible." |
| Bloque "¿Qué pasa ahora?" | 3 pasos numerados — reduce ansiedad post-submit, responde las preguntas antes de que el usuario las haga, reduce tickets de soporte |
| Paso 1 | "Revisamos tu comercio (hasta 24 hs)" |
| Paso 2 | "Te notificamos por email cuando esté activo" |
| Paso 3 | "Podés editar datos desde tu perfil" |
| CTA primario | "Ir a mi perfil de comercio" (`primary.500`) |
| CTA secundario | "Volver al inicio" (texto) |

---

### EX-07 · Error de red en submit

**Disparador:** timeout o error de red al intentar escribir en Firestore desde step_4.

**Pantalla:** step_4 con banner de error superpuesto (no pantalla nueva).

| Elemento | Detalle |
|----------|---------|
| Stepper | Todos los pasos en teal (el flujo está completo, el problema es técnico) |
| Banner rojo | Ícono `⚠`, título "No se pudo publicar" — **no** dice "Error": el framing importa |
| Texto del banner | "Problema de conexión. Tus datos están guardados — intentá cuando tengas red." — esta frase elimina el 80% de la frustración porque desmiente el miedo a haber perdido todo |
| Summary card | Se mantiene visible — refuerza que los datos no se perdieron |
| CTA primario | "Reintentar" (`primary.500`) |
| Footer | "Tus datos están guardados localmente." |
| CTA terciario | "Intentar más tarde" (texto) → navega a HOME-01 sin limpiar el draft |

**Lógica de retry:** el `draftMerchantId` es idempotente (ver FSM §4.5). Reintentar con el mismo ID no crea duplicados.

---

## Grupo C — Validación inline y errores de campo (EX-08 a EX-11)

### Patrón de validación triple

Todos los errores de campo siguen tres capas, que sirven para dos perfiles de usuario:

1. **Banner global** al tope de la pantalla — para el usuario que lee de arriba hacia abajo.
2. **Label del campo en rojo** — señal visual de dónde está el problema.
3. **Mensaje inline debajo del campo** — para el usuario que va directo a editar el campo.

Este patrón no es redundante: cada capa sirve a un usuario diferente.

---

### EX-08 · Paso 1 sin datos (intento de avanzar con campos vacíos)

**Disparador:** usuario toca "Siguiente" con `name` vacío o sin `categoryId` seleccionado.

| Elemento | Detalle |
|----------|---------|
| Banner global | Bg `#FEF2F2`, ícono `⚠` rojo, "Revisá los campos" / "Completá el nombre y seleccioná una categoría para continuar." |
| Campo nombre | Borde `#DC2626`, label "Nombre del comercio *" en rojo, error inline: "△ Ingresá el nombre del comercio" |
| Grid de categorías | Borde exterior del grid `#DC2626`, error inline debajo: "△ Seleccioná una categoría" |
| CTA "Siguiente" | Estado `disabled` (`neutral.500`) — solo se habilita cuando ambos campos son válidos |

---

### EX-09 · Dirección inválida (sin número de puerta)

**Disparador:** usuario ingresa una dirección en texto libre sin número, o selecciona del autocomplete un resultado sin número identificable.

| Elemento | Detalle |
|----------|---------|
| Campo dirección | Borde `#DC2626`, error inline: "△ La dirección debe incluir número de puerta" |
| Card de error | Bg `#FEF2F2`, título "Dirección no reconocida", body: "Buscá con número de puerta para asignar la zona correcta." |
| Mapa | Placeholder con borde punteado + texto "Seleccioná una dirección válida". **No se oculta el mapa** — mantener estructura visual estable evita el layout jump que desorientaría al usuario |
| CTA "Siguiente" | Disabled |

---

### EX-10 · Error de red en autocomplete (Google Places)

**Disparador:** usuario escribe en el campo de dirección pero no hay conexión a internet (Places API no responde).

| Elemento | Detalle |
|----------|---------|
| Campo dirección | Borde `tertiary.500` (warning, no error — el usuario no hizo nada mal) |
| Banner warning | Bg `tertiary.50`, ícono naranja `⚠`, "Sin conexión a internet" / "El buscador requiere conexión. Revisá tu red e intentá de nuevo." |
| Mapa | Placeholder gris: "Mapa no disponible sin conexión" |
| CTA | Reemplaza "Siguiente" por "Reintentar búsqueda" (outline `primary.500`) — frame de acción positiva |

---

### EX-11 · Horario inválido (cierre antes de apertura)

**Disparador:** usuario ingresa un horario de cierre menor al de apertura en algún día activo.

| Elemento | Detalle |
|----------|---------|
| Fila afectada | Solo la fila del día conflictivo tiene borde rojo en el campo de cierre — **no se marca toda la pantalla de rojo**: el error está localizado, la pantalla lo comunica con precisión |
| Error inline | Debajo de la fila: "△ El cierre (08:00) no puede ser antes de la apertura (18:00)" — incluye los valores reales para que el usuario no tenga que releerlos |
| Otras filas | Sin cambios visuales |
| CTA "Guardar y continuar" | Disabled mientras exista al menos un día con error |

---

## Grupo D — Edge cases de negocio (EX-12 a EX-14)

### EX-12 · Confirmación sin horarios

**Condición:** usuario llegó a step_4 habiendo usado "Completar después" en step_3 (`step3Skipped: true`).

| Elemento | Detalle |
|----------|---------|
| Card resumen | Fila "Horarios" muestra badge naranja "Pendiente" en lugar del resumen de días |
| Banner warning | Bg `tertiary.50`, ícono naranja, "Horarios no cargados" / "Los vecinos verán 'consultar horarios' hasta que los cargues desde tu perfil." — información concreta sobre la consecuencia real |
| CTA primario | "Publicar igual" (`primary.500`) — el sistema permite continuar |
| CTA secundario | "Cargar horarios ahora" (outline `primary.500`) — mismo peso visual que el primario, **no** texto puro. La razón: cargar horarios es una acción viable, no penalizada. Si fuera texto, el usuario la descartaría visualmente |
| Footer | "Tu comercio será revisado y estará visible en breve." |

---

### EX-13 · Nombre duplicado — soft (solo nombre coincide)

**Condición:** al validar `name` en paso 1, la búsqueda en Firestore encuentra un comercio con el mismo nombre en la misma zona, pero la dirección es diferente.

**El sistema advierte pero permite continuar.** Dos negocios distintos pueden compartir nombre.

| Elemento | Detalle |
|----------|---------|
| Campo nombre | Borde `tertiary.500` (warning, no error) |
| Banner warning inline | Bg `tertiary.50`, debajo del campo: "Ya existe un comercio con este nombre en tu zona. ¿Es el mismo local? [Contactá soporte]. Si es otro, usá un nombre diferente." — el link de soporte es navegable |
| CTA | "Continuar de todos modos" (`primary.500`) — el flujo no se bloquea |
| Footer | "Podés aclarar la situación durante la revisión." — reduce ansiedad, el usuario sabe que hay un proceso humano |

---

### EX-14 · Comercio ya registrado — hard (nombre + dirección coinciden)

**Condición:** al validar paso 2, nombre + dirección coinciden con un comercio ya existente en Firestore. Alta confianza de duplicado real.

**A diferencia de EX-13, aquí el flujo se bloquea.** El sistema presenta el flujo de reclamación de titularidad.

| Elemento | Detalle |
|----------|---------|
| Pantalla | Interstitial full-screen (sin stepper) — señal visual de que salimos del flujo normal |
| Ícono | "?" en círculo naranja grande — indica incertidumbre, no error |
| Título | "Este comercio ya existe" |
| Body | "Encontramos '{merchantName}' en {zoneName} ya registrada en TuM2." |
| Card del comercio existente | Nombre, dirección, zona — contexto para que el usuario confirme que es el mismo |
| CTA primario | "Soy el dueño — reclamar" (`primary.500`) → inicia flujo de ownership claim con verificación humana |
| CTA secundario | "Registrar otro comercio" (outline) → vuelve a step_1 limpio |
| Footer | "Si reclamás, verificamos tu identidad en 24 hs." — expectativa de tiempo explícita |

**Nota de design system:** la distinción entre EX-13 (warning navegable) y EX-14 (bloqueo con escape) es un patrón reutilizable para otros flujos del producto donde un conflicto de datos puede ser ambiguo vs. determinista.

---

## Arquitectura del borrador (TTL)

### Problema de solo-almacenamiento local

Si el borrador vive únicamente en el dispositivo (`SharedPreferences`), el usuario pierde el progress al cambiar de dispositivo o reinstalar la app.

### Arquitectura correcta

```
SharedPreferences (dispositivo Flutter)
    ↕ sincronización
Firestore: merchant_drafts/{draftId}
    - userId
    - currentStep
    - stepData: { step1, step2, step3Skipped }
    - createdAt
    - expiresAt  ← TTL gestionado server-side
    - ttlExtendedAt  ← actualizado al retomar
```

**Reglas:**
- `SharedPreferences` es el caché local para uso offline y acceso rápido (paquete `shared_preferences`).
- Firestore es la fuente de verdad para el borrador.
- El TTL se extiende server-side cuando el usuario retoma (no solo localmente).
- Al expirar, una Cloud Function limpia `merchant_drafts/{draftId}` y el campo `onboardingOwnerProgress` en `users/{uid}`.

**Caso de uso de negocio habilitado:** el equipo de soporte puede ver borradores abandonados (> 48 h sin actividad) y hacer outreach proactivo hacia el dueño.

---

## Nuevos estados y transiciones en FSM

Estos estados complementan el diagrama en `ONBOARDING-OWNER-FSM.md`:

| Estado nuevo | Descripción |
|--------------|-------------|
| `draft_expired` | Draft encontrado pero `Date.now() > expiresAt`. Se limpia y se ofrece registro limpio (EX-04). |
| `draft_resumable` | Draft vigente. Se ofrece retomar con contexto (EX-02 o EX-03 según urgencia). |
| `submitting` | Escritura en Firestore en curso. No interrumpible (EX-05). |
| `submit_error` | Error de red en el SUBMIT. Datos guardados localmente, reintentable (EX-07). |
| `submit_success` | Escritura confirmada, `visibilityStatus: review_pending` (EX-06). |
| `ownership_claim` | Duplicado hard detectado. Flujo de reclamación de titularidad (EX-14). |

| Transición nueva | Desde | Evento | Hacia |
|-----------------|-------|--------|-------|
| `SAVE_DRAFT` | cualquier step activo | usuario toca "Guardar borrador y salir" | `abandoned` |
| `DISCARD` | cualquier step activo | usuario toca "Descartar y salir" | `idle` (draft eliminado) |
| `RESUME` | `draft_resumable` | usuario toca "Retomar registro/ahora" | paso guardado en `currentStep` |
| `START_FRESH` | `draft_resumable` o `draft_expired` | usuario toca "Empezar de cero" | `step_1` (draft anterior eliminado) |
| `SUBMIT_START` | `confirmation` | usuario toca "Publicar mi comercio" | `submitting` |
| `SUBMIT_OK` | `submitting` | Firestore confirma escritura | `submit_success` |
| `SUBMIT_FAIL` | `submitting` | timeout / error de red | `submit_error` |
| `RETRY_SUBMIT` | `submit_error` | usuario toca "Reintentar" | `submitting` |
| `CLAIM_OWNERSHIP` | `ownership_claim` | usuario toca "Soy el dueño — reclamar" | flujo externo de claim |

---

## Dependencias

| Dep | Tarjeta | Estado |
|-----|---------|--------|
| FSM base del flujo | TuM2-0030-01 / ONBOARDING-OWNER-FSM.md | ✅ |
| Wireframes de los 4 pasos principales | TuM2-0030-02 | ✅ |
| Tokens de color | TuM2-0010 / design/tokens.json | ✅ |
| Modelo de comercios | TuM2-0020 | ✅ |
| Firestore Rules | TuM2-0046 | ✅ |

---

*Documento generado para TuM2-0030-03. Ver ONBOARDING-OWNER-FSM.md para el flujo principal y design/tokens.json para los valores de color.*
