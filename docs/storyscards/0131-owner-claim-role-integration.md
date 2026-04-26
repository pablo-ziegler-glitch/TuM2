# TuM2-0131 — Integración de claim con roles OWNER / owner_pending / aprobación

Estado: READY_FOR_QA (cierre técnico 2026-04-21; pendiente QA de cierre)
Última actualización: 2026-04-26
Prioridad: P0 (MVP crítica)
Épica madre: TuM2-0125 — Reclamo de titularidad de comercio  
Depende de: TuM2-0126, TuM2-0127, TuM2-0128, TuM2-0130

## Estado real de implementación (corte 2026-04-21)
### Cierre implementado
- Fuente canónica de acceso OWNER consolidada en `users/{uid}` con `ownerAccessSummary`, `ownerPending`, `accessVersion`, `role` y fallback `merchantId` legacy.
- Custom claims reducidas a capacidad global mínima (`role`, `owner_pending`, `access_version`), sin `merchantId` principal en JWT.
- Flujo admin `resolveMerchantClaim` ahora ejecuta secuencia completa: resolución claim, recalculo ownership efectivo, recalculo pending, sincronización summary, actualización custom claims, bump de `accessVersion` y auditoría estructurada.
- Política antifraude/reingreso owner activa y auditable (`none`, `cooldown`, `manual_review_only`, `blocked`) con aplicación automática en resolución y rehabilitación manual vía callable admin dedicado.
- Guards y módulo OWNER migrados a lectura canónica (`ownerAccessSummary`) con reglas multi-merchant/multi-claim y prioridad de comercios aprobados sobre claims pendientes.
- Refresh de sesión en app abierta implementado para rutas sensibles claim/owner al volver a foreground y en transición de estado, sin exigir relogin manual.
- Cobertura de tests extendida en backend + mobile para escenarios de rechazo sin degradación de owner existente, bloqueo por restricción, rehabilitación, no-op de `accessVersion`, deep links stale y owner concurrente.
- Integración consolidada con TuM2-0065: rutas de gestión de productos OWNER quedan ocultas/bloqueadas para no-owner y owner_pending según guards de acceso.

### Criterios de costo/canon respetados en la implementación
- Sin listeners globales claims+roles+merchants.
- Resolución de acceso owner con lectura acotada y cache TTL en cliente.
- Refresh costo-eficiente por `access_version`: si no cambia versión, no relee `users/{uid}`.
- Queries de backend con `limit` y/o `count` con fallback acotado.
- No-op write avoidance en sincronización de summary y claims.
- Sin escritura cliente de `merchant_public` ni custom claims.

## 1. Objetivo
Definir la integración entre dominio de claim y sistema de roles para cerrar de forma explícita:
- cuándo el usuario es solo `CUSTOMER`,
- cuándo entra en `owner_pending`,
- cuándo pasa a `OWNER`,
- qué permisos y UX aplican en cada estado.

Regla central: reclamar no equivale a administrar.

## 2. Contexto
TuM2 ya define:
- `CUSTOMER` como base,
- `OWNER` como rol compuesto,
- `owner_pending` como estado intermedio,
- cambios de claims/roles solo vía backend autorizado (Admin SDK),
- refresh de token obligatorio en splash y post-login.

Con claims, ese estado intermedio debe quedar canónico para evitar permisos prematuros y UX ambigua.

## 3. Problema que resuelve
- Escalación temprana de privilegios.
- Ambigüedad entre “en revisión” y “aprobado”.
- Inconsistencia entre Auth, Shell, Owner y estado de claim.
- Confusión claimStatus vs roleStatus.
- Riesgo de bypass por lógica cliente.
- Operación admin frágil al aprobar/rechazar.

## 4. Objetivo de negocio
Maximizar:
- seguridad de permisos,
- claridad del ciclo de vida,
- consistencia claim-auth-navegación,
- trazabilidad de transición a OWNER,
- bajo riesgo de escalación indebida.

## 5. Alcance IN
- Ciclo de vida de rol asociado al claim.
- Reglas de entrada/salida de `owner_pending`.
- Reglas de promoción a `OWNER`.
- Traducción claim status ↔ role status.
- Comportamiento esperado en Splash, post-login, Shell y módulo OWNER.
- Manejo de rechazo/conflicto/cancelación/duplicado.
- Guardrails de seguridad para grants.

