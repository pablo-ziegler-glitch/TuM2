# TuM2-0054 — Auth completa

## Sync 0127 implementado (2026-04-16)
- El claim pasa por `submitted` + auto-validación backend idempotente antes de revisión manual.
- Auth no asume aprobación por submit; sigue leyendo `owner_pending`/`role` desde claims backend.

Estado propuesto: UPDATE REQUIRED  
Prioridad: P0  
Motivo de actualización: impacto directo de la nueva épica de reclamo de titularidad sobre autenticación, resolución de claims, refresh de token y navegación post-login.

## 1. Objetivo
Actualizar Auth para resolver no solo identidad (`logueado/no logueado`) sino estado real de acceso:
- `CUSTOMER`,
- `CUSTOMER + owner_pending`,
- `OWNER`.

Auth debe:
- identificar usuario autenticado,
- refrescar token en puntos canónicos,
- leer estado real role/claim,
- reflejar `owner_pending`,
- evitar grants prematuros,
- enrutar a experiencia correcta post-login.

## 2. Contexto
Base vigente:
- Email magic link + Google Sign-In.
- `getIdTokenResult(forceRefresh: true)` en Splash y post-login.
- logout canónico (`signOut` + limpieza persistencia + invalidación providers).
- custom claims solo por backend (Admin SDK).
- OWNER compuesto, sin switch de sesión.

Con claims, Auth debe resolver también estados intermedios y transiciones dinámicas durante sesión persistida.

## 3. Problema que resuelve
- Login hacia experiencia incorrecta si no contempla pending.
- Aprobaciones/rechazos que no reflejan por token stale.
- Confusión entre estado local, claim status y rol efectivo.
- Incoherencia de identidad de claim si no se ancla en email autenticado.

## 4. Objetivo de negocio
Que login y splash funcionen como resolución contextual segura:
quién entra + qué puede hacer hoy + qué superficie debe ver ahora.

## 5. Alcance IN
- `owner_pending` incorporado explícitamente en Auth.
- email autenticado como email canónico del claim.
- resolución post-login y en Splash del estado real.
- relación token refresh ↔ cambios de rol/claim.
- impacto en guards y navegación inicial.
- comportamiento tras approve/reject/conflict/duplicate.
- sincronización con 0004, 0053, 0064 y 0131.

## 6. Alcance OUT
- No redefine proveedores de login.
- No implementa review Admin ni motor completo de roles.
- No reemplaza tarjetas de claim/roles; absorbe su impacto en Auth.

## 7. Supuestos
- auth por magic link o Google.
- email autenticado = email del claim.
- teléfono MVP opcional/sin verificación.
- owner_pending señal backend formal.
- cliente no es autoridad para conceder OWNER.

## 8. Dependencias
- TuM2-0004, 0053, 0064, 0126, 0131, 0133.
- legales de claim y privacidad asociada.

## 9. Arquitectura propuesta
Auth con doble resolución:
1. Identidad: usuario autenticado y cuenta.
2. Estado de acceso: `customer`, `pending`, `owner` (y derivados de cierre/conflicto).

Auth no termina en “logueado”; entrega “logueado + estado de acceso resuelto”.

## 10. Identidad canónica del claim
Regla explícita:
el email autenticado del usuario es el email del claim.

Consecuencias:
- sin email alternativo editable en claim MVP,
- Auth es origen de verdad de identidad de contacto,
- mejora trazabilidad y reduce incoherencias.

## 11. Estados canónicos que Auth debe resolver
- no autenticado
- autenticado customer
- autenticado pending
- autenticado owner
- autenticado con cambio reciente pendiente de reflejo (antes de refresh)
- autenticado con claim cerrado/rechazado (sin pending)
- autenticado con conflicto (sin owner)

## 12. Refresh obligatorio en Splash
Se ratifica:
`getIdTokenResult(forceRefresh: true)` en Splash es obligatorio.

Objetivo ampliado:
- capturar owner_pending,
- promociones a owner,
- cierres/rechazos de pending,
- cambios de claim recientes.

## 13. Refresh obligatorio post-login
También obligatorio forzar refresh antes de navegar.

Evita navegación optimista por memoria local stale.

## 14. Resolución de acceso post-login
Secuencia canónica:
1. identificar usuario autenticado,
2. forzar refresh token,
3. leer custom claims/señales relevantes,
4. resolver estado de acceso (`customer|pending|owner`),
5. entregar resolución a shell/guards/router.

Sin atajos paralelos.

Si la cuenta tiene restricción activa por fraude o uso indebido en funciones sensibles, Auth debe resolver sesión autenticada con acceso general permitido pero bloqueo explícito de claims/reportes y carriles sensibles, sin bypass por navegación ni rehabilitación automática.

## 15. Resolución al reabrir app
Con sesión persistida:
- validar sesión,
- refresh en splash,
- re-resolver estado role/claim,
- decidir superficie inicial correcta.

## 16. Relación con owner_pending
Auth debe:
- detectarlo explícitamente,
- proveerlo a navegación,
- sostener UX contextual mientras caso siga vivo.

`owner_pending` no es OWNER ni detalle accesorio.

## 17. Relación con OWNER
Auth no crea OWNER; Auth lo refleja tras promoción backend confirmada + token refresh.

