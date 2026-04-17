# TuM2-0004 — Arquitectura de roles, segmentos y ciclo de vida de acceso

## Sync 0127 implementado (2026-04-16)
- 0127 se ejecuta en backend al entrar a `submitted` y mantiene separación estricta entre `claimStatus` y permisos.
- No existe promoción automática a `OWNER` desde auto-validación.
- `owner_pending` sigue siendo señal intermedia backend-driven.

Estado propuesto: UPDATE REQUIRED  
Prioridad: P0  
Motivo de actualización: impacto directo de la nueva épica de reclamo de titularidad de comercio (`merchant_claims`) sobre roles, estados intermedios, navegación, seguridad y ciclo de vida de acceso.

## 1. Objetivo
Actualizar la arquitectura de roles y segmentos para distinguir sin ambigüedad entre:
- `CUSTOMER` base,
- `CUSTOMER + owner_pending`,
- `OWNER` aprobado efectivo.

Regla central: reclamar un comercio no equivale a administrarlo; toda transición a OWNER es backend-driven, auditable y controlada.

## 2. Contexto
Con la épica de claims, el modelo binario “no owner / owner” quedó insuficiente.  
Ahora existe un carril intermedio real (`owner_pending`) que impacta Auth, Splash, Shell, módulo OWNER y seguridad.

Decisiones ya fijadas:
- email del claim = email autenticado,
- teléfono MVP opcional/sin verificación,
- validación automática antes de revisión manual,
- promoción a OWNER solo por backend,
- claims/custom claims solo por Admin SDK.

## 3. Problema que resuelve
- Ambigüedad sobre qué significa `owner_pending`.
- Interpretaciones inconsistentes entre capas.
- Riesgo de UX owner prematura.
- Riesgo de confundir `claimStatus` con permisos efectivos.
- Operación admin frágil sin traducción formal a roles.

## 4. User Stories (negocio)
- Como `CUSTOMER`, quiero reclamar sin convertirme automáticamente en OWNER.
- Como usuario en revisión, quiero entender claramente que sigo en etapa intermedia.
- Como OWNER aprobado, quiero acceso consistente sin fricción.
- Como admin, quiero que approve/reject tenga efecto de rol claro y trazable.
- Como plataforma, quiero un modelo auditable incluso con conflictos/duplicados.

## 5. Objetivo de negocio
Mantener arquitectura de roles comprensible, segura y escalable tras incorporar claims, evitando zonas grises entre “pendiente” y “aprobado”.

## 6. Alcance IN
- Incorporación formal de `owner_pending`.
- Ciclo canónico `CUSTOMER -> owner_pending -> OWNER`.
- Diferenciación `claimStatus` vs `roleStatus`.
- Reglas de entrada/salida de pending.
- Impacto en Auth/Splash/Shell/OWNER.
- Guardrails de navegación y permisos.
- Relación con conflicto, duplicado y rechazo.

## 7. Alcance OUT
- No reescribe de cero toda la arquitectura previa.
- No reemplaza detalles de 0126 a 0133; absorbe su impacto en el marco canónico de roles.

## 8. Supuestos
- `CUSTOMER` sigue siendo rol base.
- `OWNER` sigue siendo compuesto (incluye CUSTOMER).
- `owner_pending` es condición intermedia, no rol operativo pleno.
- Transiciones de rol: solo backend autorizado.
- MVP optimiza a un comercio principal por owner, sin bloquear evolución multi-merchant.

## 9. Dependencias
- TuM2-0054, 0053, 0064, 0125, 0126, 0127, 0128, 0131, 0133.
- Relación legal con 0100–0104.

## 10. Arquitectura propuesta
### Estado 1 — CUSTOMER
Usuario autenticado base, sin permisos owner operativos.

### Estado 2 — CUSTOMER + owner_pending
Claim activo vigente en circuito de validación/revisión.  
Mantiene capacidades base customer + contexto de revisión.

### Estado 3 — OWNER
Titularidad operativa aprobada y consolidada en backend/token.

## 11. Regla central de diseño
“Claim enviado o en revisión no equivale a ownership concedido.”

Ningún `claimStatus` otorga permisos OWNER por sí mismo.

## 12. Entrada a owner_pending
Se activa cuando existe claim válido y activo fuera de borrador (p.ej. `submitted`, `under_review`, `needs_more_info`, conflicto vivo).

No activa pending:
- draft no enviado,
- duplicado terminal sin caso útil,
- cancelado,
- rechazo definitivo sin otro claim activo.

## 13. Salida de owner_pending
Se desactiva cuando:
- promoción válida a OWNER,
- rechazo definitivo sin claims activos,
- cancelación,
- cierre terminal negativo.

No debe quedar pending residual.

## 14. Promoción a OWNER
Solo si:
- existe aprobación válida,
- backend consolida transición,
- token actualizado refleja OWNER.

Cliente no puede inferir ownership por estado local.