## 6. Alcance OUT
- UX detallada de claim (0126).
- Motor de validación automática (0127).
- Operatoria completa Admin (0128).
- Matriz documental (0129).
- Verificación teléfono fase 2 (0132).
- Política detallada de disputas complejas (0133).
- Implementación técnica de custom claims (código).

## 7. Supuestos
- Usuario inicia como `CUSTOMER`.
- Enviar claim no concede `OWNER`.
- `owner_pending` existe como señal intermedia.
- No hay switch de sesión CUSTOMER/OWNER.
- Claims de rol se escriben solo backend.
- Token refresh canónico en splash/post-login.

## 8. Dependencias
Funcionales:
- TuM2-0004, 0054, 0053, 0064, 0126, 0127, 0128, 0130, 0133.

Políticas:
- términos/consentimiento de claim,
- privacidad,
- trazabilidad de aprobación/rechazo.

## 9. Principios rectores
- Claim enviado no equivale a OWNER.
- Backend es única autoridad de grants.
- `owner_pending` no es OWNER parcial operativo.
- CUSTOMER base se conserva hasta aprobación real.
- Transición a OWNER debe ser única, explícita y auditable.
- Cierre negativo limpia pending residual.
- Navegación basada en token real, no estado local stale.

## 10. Arquitectura de estados de negocio
Estado A: `CUSTOMER`  
Estado B: `CUSTOMER + owner_pending`  
Estado C: `OWNER`

Modelo recomendado MVP: mantener CUSTOMER base, sumar pending intermedio, promover a OWNER solo al aprobar.

## 11. Definición canónica de estados
### CUSTOMER
Puede:
- usar experiencia customer,
- iniciar claim,
- consultar estado claim propio.

No puede:
- usar módulos owner protegidos,
- operar recursos de ownership.

### CUSTOMER + owner_pending
Significa claim activo en circuito válido de revisión.

Puede:
- ver estado de claim,
- responder `needs_more_info`,
- ver UX contextual de revisión.

No puede:
- operar panel OWNER pleno,
- editar recursos reservados a OWNER efectivo.

### OWNER
Significa aprobación consolidada por backend + token actualizado.

Puede:
- acceder módulo OWNER,
- gestionar recursos permitidos por negocio.

No puede:
- exceder scope de ownership,
- actuar como admin.

## 12. Regla clave claimStatus vs roleStatus
Son dominios relacionados, no equivalentes.

Ejemplos:
- `submitted` no implica OWNER.
- `under_review` puede implicar `owner_pending=true`.
- `needs_more_info` puede mantener pending activo.
- `rejected` debe limpiar pending si no hay claim vigente.
- `approved` habilita transición a OWNER.
- `conflict_detected` nunca habilita acceso owner.

## 13. Entrada a owner_pending
Recomendación MVP: activar pending cuando claim:
- está enviado,
- sigue vivo en circuito,
- no fue descartado terminalmente.

Estados típicos de ingreso:
- `submitted`,
- `under_review`,
- `needs_more_info` (si sigue abierto).

No activa pending:
- borrador no enviado,
- cancelado,
- rechazo definitivo,
- duplicado terminal sin otro claim vivo.

## 14. Salida de owner_pending
Sale pending cuando:
- aprobación efectiva (pasa a OWNER),
- rechazo definitivo sin otro claim vivo (vuelve CUSTOMER),
- cancelación (vuelve CUSTOMER),
- cierre por duplicado terminal sin caso activo,
- conflicto resuelto negativamente sin aprobación.

Regla: nunca dejar `owner_pending=true` residual tras cierre negativo.

## 15. Transición a OWNER
Solo cuando:
- existe decisión de aprobación válida,
- backend autorizó cambio,
- token refleja nuevo estado.

No alcanza:
- estado local optimista,
- acción admin no consolidada,
- refresh de pantalla sin refresh de token.

## 16. Escenarios recomendados
- Sin claim: `CUSTOMER`, pending false, sin acceso owner.
- Claim enviado válido: `CUSTOMER`, pending true, sin acceso owner.
- `needs_more_info`: `CUSTOMER`, pending true.
- `conflict_detected`: `CUSTOMER`, pending true o estado especial, sin acceso owner.
- Rechazado definitivo: `CUSTOMER`, pending false.
- Aprobado consolidado: `OWNER`, pending false.

