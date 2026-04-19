# TuM2-0067 — Implementación técnica (OWNER señales operativas)

Estado: DONE

## Objetivo técnico
Implementar carga y mantenimiento de señal operativa manual OWNER con prioridad sobre cálculo automático de horarios, preservando el patrón dual-collection y minimizando costo Firestore.

## Alcance implementado
- OWNER-08 en mobile: alta/edición y desactivación de señal manual.
- Tipos MVP habilitados: `vacation`, `temporary_closure`, `delay`.
- Mensaje opcional con límite de 80 caracteres.
- Persistencia en `merchant_operational_signals/{merchantId}` (1 doc por comercio).
- Sincronización server-side de `merchant_public/{merchantId}` vía trigger.
- Regla de precedencia implementada:
  - `vacation` y `temporary_closure`: `isOpenNow=false` (force closed).
  - `delay`: conserva `isOpenNow` automático y agrega estado informativo.
  - sin señal activa: estado automático de horarios.

## Arquitectura aplicada
- Patrón dual-collection mantenido:
  - privada: `merchants`, `merchant_operational_signals`
  - pública: `merchant_public`
- Cliente mobile escribe solo `merchant_operational_signals`.
- `merchant_public` se actualiza exclusivamente desde Cloud Functions (Admin SDK).
- Lógica canónica de precedencia centralizada en:
  - `functions/src/lib/operationalSignals.ts`

## Colecciones impactadas
- `merchant_operational_signals/{merchantId}`
  - `merchantId`, `ownerUserId`, `signalType`, `isActive`, `message`, `forceClosed`, `updatedAt`, `updatedByUid`, `schemaVersion`
  - mantiene campos derivados existentes de horarios/guardias para compatibilidad.
- `merchant_public/{merchantId}`
  - `hasOperationalSignal`
  - `operationalSignalType`
  - `operationalSignalMessage`
  - `operationalSignalUpdatedAt`
  - `manualOverrideMode`
  - `operationalStatusLabel`
  - `isOpenNow` resuelto con precedencia

## Reglas Firestore actualizadas
- `merchant_public`: escritura cliente denegada (`allow write: if false`).
- `merchant_operational_signals`:
  - lectura/escritura solo owner del comercio o admin.
  - validación de enum `signalType`.
  - validación de `isActive`, `forceClosed`, `message <= 80`.
  - consistencia `merchantId` (path vs doc), `ownerUserId`, `updatedByUid`.
  - bloqueo de cambio owner sobre campos derivados backend.
  - no se permiten campos arbitrarios fuera de whitelist.

## Cloud Function / trigger agregado
- `onSignalsWriteSyncPublic` refactorizado:
  - usa función canónica de precedencia.
  - calcula payload público derivado.
  - evita writes no-op comparando estado normalizado before/after.
  - structured logs: `merchantId`, `signalType`, `overrideMode`, `forceClosed`, `projectionWriteSkipped`, `reason`.

## OWNER-08 (flujo mobile)
- Carga inicial con lectura única del doc.
- Formulario con selector de tipo + mensaje opcional + guardar.
- Botón explícito de desactivación.
- Estados manejados:
  - loading inicial
  - sin señal activa
  - señal activa precargada
  - guardando
  - éxito/error
  - validación inline (tipo requerido y largo mensaje)
  - permission denied
  - fallo de red/backend
- Sin listeners realtime permanentes.

## Costo Firestore / Functions
- 1 lectura al abrir OWNER-08 (`merchant_operational_signals/{merchantId}`).
- 1 escritura por guardar o desactivar.
- Sin polling ni cron adicional para esta tarjeta.
- Sin escrituras cliente duplicadas en colecciones públicas.
- Trigger con no-op write avoidance para evitar write amplification en `merchant_public`.

## Tests agregados/actualizados
- Functions:
  - `functions/src/lib/__tests__/operationalSignals.test.ts`
    - `vacation => isOpenNow=false`
    - `temporary_closure => isOpenNow=false`
    - `delay => preserva isOpenNow automático`
    - sin señal => usa automático
- Mobile:
  - `mobile/test/modules/owner/operational_signals_notifier_test.dart`
    - carga inicial sin señal y con señal
    - guardar `vacation`, `temporary_closure`, `delay`
    - limpiar señal
    - error de permisos
    - error de red

## Riesgos y deuda residual
- Reglas de seguridad: faltan tests automatizados de emulador para validar rule paths end-to-end (owner propio/ajeno, customer, anónimo).
- Persisten jobs heredados de actualización operativa nocturna fuera del alcance de 0067.
- Compatibilidad legacy de campos antiguos mantenida en lectura para migración progresiva.

## Checklist de producción
- [x] OWNER-08 conectado a Firebase real
- [x] Escritura cliente solo en `merchant_operational_signals`
- [x] `merchant_public` write-protected para cliente
- [x] Trigger server-side sincroniza proyección pública
- [x] `manual override > cálculo automático`
- [x] `delay` informativo (no fuerza cerrado)
- [x] no-op write avoidance en trigger
- [x] tests unitarios actualizados
- [x] `CLAUDE.md` actualizado
