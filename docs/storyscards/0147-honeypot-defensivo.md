# TuM2-0147 — Honeypot defensivo y detección temprana de abuso

Estado: IN_PROGRESS (corte técnico 2026-04-26)  
Prioridad: P0  
Dependencias: Firebase Hosting rewrites, Cloud Functions v2 HTTP, Cloud Logging

## Objetivo
Implementar un honeypot defensivo low-interaction para detectar scanners, scraping y probes sobre rutas admin/internal/claims/secrets, sin tocar datos reales ni generar costo innecesario en Firestore.

## Contexto
TuM2 opera sobre Firebase Hosting + Cloud Functions TypeScript. El objetivo de esta tarjeta es observar tráfico hostil temprano con costo bajo y sin abrir superficie adicional en datos sensibles.

## Problema
Los scanners suelen explorar rutas conocidas (`/.env`, `/wp-login.php`, `/api/admin/*`) y endpoints internos no públicos. Sin un trap centralizado, estos eventos quedan dispersos y sin señal de riesgo uniforme.

## Alcance IN
- Cloud Function HTTP v2 `securityTrap`.
- Clasificación de rutas trampa por categoría.
- Redacción segura de request sin PII.
- Hash HMAC de IP y user-agent.
- Detección de honeytokens falsos.
- Logging estructurado en Cloud Logging.
- Rewrites de Hosting en targets `web` y `admin` antes del catch-all.
- Tests unitarios para clasificador, redacción y hashing.

## Alcance OUT
- Bloqueo automático, CAPTCHA o Cloud Armor.
- Firestore aggregation o BigQuery export.
- Dashboard admin específico.
- Cambios en roles/custom claims.
- Cambios en `merchant_public`, `merchant_claims`, `merchants`, `users`.
- Cambios en Flutter mobile/web/admin.

## Arquitectura
Bot/scanner -> Firebase Hosting -> rewrites de rutas trampa -> Function `securityTrap` -> clasificación + redacción + hashing + honeytoken detection -> log estructurado `security_honeypot_hit` en Cloud Logging -> métricas/alertas recomendadas.

`securityTrap` responde siempre `404` con payload genérico `{"error":"not_found"}`.

## Rutas trampa
Se configuraron rewrites dedicadas en ambos targets (`web`, `admin`) para:
- scanner genérico (`/wp-login.php`, `/wp-admin/**`, `/phpmyadmin/**`, `/.git/**`, etc.)
- probes admin falsos (`/api/admin/*`, `/admin/*.csv`)
- probes internos falsos (`/api/internal/*`, `/api/private/*`)
- probes de claims falsos (`/api/claims/*`, `/api/merchant-claims/*`)
- probes de secretos (`/.env`, `/.env.production`, `/service-account.json`, etc.)

Precedencia de clasificación implementada:
`secret_probe` > `claim_probe` > `tum2_internal_probe` > `tum2_admin_probe` > `scanner_generic` > `unknown_trap`.

## Honeytokens
Tokens detectados:
- `tum2_honey_key_001`
- `tum2_fake_admin_export_token`
- `tum2_fake_claim_reveal_token`
- `honey_merchant_do_not_use`
- `honey_claim_probe`
- `honey_internal_admin_probe`

Si aparece cualquiera:
- `honeytokenDetected=true`
- `severity=critical`
- `riskScore=100`

No se persiste el token completo en logs; solo `honeytokenType`.

## Logging
Evento estructurado: `security_honeypot_hit`  
`schemaVersion=1`

Campos principales:
- entorno y projectId
- categoría, severidad y score de riesgo
- método/path/normalizedPath
- `ipHash` y `userAgentHash`
- familia de user-agent
- presencia de headers sensibles (booleanos)
- `queryKeyCount` y `queryKeys` (sin values)
- `bodySizeBytes` y `bodyCaptured=false`
- estado 404 + timestamp

Se usó `console.log(JSON.stringify(...))` para mantener consistencia con callables actuales del repo.

## Redacción y privacidad
Nunca se loguea:
- IP cruda
- valores de Authorization/Cookie/AppCheck
- query values
- body completo
- headers completos

Solo se registran metadatos mínimos y hashes HMAC.

## Firestore / costo
- `securityTrap` no hace lecturas Firestore por hit.
- `securityTrap` no hace escrituras Firestore por hit.
- Sin listeners ni polling.
- Sin Auth lookup.
- Sin llamadas externas.