## 17. UX por estado
### CUSTOMER
CTAs para iniciar claim y seguir experiencia normal.

### owner_pending
Mostrar:
- “tu solicitud está en revisión”,
- estado + próximos pasos,
- CTA para completar info.

No mostrar:
- panel OWNER operativo completo.

### OWNER
Acceso directo a dashboard y acciones owner reales.

## 18. Relación con Auth (0054)
Obligatorio:
- refresh token post-login,
- refresh token splash,
- leer estado real de token/claims tras refresh.

No permitir:
- grants owner por cache stale,
- asumir pending/owner sin validar token.

## 19. Relación con Shell (0053)
Tres experiencias:
- shell customer,
- shell customer con contexto pending,
- shell owner.

Recomendación: pending como overlay contextual de customer, no shell paralela compleja.

## 20. Relación con OWNER module (0064)
- OWNER aprobado entra a OWNER-01.
- `owner_pending` no entra a operativa owner plena.
- Variante OWNER-pending se valida como estado real de negocio.

## 21. Relación con Admin review (0128)
Decisión admin debe traducirse así:
- approve: claim aprobado + promoción OWNER + fin pending.
- more_info: claim vivo + pending activo.
- reject: cierre negativo + pending off si no hay otro claim.
- conflict: sin acceso owner; pending puede seguir mientras caso siga vivo.

## 22. Relación con conflictos/duplicados (0133)
- Duplicado terminal: no OWNER ni pending residual sin caso vivo.
- Conflicto real: puede mantener pending, nunca elevar privilegios.
- Owner existente: tratamiento restrictivo, sin acceso por “buena fe”.

## 23. Frontend (funcional)
Estados UI obligatorios:
- customer normal,
- owner pending,
- owner aprobado,
- claim rechazado,
- `needs_more_info`,
- conflictivo,
- duplicado terminal.

Comportamientos:
- banners contextuales,
- rutas protegidas correctas,
- explicación clara de por qué no hay acceso owner aún.

## 24. Backend (funcional)
Autoridad única para:
- activar/desactivar pending,
- promover a OWNER,
- cerrar carril pending negativo,
- sincronizar estado real consumido por cliente.

Guardrails:
- no promote-by-client,
- no caminos paralelos a OWNER,
- consistencia rol vs ownership real,
- no escritura cliente de proyecciones públicas.

## 25. Reglas de seguridad obligatorias
1. Enviar claim nunca concede permisos owner.
2. `owner_pending` no equivale a OWNER.
3. Fuente de verdad = backend + token actualizado.
4. No bypass a rutas owner por URL manual.
5. Transición a OWNER única y auditable.
6. Cierre negativo limpia estados pending obsoletos.
7. Conflicto/duplicado nunca elevan privilegios.
8. Cuentas con restricción activa por fraude/abuso en claims/reportes no pueden ingresar, permanecer ni reingresar al carril owner sin revisión manual autorizada.

## 26. Guardrails de costo
- Resolver acceso owner priorizando señal canónica resumida/token.
- Evitar polling continuo de claim para navegación.
- Evitar refresh redundante de token.
- Sin listeners cruzados claims+roles+merchants en splash.
- Cargar detalle claim solo cuando usuario entra a seguimiento.

## 27. Datos impactados
Entidades:
- `users`,
- `merchant_claims`,
- `merchants`,
- auth custom claims,
- estados UI de shell/owner.

Datos clave:
- rol efectivo,
- `owner_pending`,
- `merchantId` vinculado (si aplica),
- `claimStatus` relevante,
- timestamps de transición,
- actor admin de aprobación/rechazo.

## 28. Reglas de negocio detalladas
- Todos inician en CUSTOMER.
- Claim activo elegible puede activar pending.
- OWNER solo por aprobación backend autorizada.
- OWNER incluye CUSTOMER, sin switch de sesión.
- Rechazo definitivo sin claims vigentes apaga pending.
- `needs_more_info` puede mantener pending.
- Conflicto puede mantener pending sin acceso owner.
- App debe refrescar token para reflejar cambios reales.
- OWNER module distingue pending de aprobado sin ambigüedad.
- Restricciones de seguridad sobre claims/reportes se modelan como limitación de capacidades sensibles manteniendo rol base `CUSTOMER`.

