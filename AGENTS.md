# TuM2 — Reglas de ejecución para agentes

Estas reglas son **restricción de arquitectura de primer nivel** para cualquier agente que modifique este repositorio: Codex, Claude Code, asistentes automáticos o cualquier herramienta de generación/edición de código, documentación, configuración o assets.

Este archivo tiene prioridad operativa para ejecución de agentes. Para contexto extendido consultar:

- `CLAUDE.md`
- `ARCHITECTURE.md`
- `PRD-MVP.md`
- `docs/storyscards/`
- `docs/ops/ANTI_MOCK_SCREEN_INVENTORY.md`

---

## 1) Restricción principal: costo Firestore

Todo diseño, refactor o feature debe incluir explícitamente:

- minimización de lecturas Firestore
- eliminación de listeners innecesarios
- uso obligatorio de límites (`limit`) y/o paginación real
- evitar queries amplias sin scope (`zoneId`, `visibilityStatus`, `categoryId`, `status`, `merchantId`, `userId` o filtros equivalentes)
- preferencia por cache + TTL/control de invalidez frente a realtime permanente
- evitar polling/refetch agresivo
- reducción de writes redundantes en Cloud Functions
- no-op write avoidance en triggers/proyecciones
- diseño orientado a costo desde el inicio

Si una propuesta rompe esto, se considera **error crítico con impacto económico**.

---

## 2) Reglas no negociables de arquitectura

- Patrón dual-collection obligatorio: `merchants` privado + `merchant_public` proyección pública.
- `merchant_public` nunca se escribe desde cliente; solo Cloud Functions con Admin SDK.
- Custom claims solo vía Admin SDK en Cloud Functions.
- Transiciones de rol, claim, visibilidad, verificación o estado sensible: backend-only.
- Contribuciones anónimas con `ipHash`, nunca IP cruda.
- Campos canónicos: usar `zoneId` y `categoryId`.
- Evitar `zone` / `category` salvo compatibilidad legacy documentada y acotada.
- Campos derivados como `isOpenNow`, `isOnDutyToday`, `sortBoost` y señales públicas se calculan server-side.

---

## 3) Ambientes válidos

Ambientes Firebase canónicos:

- `tum2-dev-6283d`
- `tum2-staging-45c83`
- `tum2-prod-bc9b4`

No usar:

- `tum2-dev`

Ese proyecto es huérfano y no debe aparecer en código, documentación, workflows, scripts ni configuración.

---

## 4) Branching, PRs y protección de ramas

- Nunca crear PRs contra `main`.
- Nunca crear PRs contra `staging`.
- Todo PR generado por agentes debe apuntar a `develop`, salvo instrucción humana explícita y excepcional.
- No pushear directo a `main`, `staging` ni `develop`.
- Crear siempre una rama feature/fix desde `develop`.

Formato recomendado de rama:

```txt
codex/tum2-XXXX-descripcion-corta
```

Ejemplos:

```txt
codex/tum2-0065-owner-products
codex/tum2-0130-claim-sensitive-data
codex/tum2-xxxx-docs-agents-rules
```

Formato recomendado de PR:

```txt
TuM2-XXXX: descripción corta
```

Todo PR debe incluir:

- resumen funcional
- cambios técnicos
- impacto en Firestore reads/writes
- impacto en seguridad/reglas/auth
- tests ejecutados
- documentación actualizada
- riesgos/deuda restante

---

## 5) Documentación obligatoria

Todo cambio asociado a una tarjeta debe actualizar:

- `docs/storyscards/<ID>.md`
- `CLAUDE.md` si cambia estado, backlog, deuda, arquitectura, ambiente, flujo operativo o decisión canónica
- `ARCHITECTURE.md` si cambia arquitectura, datos, reglas, funciones, colecciones, índices o permisos
- `PRD-MVP.md` si cambia alcance funcional del MVP
- `VISION.md` si cambia posicionamiento/producto
- `ROADMAP.md` si cambia orden, bloqueo o fase
- `PROMPT-PLAYBOOK.md` si cambia metodología de trabajo con agentes
- `docs/ops/ANTI_MOCK_SCREEN_INVENTORY.md` si agrega, cambia, diseña, implementa o cierra una pantalla/funcionalidad

No se considera completo un PR que cambia comportamiento productivo sin documentación correspondiente.

---

## 6) Regla anti-mock obligatoria

Antes de implementar, cerrar o declarar DONE cualquier pantalla o funcionalidad, el agente debe consultar:

```txt
./docs/ops/ANTI_MOCK_SCREEN_INVENTORY.md
```

Reglas:

- Para tarjetas marcadas como DONE o implementadas, no se aceptan mocks, fakes, stubs ni datos hardcodeados como sustituto de integración real.
- Si una pantalla queda con datos mock temporales, la tarjeta debe quedar explícitamente `IN_PROGRESS`, `TODO`, `real_data_partial` o `blocked_backend`.
- No usar listas hardcodeadas cuando exista colección real o fuente canónica.
- No marcar una pantalla como `done_real_data` si depende de backend, reglas, Cloud Functions, índices o contratos pendientes.
- Cada pantalla nueva o modificada debe tener entrada o actualización en `docs/ops/ANTI_MOCK_SCREEN_INVENTORY.md`.
- Si la funcionalidad requiere pantallas nuevas, el inventario debe indicar si está `Listo para Stitch` y si requiere `Prompt Stitch`.

Excepción válida:

- Tests unitarios, widget tests o tests de integración pueden usar mocks controlados, pero nunca como implementación productiva.

---

## 7) Feature flags y rollback

Toda feature mayor, flujo sensible o cambio con impacto en UX/producto debe considerar Remote Config.

Obligatorio para:

- módulos OWNER nuevos
- claims
- admin review
- analytics nuevos
- cambios de búsqueda/mapa/farmacias de turno
- importaciones o procesos batch
- cambios que puedan aumentar costo Firestore

Cada feature flag debe tener:

- nombre estable en snake_case
- default seguro
- comportamiento fallback
- plan de rollback sin redeploy
- documentación en la storycard correspondiente

---

## 8) Cloud Functions, callables y App Check

- Todo callable nuevo debe definir explícitamente si requiere App Check.
- En staging/prod, los callables admin o sensibles deben usar `enforceAppCheck: true`.
- No agregar callables admin con `enforceAppCheck: false` salvo justificación documentada y temporal.
- Toda validación crítica debe correr server-side.
- Validar auth, custom claims, ownership y permisos dentro de la Function.
- No confiar en validaciones de cliente como única barrera.
- Usar structured logs sin PII cruda.
- Jobs programados deben procesar en lotes acotados y con cursor/checkpoint.
- Evitar jobs con N lecturas secuenciales sobre colecciones crecientes.

---

## 9) Claims y datos sensibles

Reglas obligatorias para `merchant_claims` y flujos relacionados:

- Email del claim = email autenticado actual.
- No crear campo alternativo de email en MVP.
- Teléfono en MVP: opcional y sin verificación.
- Verificación telefónica queda fuera de MVP; fase 2.
- Todo claim pasa primero por validación automática.
- Casos dudosos, conflictivos, inconsistentes o riesgosos pasan a revisión manual.
- Enviar claim no convierte automáticamente en OWNER.
- `owner_pending` tiene permisos limitados.
- `OWNER` solo se asigna por backend autorizado vía Admin SDK.

Datos sensibles:

- No guardar PII cruda innecesaria.
- No duplicar sensibles en colecciones públicas o de alta lectura.
- No exponer sensibles completos en listados admin.
- Usar masking por defecto.
- Reveal temporal solo con permiso, razón y auditoría.
- Usar cifrado reversible para datos que requieran revisión humana.
- Usar hash/fingerprint para matching, dedupe y antifraude.
- Evidencia documental se carga y consulta on-demand; nunca en listados masivos.

---

## 10) Auth, roles y sesión

- Roles canónicos: `CUSTOMER`, `OWNER`, `ADMIN`.
- `OWNER` incluye capacidades `CUSTOMER`; no implementar switch manual de sesión.
- `owner_pending` es estado/claim especial, no OWNER pleno.
- Custom claims solo se escriben con Admin SDK en Cloud Functions.
- Nunca modificar claims desde cliente.
- Splash y post-login deben forzar refresh de token cuando aplique: `getIdTokenResult(forceRefresh: true)`.
- Logout debe limpiar FirebaseAuth, storage local de sesión y providers Riverpod.
- No resolver permisos con múltiples lecturas en cascada por pantalla.
- Preferir estado resumido cacheado con TTL para shell/guards.

---

## 11) Reglas de consulta Firestore por dominio

### `merchant_public`

- Consultar siempre con scope: `zoneId`, `visibilityStatus`, `categoryId`, `isOpenNow` o filtros equivalentes.
- Usar `limit`.
- No hacer full scans.
- No crear listeners globales de comercios.

### `merchant_claims`

- Admin: filtros obligatorios por `status` + `zoneId` o equivalente.
- Usuario final: consultar solo claim activo o últimos N con `limit`.
- No listeners globales.
- No scans para dedupe; usar claves normalizadas/indexadas y `limit`.

### `pharmacy_duties`

- Consultar por `zoneId + date + status`.
- No hidratar comercios uno por uno sin batch/control.
- Mantener timezone operativo UTC-3.