## 18. Rechazados/cerrados
Si pending se cierra negativamente y no hay otro claim vivo, Auth debe dejar de reflejar pending en siguiente resolución canónica.

## 19. Conflictos y duplicados
- duplicado terminal no sostiene pending por sí solo,
- conflicto puede sostener pending,
- ninguno habilita OWNER.

Auth refleja consecuencias backend, no interpreta conflicto como “casi owner”.

## 20. Impacto sobre Shell (0053)
Shell debe consumir de Auth un `resolvedAccessState` explícito, no inferirlo localmente.

## 21. Impacto sobre OWNER module (0064)
- owner: acceso operativo pleno,
- pending: experiencia contextual no operativa,
- customer: sin rutas owner.

## 22. Logout y limpieza
Se ratifica:
- `FirebaseAuth.signOut()`
- limpieza persistencia local
- invalidación Riverpod providers

Incluye limpiar residuos de pending/owner journey.

## 23. Frontend (funcional)
Frontend consume estado resuelto simple:
- `unauthenticated`
- `authenticated_customer`
- `authenticated_pending`
- `authenticated_owner`

No reimplementa lógica compleja de claims.

## 24. Backend (autoridad)
Backend sigue siendo fuente de verdad de:
- custom claims,
- transición de rol,
- activación/desactivación pending,
- concesión OWNER.

Cliente nunca escribe claims de rol.

## 25. Seguridad
Reglas críticas:
1. login exitoso no implica OWNER.
2. token actualizado requerido para resolver acceso real.
3. cliente no concede ni elimina OWNER.
4. guards sin bypass por navegación manual.
5. `owner_pending` no mapea a permisos owner.
6. conflictos no degradan seguridad por estado stale.
7. restricciones de claims/reportes por fraude o abuso no crean rol nuevo y solo se levantan por revisión autorizada.

## 26. Guardrails de costo
- Resolver estado de acceso con token + señal resumida, no fan-out.
- Sin polling continuo para decidir navegación.
- Sin listeners permanentes claims+roles en splash/login.
- Cache TTL corta y controlada para sesión; invalidar en eventos canónicos.

## 27. UX / microcopy
Login simple, sin jerga técnica.

Mensajes compatibles:
- “Tu solicitud sigue en revisión”
- “Todavía no tenés acceso completo a la gestión del comercio”
- “Tu comercio ya está listo para ser gestionado”

Sin promesas prematuras.

## 28. Datos impactados
- estado de autenticación
- email autenticado
- token/custom claims
- señal `owner_pending`
- rol efectivo resuelto
- guards/ruta inicial
- estado persistido de sesión y UI derivada

## 29. Riesgos si no se actualiza
- UX post-login incorrecta,
- promociones/rechazos no reflejados,
- rutas owner erróneas,
- pending obsoleto persistente,
- contradicciones entre Auth/Shell/OWNER.

## 30. Edge cases
- sesión persistida con cambio de estado offline,
- aprobación/rechazo con sesión abierta,
- conflicto vigente con re-login,
- duplicado terminal no debe revivir pending,
- multi-merchant futuro sin romper patrón base.

## 31. BDD / aceptación
- Dado usuario autenticado, cuando inicia sesión, entonces Auth fuerza refresh antes de navegar.
- Dado usuario pending, cuando abre app/login, entonces ve pending y no owner pleno.
- Dado usuario owner aprobado (backend consolidado), cuando refresca token, entonces Auth lo resuelve como owner.
- Dado rechazado sin claims vivos, cuando abre app, entonces ya no se resuelve pending.
- Dado logout, cuando vuelve anónimo, entonces no quedan residuos locales de pending/owner.

## 32. QA plan
- QA funcional: login/relogin/sesión persistida/pending/owner/rechazo/conflicto.
- QA auth: refresh token y consistencia estado.
- QA seguridad: guards/bypass/no grants cliente.
- QA UX: sin flashes incorrectos ni confusión de estado.

## 33. Definition of Done
- Email autenticado formalizado como email del claim.
- Auth resuelve explícitamente pending.
- Splash y post-login con refresh obligatorio y objetivo ampliado.
- Navegación inicial alineada con customer/pending/owner.
- Logout limpia estado derivado completo.
- Impacto en 0053 y 0064 documentado.

## 34. Plan de rollout
1. Actualizar documentación Auth (esta tarjeta).
2. Alinear Shell y OWNER module.
3. Verificar lectura real token + tratamiento pending en login/splash.
4. QA cruzado con claims aprobados/rechazados/conflictivos/duplicados.

## 35. Sincronización documental obligatoria
- `docs/storyscards/0054-auth-complete.md`
- `docs/storyscards/0004-role-segment-architecture.md`
- `docs/storyscards/0053-mobile-shell.md`
- `docs/storyscards/0064-owner-module-business.md`
- `docs/storyscards/0126-merchant-claim-flow.md`
- `docs/storyscards/0131-owner-claim-role-integration.md`

## 36. Cierre ejecutivo
Auth deja de resolver solo identidad y pasa a resolver estado real de acceso:
- `CUSTOMER`,
- `CUSTOMER + owner_pending`,
- `OWNER`.

Además, fija que email autenticado = email canónico del claim y que ningún grant owner puede originarse en cliente ni en estado stale local.