## 29. UX / microcopy
Pending:
- “Tu solicitud está en revisión”
- “Todavía no tenés acceso completo a la gestión del comercio”
- “Te avisaremos si necesitamos más información”

Aprobado:
- “Tu comercio ya está listo para ser gestionado”

Evitar:
- mensajes triunfalistas ambiguos,
- copy técnico de permisos/token.

## 30. Analytics y KPI
Eventos:
- `owner_claim_pending_state_entered`
- `owner_claim_pending_state_viewed`
- `owner_claim_pending_more_info_viewed`
- `owner_claim_approved_role_granted`
- `owner_claim_rejected_pending_cleared`
- `owner_module_access_blocked_pending`
- `owner_module_access_granted`

KPIs:
- tiempo promedio en pending,
- % claims que pasan a OWNER,
- % pending que terminan rechazados,
- intentos bloqueados de acceso owner desde pending,
- tiempo entre aprobación y primer acceso owner.

North Star local:
% de usuarios que pasan de claim a OWNER sin confusión ni permisos indebidos.

## 31. Edge cases
- Claim enviado y relogin antes de consolidar pending.
- Claim aprobado/rechazado con sesión abierta.
- Pending intentando rutas owner profundas por URL.
- Duplicado terminal que no debe dejar pending.
- Conflicto activo con pending sin operativa owner.
- Claim cancelado que debe limpiar estado.
- Token desactualizado mostrando estado viejo.
- Doble decisión admin casi simultánea.
- Futuro multi-claim/multi-merchant.

## 32. QA plan
- QA funcional: entrada/salida pending, promoción OWNER, rechazo/limpieza, more-info, conflicto.
- QA auth: refresh splash/post-login, sincronización de claims, no stale peligrosa.
- QA seguridad: no acceso owner desde pending, no grants cliente, no bypass URL.
- QA integración: 0004, 0054, 0053, 0064, 0128.
- QA UX: comprensión pending, aprobación, rechazo y próximos pasos.

## 33. Definition of Done
- Ciclo CUSTOMER → owner_pending → OWNER definido.
- Entrada/salida pending cerradas.
- Claim enviado ≠ OWNER formalizado.
- Traducción claim status ↔ role status cerrada.
- Auth/Shell/OWNER alineados.
- Rechazo/conflicto/more-info cubiertos.
- Reglas de seguridad de grants/acceso explícitas.
- Edge cases principales cubiertos.
- Lista para implementación sin contradicciones.

## 34. Plan de rollout
Fase 1: cierre definición con 0126/0127/0128/0130/0004/0054/0064.  
Fase 2: implementación pending canónico + rutas protegidas + transición a OWNER + limpieza negativa.  
Fase 3: medición de tiempo pending, fricción y bloqueos indebidos.  
Fase 4: evolución a multi-claim, multi-merchant y permisos owner finos.

## 35. Documentos a sincronizar
Crear/mantener:
- `docs/storyscards/0131-owner-claim-role-integration.md`
- `docs/storyscards/0126-merchant-claim-flow.md`
- `docs/storyscards/0127-merchant-claim-auto-validation.md`
- `docs/storyscards/0128-admin-merchant-claims-review.md`
- `docs/storyscards/0130-merchant-claim-sensitive-data-protection.md`
- `docs/storyscards/0133-merchant-claim-conflicts-and-duplicates.md`

Actualizar por impacto:
- `docs/storyscards/0004-role-segment-architecture.md`
- `docs/storyscards/0054-auth-complete.md`
- `docs/storyscards/0053-mobile-shell.md`
- `docs/storyscards/0064-owner-module-business.md`
- `docs/storyscards/0081-claim-impact-merchant-profile-review.md`
- legales (si cambia comunicación de owner_pending).

## 36. Cierre ejecutivo
TuM2-0131 define el puente seguro entre reclamar, quedar pendiente y convertirse en OWNER:
- todos parten como CUSTOMER,
- claim activo puede activar owner_pending,
- pending no concede acceso owner pleno,
- OWNER solo por aprobación backend autorizada,
- cierres negativos limpian pending,
- Auth + Shell + OWNER reflejan estado real (token + backend), no supuestos locales.

