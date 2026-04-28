# TuM2-0029 — Checklist de activación AUTH-01 (normal / mundialista)

Estado: operativo  
Última actualización: 2026-04-27

## 1. Objetivo

Controlar la variante visual de `AUTH-01 Splash` en mobile sin redeploy, usando Remote Config.

## 2. Claves Remote Config usadas por mobile

- `splash_brand_variant` (string)
- `mobile_worldcup_enabled` (bool)

Regla de resolución en app:
- Si `mobile_worldcup_enabled=true`, gana mundialista.
- Si `mobile_worldcup_enabled=false`, se usa `splash_brand_variant`.
- Valores mundialista válidos en `splash_brand_variant`: `mundialista` o `worldcup`.
- Fallback por error de fetch: `original`.

## 3. Ambientes válidos

- `tum2-dev-6283d`
- `tum2-staging-45c83`
- `tum2-prod-bc9b4`

No usar `tum2-dev` (huérfano).

## 4. Matriz de valores por modo

Modo normal:
- `splash_brand_variant=original`
- `mobile_worldcup_enabled=false`

Modo mundialista:
- `splash_brand_variant=mundialista`
- `mobile_worldcup_enabled=true`

Rollback inmediato a normal:
- `mobile_worldcup_enabled=false`
- `splash_brand_variant=original`

## 5. Checklist de publicación por ambiente

1. Entrar al proyecto Firebase correcto (`dev`, `staging` o `prod`).
2. Abrir Remote Config y confirmar existencia de ambas claves.
3. Cargar valores según matriz de la sección 4.
4. Publicar template.
5. Esperar propagación (hasta intervalo de fetch del cliente).
6. Verificar en app mobile:
   - Splash muestra logo correcto.
   - Copy sigue igual (`Lo que necesitás, en tu zona.` / `Preparando tu zona...`).
   - Timeout guest-first sigue operativo.
7. Verificar que no hay impacto de costo:
   - Sin lecturas Firestore nuevas.
   - Sin listeners nuevos.
   - Sin llamadas a Cloud Functions para splash.

## 6. Verificación funcional mínima (QA)

- Instalación limpia -> abrir app -> validar variante de splash.
- App ya instalada -> cerrar y abrir -> validar misma variante.
- Simular mala red -> timeout muestra CTA `Explorar sin iniciar sesión`.
- Cambiar de mundialista a normal y revalidar en el mismo ambiente.

## 7. Checklist de release recomendado

Orden:
1. `tum2-dev-6283d`
2. `tum2-staging-45c83`
3. `tum2-prod-bc9b4`

Promoción a siguiente ambiente solo si dev/staging validan:
- render correcto,
- navegación AUTH-01 sin bloqueo,
- sin regresión en onboarding guest-first.