Diseño orientado a costo: procesamiento en memoria + log estructurado.

## Seguridad / threat model
- Cubre reconocimiento temprano de rutas sensibles simuladas.
- Reduce fuga de información con respuesta uniforme 404.
- Evita almacenar secretos accidentalmente.
- Incluye kill switch por `SECURITY_TRAP_ENABLED=false`.
- Secreto de hashing vía `SECURITY_HASH_SECRET` (fallback solo cuando `FUNCTIONS_EMULATOR=true`).

## Testing
Unit tests agregados:
- `functions/src/security/__tests__/trapClassifier.test.ts`
- `functions/src/security/__tests__/redaction.test.ts`
- `functions/src/security/__tests__/hash.test.ts`

Validación ejecutada (cobertura CI local):
- `cd functions && npm run lint` ✅
- `cd functions && npm run build` ✅
- `cd functions && npm test` ✅
- `cd functions && npm run guard:claim-categories:allowlist` ✅
- `cd functions && npm run test:rules` ✅
- `cd mobile && flutter analyze` ✅
- `cd mobile && flutter test --dart-define=ENV=staging` ✅
- `cd web && flutter analyze` ✅
- `cd web && flutter test` ✅

## DevOps / CI
Se actualizó `functions/package.json` para incluir los tests de `security` en `npm test`.

## Métricas y alertas sugeridas
Logs-based metrics sugeridas:
- `security_honeypot_hits_total`
- `security_honeypot_hits_high_total`
- `security_honeypot_hits_critical_total`
- `security_honeypot_honeytoken_detected_total`
- `security_honeypot_admin_probe_total`
- `security_honeypot_secret_probe_total`
- `security_honeypot_claim_probe_total`

Alertas sugeridas:
- P2: más de 50 hits en 10 minutos.
- P1: más de 10 hits `high` en 10 minutos.
- P0: cualquier `honeytokenDetected=true`.
- P0: más de 5 `secret_probe` en 5 minutos desde mismo `ipHash`.

## Runbook operativo
1. Confirmar pico en métrica y revisar filtros por `trapCategory`, `severity`, `ipHash`.
2. Correlacionar por `userAgentHash` y `queryKeys` para identificar patrón.
3. Si hay honeytoken (`critical`), escalar incidente de seguridad y revisar exposición de rutas internas.
4. Si el tráfico afecta costos/latencia, activar mitigación de plataforma (fuera de esta tarjeta).
5. Si se requiere pausa táctica, usar kill switch `SECURITY_TRAP_ENABLED=false` manteniendo respuesta 404.

## Riesgos
- Smoke test HTTP del endpoint honeypot en emulador pendiente de corrida manual de entorno.
- Validación de workflow `firestore-cost-guard` en modo completo pendiente de credenciales GCP de monitoreo (OIDC o service account key).

## Rollout
1. Revisar secret manager/env vars: `SECURITY_HASH_SECRET`, `SECURITY_HASH_SECRET_VERSION`.
2. Deploy controlado a dev.
3. Verificar logs `security_honeypot_hit`.
4. Propagar a staging y luego prod.

## Definition of Done
- [x] Existe Cloud Function HTTP v2 `securityTrap`.
- [x] `securityTrap` exportada desde `functions/src/index.ts`.
- [x] Rewrites trampa en `firebase.json`.
- [x] Rewrites antes del catch-all en `web` y `admin`.
- [x] Rutas trampa responden 404 (implementación).
- [x] Log estructurado `security_honeypot_hit`.
- [x] `ipHash` y `userAgentHash` con HMAC.
- [x] Sin IP cruda, sin headers sensibles, sin body/query values.
- [x] Sin reads/writes de Firestore por hit.
- [x] Honeytokens elevan a `critical`.
- [x] Tests unitarios nuevos agregados.
- [x] `functions/package.json` actualizado para incluir nuevos tests.
- [x] `npm run build` global pasa.
- [x] `npm run lint` pasa.
- [x] `npm test` global pasa.
- [x] Storycard creada.
- [x] `CLAUDE.md` actualizado.

## Estado real de implementación
Implementación técnica de honeypot completada en código y configuración.  
CI local validada en functions/mobile/web; pendiente smoke manual del endpoint y verificación del workflow de cost guard con credenciales de monitoreo.