## 37. Evidencia de implementación (archivos clave)
- Backend:
  - `functions/src/lib/merchantClaimOwnerPending.ts`
  - `functions/src/callables/merchantClaims.ts`
  - `functions/src/triggers/claims.ts`
  - `functions/src/index.ts`
  - `functions/src/callables/__tests__/merchantClaims.integration.test.ts`
- Mobile:
  - `mobile/lib/core/auth/owner_access_summary.dart`
  - `mobile/lib/core/auth/auth_notifier.dart`
  - `mobile/lib/core/auth/auth_state.dart`
  - `mobile/lib/core/providers/auth_providers.dart`
  - `mobile/lib/core/router/router_guards.dart`
  - `mobile/lib/modules/merchant_claim/screens/merchant_claim_flow_screens.dart`
  - `mobile/lib/modules/owner/providers/owner_providers.dart`
  - `mobile/lib/modules/owner/repositories/owner_repository.dart`
  - `mobile/lib/modules/owner/screens/owner_panel_screen.dart`
  - `mobile/lib/modules/owner/screens/owner_access_guard_page.dart`
  - `mobile/lib/modules/owner/analytics/owner_dashboard_analytics.dart`
  - `mobile/test/core/router/router_guards_claim_test.dart`
  - `mobile/test/core/router/router_guards_test.dart`
  - `mobile/test/modules/owner/owner_panel_screen_test.dart`
  - `mobile/test/core/auth/owner_access_summary_test.dart`

## 38. Matriz E2E cruzada (claim -> admin -> owner)
Cobertura validada por tests de integración backend + router/widget mobile (8/8):
- (1) CUSTOMER claim -> admin approve -> app abierta -> refresh -> OWNER-01:
  - `functions/src/callables/__tests__/merchantClaims.integration.test.ts` (`resolve approved promueve a owner y limpia owner_pending`)
  - `mobile/test/core/router/router_guards_claim_test.dart` (`E2E-01 claim aprobado + refresh permite entrada OWNER-01`)
- (2) CUSTOMER claim -> admin reject -> desaparece carril owner_pending:
  - `functions/src/callables/__tests__/merchantClaims.integration.test.ts` (`E2E-02 CUSTOMER claim -> admin reject limpia owner_pending`)
- (3) OWNER(A) + pending(B) -> approve(B) -> mantiene contexto correcto:
  - `functions/src/callables/__tests__/merchantClaims.integration.test.ts` (`E2E-03 OWNER(A)+pending(B)->approve(B) conserva OWNER y queda multi-merchant`)
- (4) OWNER(A) + conflict(B) -> A sigue operable, B visible conflicto:
  - `functions/src/callables/__tests__/merchantClaims.integration.test.ts` (`E2E-04 OWNER(A)+conflict(B) mantiene A operable y B conflictivo`)
- (5) blocked user -> re-entry deny consistente UI/backend:
  - `functions/src/callables/__tests__/merchantClaims.integration.test.ts` (`submit bloquea reingreso cuando restrictionState=blocked`)
  - `mobile/test/core/router/router_guards_claim_test.dart` (`owner restringido no puede reingresar a subrutas owner por deep link`)
- (6) app offline durante resolución -> no habilita permisos hasta refresh exitoso:
  - `mobile/test/core/router/router_guards_claim_test.dart` (`E2E-06 offline con estado stale no habilita owner hasta refresh exitoso`)
- (7) deep links OWNER-01 con estado viejo -> reevaluación y redirect:
  - `mobile/test/core/router/router_guards_claim_test.dart` (`deep link stale a owner desde customer redirige a access updated`)
- (8) múltiples claims concurrentes -> ruta correcta y sin ambigüedad:
  - `functions/src/callables/__tests__/merchantClaims.integration.test.ts` (`E2E-08 múltiples claims concurrentes reflejan owner_pending_only sin ambigüedad`)
  - `mobile/test/core/router/router_guards_claim_test.dart` (`E2E-08 múltiples claims concurrentes sin aprobados mantienen ruta de pending`)

## 39. Riesgo residual documentado
- Push FCM de invalidación inmediata (`claim_state_changed`) quedó opcional y no se activó en este cierre para evitar introducir infraestructura nueva fuera del scope canónico; el fallback implementado es refresh en foreground + refresh explícito en pantallas sensibles.