### `zones`

- Leer desde colección real `zones`.
- No hardcodear barrios/localidades/provincias.
- Cachear con TTL porque es metadata de baja mutación.

### Admin

- Tablas siempre paginadas por cursor.
- Cargar detalle on-demand.
- No cargar evidencia, blobs o payloads pesados en listados.

---

## 12) Rubros MVP canónicos

Rubros incluidos en MVP:

- Farmacias
- Kioscos
- Almacenes
- Veterinarias
- Tiendas de comida al paso
- Casas de comida / Rotiserías
- Gomerías
- Panaderías
- Confiterías

Los agentes deben usar esta lista como fuente operativa para pantallas, prompts Stitch, seeds, filtros, tests, documentación, assets y analytics.

---

## 13) UX y producto

- Estrategia guest-first: no forzar login para explorar valor público.
- Login solo a demanda para acciones protegidas.
- Prioridad UX: resultado útil en menos de 3 segundos cuando sea viable.
- Estados obligatorios en pantallas productivas:
  - loading
  - empty
  - error recuperable
  - permission denied
  - offline / red inestable cuando aplique
  - fallback claro si falta ubicación
- Microcopy en español, tono cercano, útil, claro y confiable.
- No usar lenguaje técnico o legalista en pantallas operativas.

---

## 14) Flutter y arquitectura cliente

Stack canónico:

- Flutter Mobile
- Flutter Web pública
- Flutter Web Admin
- `go_router ^13`
- `flutter_riverpod ^2.5`

Reglas:

- No introducir otro gestor de estado sin decisión explícita.
- Evitar listeners permanentes salvo necesidad justificada.
- Providers deben invalidarse correctamente en logout.
- Flujos críticos deben manejar loading, success, empty, error, permission denied y retry.
- No guardar secretos en app.
- No confiar permisos al cliente.
- No exponer datos sensibles completos.
- No asumir rol sin token/claim actualizado.

---

## 15) Testing mínimo obligatorio

Todo PR debe declarar tests ejecutados.

Según impacto, agregar o actualizar:

- Unit tests Flutter para notifiers/services/mappers.
- Widget tests para estados críticos.
- Tests de Cloud Functions para lógica derivada, validaciones y no-op writes.
- Tests de reglas Firestore con emulador para permisos owner/customer/admin/anónimo.
- Tests de claims para duplicados, conflictos, owner_pending y transición a OWNER.
- Tests de costo lógico:
  - no listeners nuevos innecesarios
  - queries con `limit`
  - paginación real
  - no scans globales
- E2E/manual checklist cuando toque auth, claims, owner, admin o farmacias.

---

## 16) Validaciones antes de abrir PR

Antes de abrir PR, ejecutar lo que aplique.

Flutter:

```bash
flutter analyze
flutter test
```

Functions:

```bash
npm run lint
npm run build
npm test
```

Firebase/config:

- Validar `firestore.indexes.json` sin comentarios JSON.
- Validar Firestore Rules si fueron modificadas.
- Validar que no se use proyecto Firebase huérfano.
- Validar que no se agregaron secretos al repo.

Docs:

- Verificar storycard actualizada.
- Verificar `CLAUDE.md` actualizado si cambia estado/arquitectura/backlog.
- Verificar `docs/ops/ANTI_MOCK_SCREEN_INVENTORY.md` actualizado si cambia una pantalla o funcionalidad.

---

## 17) Secretos, PII y logging

- Nunca commitear secretos, service accounts, API keys privadas, tokens ni credenciales.
- No loguear PII cruda: email completo, teléfono, documento, dirección exacta del usuario, evidencia, IP cruda.
- IP cruda prohibida en persistencia; usar `ipHash`.
- Logs deben ser estructurados y contener IDs técnicos mínimos.
- Los errores mostrados al usuario no deben revelar detalles internos de permisos, reglas o infraestructura.

---

## 18) Storage y evidencia documental

- No cargar evidencia documental en listados.
- Usar metadata mínima en Firestore.
- Acceso a archivos sensibles solo on-demand.
- Preferir URLs firmadas/temporales cuando corresponda.
- Validar tamaño, tipo MIME y extensión.
- Evitar duplicar adjuntos.
- Definir política de retención/TTL cuando aplique.

---

## 19) Restricciones de diseño visual y branding

- Usar paleta canónica TuM2.
- Mantener estilo flat vector, sin gradientes ni sombras para assets base.
- Logo base: solo azul, teal y neutral.
- El naranja cálido es acento UI; no usarlo en logo base.
- No introducir assets visuales fuera del sistema sin documentación.
- Versión mundialista/eventual debe mantenerse separada del branding base y no reemplazarlo silenciosamente.