## 15. Relación claim status vs role status
Son dimensiones distintas.  
`claimStatus` informa avance del caso; `roleStatus` define permisos efectivos.

La traducción entre ambas debe ser explícita, backend-authoritative y no optimista en frontend.

## 16. Impacto en trust levels
`owner_pending` representa confianza intermedia de journey, no grant operativo.  
Puede mejorar contexto UX, pero no habilita recursos protegidos.

## 17. Impacto en permisos funcionales
- `CUSTOMER`: uso base + iniciar/seguir claim.
- `owner_pending`: seguimiento/acciones de claim (p.ej. more-info), sin operación owner plena.
- `OWNER`: acceso a módulo OWNER y recursos habilitados por política vigente.
- `CUSTOMER` con restricción de seguridad activa: acceso general de usuario final, pero sin iniciar nuevos claims, sin enviar reportes y sin facultades sensibles hasta revisión manual autorizada.

## 18. Impacto en navegación
La navegación debe contemplar tres superficies:
- customer normal,
- customer con contexto pending,
- owner plena.

No requiere app separada; sí guards y entry points coherentes.

## 19. Impacto en Auth, Shell y OWNER
Auth (0054):
- `getIdTokenResult(forceRefresh: true)` en splash/post-login.
- Capturar correctamente pending vs owner.
- Evitar estado local stale como fuente de verdad.

Shell (0053):
- pending como capa contextual sobre customer, no “modo owner”.

OWNER module (0064):
- distinguir sin ambigüedad: sin ownership / pending / owner aprobado.

## 20. Conflictos y duplicados
Con conflicto/disputa:
- nunca promoción automática a OWNER,
- `owner_pending` puede mantenerse solo como señal de caso vivo,
- sin grants por automatización optimista.

## 21. Seguridad (reglas obligatorias)
1. Enviar claim no concede permisos owner.
2. `owner_pending` no mapea a acceso owner pleno.
3. Cliente no decide rol efectivo.
4. Navegación manual no puede bypassear guards owner.
5. Promoción a OWNER única, explícita y auditable.
6. Conflictos nunca resuelven permisos automáticamente.
7. Restricciones por fraude/abuso se modelan como capacidad funcional restringida sobre cuentas `CUSTOMER`, no como rol nuevo.

## 22. Guardrails de costo
- Resolver estado de acceso desde señal resumida/token, evitando fan-out.
- Sin listeners permanentes cruzados claims+roles+merchants para guards.
- Sin polling agresivo de claim para decidir navegación.
- Claims detallados solo on-demand (seguimiento).

## 23. Datos impactados
- `users`
- `merchant_claims`
- vínculo `owner <-> merchant`
- custom claims de auth
- estado de shell y módulo owner
- guards y timestamps de transición

## 24. BDD / aceptación
- Dado `CUSTOMER`, cuando envía claim válido, entonces no pasa automáticamente a OWNER.
- Dado claim activo en revisión, cuando abre app, entonces ve estado pending y no owner pleno.
- Dado `owner_pending`, cuando entra a ruta owner operativa, entonces ve restricción contextual.
- Dado claim aprobado, cuando backend consolida y token refresca, entonces pasa a OWNER.
- Dado claim rechazado definitivo sin otros claims vivos, entonces pending se desactiva.

## 25. QA plan
- QA funcional: entrada/salida pending, promoción owner, rechazo/conflicto/more-info.
- QA auth: refresh token, consistencia claims/UI.
- QA seguridad: bypass rutas owner, grants indebidos, navegación manual.
- QA UX: claridad pending vs aprobado real.

## 26. Definition of Done
- `owner_pending` formalmente incorporado.
- Ciclo `CUSTOMER -> owner_pending -> OWNER` documentado.
- `claimStatus` y `roleStatus` diferenciados.
- Entrada/salida pending documentadas.
- Impacto en Auth/Shell/OWNER alineado.
- Conflictos, duplicados y rechazos cubiertos.

## 27. Rollout
1. Actualizar arquitectura canónica de roles (esta tarjeta).
2. Alinear 0054/0053/0064.
3. Ajustar lectura de estado real en login/splash/owner.
4. Validar con QA cruzado claims-auth-permisos.

## 28. Sincronización documental obligatoria
- `docs/storyscards/0004-role-segment-architecture.md`
- `docs/storyscards/0054-auth-complete.md`
- `docs/storyscards/0053-mobile-shell.md`
- `docs/storyscards/0064-owner-module-business.md`
- `docs/storyscards/0131-owner-claim-role-integration.md`

## 29. Cierre ejecutivo
TuM2 deja de modelar ownership como salto binario:
- un CUSTOMER puede reclamar,
- puede quedar `owner_pending`,
- y solo backend puede convertirlo en OWNER efectivo.

Esta actualización restaura a 0004 como fuente de verdad del ciclo de vida de acceso tras la épica de claims.
