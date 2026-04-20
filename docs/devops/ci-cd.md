# TuM2 CI/CD productivo (GitHub Actions + Firebase + GCP)

Documento operativo de referencia para CI/CD del proyecto TuM2.

## Estado verificado (2026-04-10)
- Environments existentes: `dev`, `staging`, `prod`.
- `staging` y `prod` tienen `required_reviewers` y `branch_policy` activos.
- `dev` no requiere aprobación manual.

## 1) Arquitectura final

### Workflows
- `ci-pr.yml`: validación de Pull Requests (sin deploy).
- `deploy-dev.yml`: deploy automático a `dev` desde `develop`.
- `deploy-staging.yml`: deploy a `staging` con aprobación manual.
- `deploy-prod.yml`: deploy a `prod` con aprobación manual.
- `firestore-cost-guard.yml`: auditoría independiente de costo Firestore.

### Ambientes canónicos (obligatorios)
- `dev`: `tum2-dev-6283d`
- `staging`: `tum2-staging-45c83`
- `prod`: `tum2-prod-bc9b4`

`tum2-dev` (sin sufijo) está explícitamente bloqueado por validaciones.

## 2) Qué valida cada workflow

### `ci-pr.yml`
- Trigger: `pull_request` (sin filtro por paths para no saltear CI completo).
- Ejecuta detección de módulos impactados y reporta alcance en el summary.
- Flutter mobile (`mobile/**`):
  - `flutter pub get`
  - `dart format --set-exit-if-changed .`
  - `flutter analyze`
  - `flutter test --dart-define=ENV=staging`
- Flutter web admin (`web/**`):
  - `flutter pub get`
  - `dart format --set-exit-if-changed .`
  - `flutter analyze`
  - `flutter test`
- Functions (`functions/**`, `schema/**`):
  - `npm ci`
  - `npm run lint`
  - `npm run build`
  - `npm test`
- Config Firebase (siempre):
  - `jq empty firestore.indexes.json`
  - `jq empty firebase.json`
  - `jq empty .firebaserc`
  - validación anti-proyecto huérfano (`tum2-dev`).

### Deploys (`deploy-dev/staging/prod`)
- Trigger:
  - `push` a la rama del ambiente (`develop`, `staging`, `main`)
  - `workflow_dispatch` (manual, restringido por rama)
- Deploy selectivo por cambios:
  - `firestore:rules`
  - `firestore:indexes`
  - `storage`
  - `functions`
  - `hosting:web`
  - `hosting:admin`
- Preflight fuerte:
  - valida rama correcta para manual dispatch
  - valida proyecto destino
  - valida modo de auth (OIDC o key fallback)
  - valida variables y secretos obligatorios
- Hardening:
  - `permissions` mínimas
  - `concurrency` por ambiente
  - `timeout-minutes`
  - `set -euo pipefail`
  - summary de despliegue (commit, branch, project, targets, auth mode)
  - artefacto `deploy-manifest-<env>-<run_id>` para auditoría/trace
  - smoke check liviano post-deploy (`hosting:sites:list`, `functions:list`)

### `firestore-cost-guard.yml`
- Trigger:
  - `schedule` diario (`03:15 UTC`)
  - `workflow_dispatch` con input de ambiente y archivo de umbrales
- Independiente de deploy.
- Soporta umbrales desde `docs/ops/firestore_cost_thresholds.json`.
- Produce artefactos JSON por ambiente.
- Falla temprano si no hay auth configurada.

## 3) Seguridad: OIDC + fallback

### Modo recomendado (producción)
OIDC + Workload Identity Federation (sin keys JSON largas).

Variables requeridas por environment (`dev`, `staging`, `prod`):
- `GCP_WIF_PROVIDER`
- `GCP_DEPLOYER_SERVICE_ACCOUNT`

Variables requeridas para cost guard (repo-level o según política):
- `GCP_MONITORING_WIF_PROVIDER`
- `GCP_MONITORING_SERVICE_ACCOUNT`

### Fallback temporal (si aún no migraste)
Secrets por environment:
- `GCP_SA_KEY_DEV`
- `GCP_SA_KEY_STAGING`
- `GCP_SA_KEY_PROD`
- `FIREBASE_SERVICE_ACCOUNT` (compatibilidad legacy, también aceptado por workflows)
- `FIREBASE_PROJECT_ID` (opcional, usado para detectar drift de ambiente)

