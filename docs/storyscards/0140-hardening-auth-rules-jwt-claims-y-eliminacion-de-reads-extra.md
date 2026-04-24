# TuM2-0140 — Hardening de Auth/Rules con JWT claims y eliminación de reads extra

Estado: DONE (cierre técnico 2026-04-23)  
Prioridad: P0  
Depende de: TuM2-0004, TuM2-0053, TuM2-0054, TuM2-0131

## Estado real de implementación (corte 2026-04-23)
- Rules hardeneadas para authz base por claims (`request.auth.token.role`, `owner_pending`, `admin`, `super_admin`) sin lectura de `users/{uid}` por request.
- Lectura de ownership acotada al recurso objetivo (`merchants/{merchantId}.ownerUserId`) para validaciones puntuales de propietario, removiendo dependencia de `merchantId/merchantIds` en JWT.
- Escritura de custom claims centralizada en función canónica backend `applyUserAccessClaims(...)` (Admin SDK only, idempotente, no-op avoidance, trazabilidad estructurada, limpieza de claims legacy).
- Flujos backend conectados a la función canónica: `onUserCreate`, `onboardingOwnerSubmit`, `assignOwnerRole`, `syncOwnerPendingAccess`.
- Claims mínimas canónicas activas: `role`, `owner_pending`, `admin`, `super_admin`, `access_version`, `claims_version`, `claims_updated_at` (+ preservación controlada de claims no gestionadas).
- Mobile auth/session refactorizado con parser tipado `AccessClaims`, refresh centralizado por motivo (`AuthSessionRefreshReason`) y `forceRefresh` en hitos críticos (splash, post-login, claim status, owner updates).
- UX prudente ante token stale/fallo refresh: sin grant indebido, retry explícito y navegación conservadora (no redirigir a rutas owner operativas sin token vigente).
- Analytics integrado en hitos de refresh y transición de acceso:
  - `token_force_refresh_started`
  - `token_force_refresh_succeeded`
  - `token_force_refresh_failed`
  - `role_transition_detected`
  - `owner_access_unlocked`

## Costo y seguridad (resultado)
- Eliminado acople de autorización frecuente al documento `users`.
- Eliminada dependencia de `merchantId` en JWT para authz operativa.
- Mantenido patrón dual-collection: `merchant_public` continúa backend-only.
- Sin listeners globales ni polling agresivo como workaround.
- No-op writes evitadas tanto en sync de claims como en refresh de sesión.

## Testing agregado
- Backend unit: `functions/src/lib/__tests__/accessClaims.test.ts` (parser/normalización/no-op/claims legacy/admin flags).
- Rules matrix: `functions/src/rules/__tests__/authClaimsMatrix.rules.test.ts` para anónimo/customer/owner_pending/owner/admin/super_admin en colecciones críticas (`users`, `merchants`, `merchant_public`, `merchant_schedules`, `merchant_operational_signals`, `merchant_products`, `merchant_claims`, `reports`, `admin_configs`, `pharmacy_duties`, `external_places`, `import_batches`).
- Mobile unit: `mobile/test/core/auth/access_claims_test.dart` (parser claims válidas/inválidas, fallback seguro).

## Riesgos residuales y follow-up
- Validar rollout de claims en cuentas administrativas legacy para asegurar presencia consistente de flags `admin/super_admin`.
- Ejecutar corrida E2E completa en `tum2-staging-45c83` para transición claim -> owner con fallos de red reales y refresh retry.
