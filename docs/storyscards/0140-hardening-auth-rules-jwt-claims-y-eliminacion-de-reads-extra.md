# TuM2-0140 — Hardening de Auth/Rules con JWT claims y eliminación de reads extra

## 1. Estado y metadata
- **Estado:** TODO
- **Prioridad:** P0
- **Dependencia madre:** TuM2-0135
- **Dependencias funcionales:** TuM2-0004, TuM2-0053, TuM2-0054, TuM2-0131

## 2. Objetivo
Eliminar lecturas innecesarias en Firestore Rules y centralizar la autorización sensible en JWT custom claims y flujos backend-only autorizados.

## 3. Contexto
Existe una deuda conocida explícita:
- `getUserRole()` en Rules realiza una lectura extra a Firestore por request en lugar de leer el JWT custom claim.

Eso penaliza costo y latencia en todas las rutas que dependen de esa verificación.

## 4. Problema
Cada lectura adicional en Rules:
- cuesta,
- agrega latencia,
- complica debugging,
- escala mal en features de alto tráfico.

## 5. Alcance IN
- reemplazo de lecturas de rol por claims JWT cuando corresponda,
- revisión de permisos `CUSTOMER`, `owner_pending`, `OWNER`, `ADMIN`,
- hardening de splash/post-login con `forceRefresh`,
- estrategia para transiciones claim → owner_pending → OWNER,
- reducción de fan-out de acceso.

## 6. Alcance OUT
- cambiar modelo de roles,
- claims escritos desde cliente,
- saltarse revisión admin.

## 7. Decisiones canónicas
### 7.1 Roles desde JWT
Cuando la autorización dependa de:
- `role`
- `owner_pending`
- `admin`
- `super_admin`
la fuente primaria debe ser el JWT claim.

### 7.2 Claims
Se siguen escribiendo **solo** con Admin SDK desde Cloud Functions.

### 7.3 Refresh de token
Obligatorio en:
- Splash,
- post-login,
- después de resoluciones admin que cambien acceso.

## 8. Arquitectura propuesta
```text
Admin / CF autorizada
      |
      v
setCustomUserClaims()
      |
      v
Firebase Auth ID token
      |
      v
request.auth.token en Rules
      |
      +--> cliente hace forceRefresh en hitos críticos
```

## 9. Frontend
- `getIdTokenResult(forceRefresh: true)` obligatorio en splash y post-login.
- guards basados en token refrescado.
- la UI no decide autoridad por inferencia blanda.
- claims visuales pueden usar doc estado + token refresh, sin listener permanente por defecto.

## 10. Backend
- Refactor de Rules para usar `request.auth.token.role` y equivalentes.
- Callables/triggers mantienen la fuente de verdad de claims en backend.
- Doc resumen opcional solo si una pantalla requiere un resumen adicional no representable en claims.

## 11. Seguridad
Beneficios:
- menos superficie de errores por lecturas de Rules,
- menos latencia,
- menos costo.

Riesgos:
- token viejo tras cambios de claims,
- UI mostrando acceso desactualizado si no refresca.

Mitigación:
- refresh explícito,
- tests E2E claim → admin → owner,
- timestamps / logs de actualización de claims.

## 12. UX / Producto
El usuario puede tener “permiso viejo” en el teléfono aunque backend ya lo haya aprobado o rechazado.  
Por eso se fuerza una actualización del token en momentos clave.

## 13. Datos impactados
- custom claims de Auth
- Firestore Rules
- `users`
- shell
- auth flow
- claim-role integration
- owner module access

## 14. APIs y servicios
- Firebase Auth
- Admin SDK
- Cloud Functions
- Firestore Rules
- Flutter auth/session layer

## 15. Analytics
Eventos:
- `token_force_refresh_started`
- `token_force_refresh_succeeded`
- `token_force_refresh_failed`
- `role_transition_detected`
- `owner_access_unlocked`

## 16. Testing
- parser/mapper de claims,
- guards por rol,
- callable/admin cambia claim,
- cliente refresca token,
- Rules leen token correcto,
- E2E claim enviado → admin aprueba → transición a OWNER.

## 17. DevOps
- staging obligatorio antes de prod,
- logs de cambios de claims,
- alarmas por fallas de refresh masivas.

## 18. Riesgos
- depender demasiado del doc `users`,
- olvidar refresh en algunos entry points,
- mezclar estado visual de claim con auth real.

## 19. Definition of Done
- Rules principales leen claims y no roles desde docs en cada request,
- `forceRefresh` cubre hitos críticos,
- tests claim→admin→owner en verde,
- costo por autorización reducido.

## 20. Rollout
1. refactor de Rules,
2. auth guards,
3. staging E2E,
4. prod gradual.

## 21. Checklist final
- [ ] lectura de rol desde JWT
- [ ] claims solo Admin SDK
- [ ] `forceRefresh` en splash/post-login/hitos
- [ ] tests E2E completos
- [ ] reducción de fan-out en Rules