Secret cost guard:
- `GCP_MONITORING_SA_KEY`

Los workflows eligen OIDC si encuentra vars de WIF; si no, usan key fallback.

## 4) Configuración obligatoria en GitHub

## 4.1 Environments
Crear:
- `dev`
- `staging`
- `prod`

## 4.2 Protección manual
Configurar en `staging` y `prod`:
- `Required reviewers` (aprobación manual real).
- Recomendado: `can_admins_bypass = false`.

## 4.3 Variables por environment
`dev`:
- `HOSTING_SITE_WEB_DEV`
- `HOSTING_SITE_ADMIN_DEV`
- `MOBILE_WEB_APP_ID_DEV`
- `ADMIN_WEB_APP_ID_DEV`
- `ADMIN_WEB_APP_CHECK_SITE_KEY_DEV`
- `GCP_WIF_PROVIDER` (si OIDC)
- `GCP_DEPLOYER_SERVICE_ACCOUNT` (si OIDC)

`staging`:
- `HOSTING_SITE_WEB_STAGING`
- `HOSTING_SITE_ADMIN_STAGING`
- `ADMIN_WEB_APP_CHECK_SITE_KEY_STAGING`
- `GCP_WIF_PROVIDER` (si OIDC)
- `GCP_DEPLOYER_SERVICE_ACCOUNT` (si OIDC)

`prod`:
- `HOSTING_SITE_WEB_PROD`
- `HOSTING_SITE_ADMIN_PROD`
- `ADMIN_WEB_APP_CHECK_SITE_KEY_PROD`
- `GCP_WIF_PROVIDER` (si OIDC)
- `GCP_DEPLOYER_SERVICE_ACCOUNT` (si OIDC)

## 4.4 Secrets por environment (fallback)
- `GCP_SA_KEY_DEV`
- `GCP_SA_KEY_STAGING`
- `GCP_SA_KEY_PROD`
- `FIREBASE_SERVICE_ACCOUNT` (alternativa legacy)
- `FIREBASE_PROJECT_ID` (opcional para validación de drift)

## 4.5 Variables/secret para cost guard
- `GCP_MONITORING_WIF_PROVIDER` + `GCP_MONITORING_SERVICE_ACCOUNT` (OIDC recomendado)
- `GCP_MONITORING_SA_KEY` (fallback)

## 5) Operación diaria

### PR
1. Abrir PR hacia `develop`.
2. Esperar `CI PR Validation`.
3. Corregir si falla.
4. Merge.

### Deploy dev
1. Merge a `develop`.
2. Corre `Deploy Dev` automáticamente.

### Deploy staging/prod
1. Push a `staging` o `main` (o `workflow_dispatch` en rama correcta).
2. Workflow queda en espera por environment.
3. Reviewer aprueba.
4. Continua deploy.

## 6) Rollback operativo

### Opción 1 (recomendada): rollback por Git
1. Identificar commit estable anterior.
2. Revertir en la rama del ambiente.
3. Push.
4. El workflow redeploya ese estado.

### Opción 2: deploy selectivo manual
Usar `workflow_dispatch` con commit/branch estable y `force_full_deploy=true` solo si es necesario.

### Opción 3: rollback de Hosting por CLI
Si necesitás rollback rápido de Hosting sin tocar Functions:
1. Identificar versión estable en Firebase Hosting.
2. Publicar esa versión al canal/site correspondiente.
3. Ejecutar deploy normal en el siguiente commit para re-sincronizar IaC del repo.

## 7) Estrategia de costos
- CI no se saltea completo: evita merge ciego.
- Jobs pesados corren solo cuando el módulo cambió (paths-filter por job).
- Deploys son selectivos por targets.
- Cost guard separado de deploy.
- Preflights tempranos para no gastar runner en compilaciones inútiles.

## 8) Troubleshooting rápido
- Error `Missing auth config`: faltan vars OIDC o secret fallback.
- Error `Proyecto huérfano`: se intentó usar `tum2-dev`.
- Error en `Validate hosting variables`: faltan variables de hosting.
- Error en `firebase deploy`: permisos IAM insuficientes de la identidad usada.

## 9) Pendientes recomendados (no bloqueantes)
- Forzar `prevent_self_review=true` en `staging/prod` si el proceso de release requiere doble control.
- Publicar tablero de métricas históricas con reportes del cost guard.
- Evaluar smoke checks HTTP para Hosting usando URL canónica por ambiente.
