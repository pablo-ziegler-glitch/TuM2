# TuM2-0124 — Mitigación operativa de guardias de farmacia

Estado: DONE  
PR: #59  
Fecha de cierre: 2026-04-09

## Resumen de implementación real (PR #59)

- Flujo operativo end-to-end implementado en Cloud Functions y mobile OWNER:
  - `reportPharmacyDutyIncident`
  - `getEligibleReplacementCandidates`
  - `createReassignmentRound`
  - `respondToReassignmentRequest`
  - `cancelReassignmentRound`
- Nuevas colecciones en schema: `pharmacy_duty_incidents`, `pharmacy_duty_reassignment_rounds`, `pharmacy_duty_reassignment_requests`.
- Estados de guardia y confianza pública integrados (`confidenceLevel`, `publicStatusLabel`) para degradar/recuperar visibilidad durante incidentes.
- Jobs programados para mitigación operativa:
  - recordatorios de confirmación de guardia,
  - expiración incremental de solicitudes pendientes.
- Optimización de costo aplicada desde diseño:
  - candidatas filtradas por `zoneId` + farmacia activa + distancia,
  - límite de candidatas por ronda configurable,
  - scans de jobs con límite por ciclo (sin barridos globales por ejecución).

---

## 1. Objetivo
Diseñar un sistema resiliente que permita prevenir, detectar y resolver cambios inesperados en farmacias de turno, garantizando continuidad operativa y preservando la confianza del dato público.

---

## 2. Contexto
Las farmacias pueden no cumplir una guardia por imprevistos. Actualmente no existe un mecanismo estructurado para reasignación rápida.

Impacto directo:
- Pérdida de confianza del usuario
- Información incorrecta en tiempo real
- Riesgo reputacional del producto

---

## 3. User Stories

OWNER (farmacia incidente):
"Quiero informar un problema y pedir cobertura rápidamente para no dejar mi zona sin guardia"

OWNER (farmacia receptora):
"Quiero aceptar o rechazar cubrir una guardia de forma clara y rápida"

CUSTOMER:
"Quiero ver información confiable sobre qué farmacia está de turno"

---

## 4. Alcance IN
- Confirmación preventiva de guardia
- Reporte de incidentes
- Selección múltiple de farmacias candidatas
- Radio configurable por admin (default 10 km)
- Invitaciones paralelas 1 a 1
- Aceptación/rechazo
- Primera aceptación gana
- Cancelación automática del resto
- Estado público degradado según confianza

## Alcance OUT
- Optimización logística avanzada
- Integraciones externas de salud

---

## 5. Supuestos
- Todas las farmacias tienen coordenadas válidas
- Existe densidad mínima de farmacias por zona
- Usuarios OWNER autenticados correctamente

---

## 6. Arquitectura propuesta

### Componentes
- Firestore
- Cloud Functions (orquestación)
- FCM (notificaciones)
- Remote Config (parámetros)

### Colecciones
- pharmacy_duties
- pharmacy_duty_incidents
- pharmacy_duty_reassignment_rounds
- pharmacy_duty_reassignment_requests
- admin_configs

### Flujo
1. Incidente reportado
2. Selección de candidatas
3. Creación de requests paralelos
4. Respuestas individuales
5. Primera aceptación → cierre
6. Cancelación automática del resto

---

## 7. Frontend

### Stack
- Flutter
- Riverpod
- go_router

### Flujos críticos
- Reporte incidente
- Selección candidatas
- Tracking solicitudes
- Aceptación cobertura

### Estados UI
- pendiente
- aceptada
- rechazada
- expirada
- cancelada

### Offline
- soporte limitado
- no confirmar mutaciones sin backend

---

## 8. Backend

### Callables
- reportPharmacyDutyIncident
- createReassignmentRound
- respondToReassignmentRequest
- closeReassignmentRound

### Validaciones
- ownership
- zona
- distancia
- estado del duty
- concurrencia

### Concurrencia
- transacción Firestore
- lock por round

---

## 9. Seguridad

### Riesgos
- IDOR
- doble aceptación
- spoofing de distancia
- spam

### Controles
- App Check
- validación server-side
- límites por usuario
- idempotencia

---

## 10. UX / Producto

Principios:
- velocidad
- claridad
- baja fricción

Microcopy clave:
- “Solicitar cobertura”
- “La primera que acepte toma la guardia”
- “Esperando respuesta”

---

## 11. Datos impactados

Campos nuevos en pharmacy_duties:
- confirmationStatus
- confidenceLevel
- replacementMerchantId

---

## 12. APIs / Servicios

- Firebase Auth
- Firestore
- Cloud Functions
- FCM

---

## 13. BDD (Gherkin)

Scenario: farmacia acepta cobertura
Given una ronda abierta
When una farmacia acepta
Then el turno se reasigna
And las demás solicitudes se cancelan

---

## 14. Analytics

Eventos:
- incident_reported
- reassignment_requested
- reassignment_accepted

KPI:
- tiempo de recuperación
- % guardias confirmadas

---

## 15. Riesgos

- concurrencia
- falta de adopción
- zonas con baja densidad

---

## 16. Edge cases

- sin candidatas
- todas rechazan
- aceptación simultánea
- request expira

---

## 17. QA Plan

- tests unitarios
- integración
- E2E
- seguridad

---

## 18. Definition of Done

- flujo completo funcional
- validaciones backend
- UI operativa
- logs activos

---

## 19. Rollout

- feature flag
- staging
- piloto
- producción gradual

---

## 20. Costos (optimización obligatoria)

- queries acotadas por zona
- límite de candidatas
- evitar listeners globales
- batch operations

---

## 21. Decisión final de diseño

Se adopta Alternativa 3:
- selección múltiple
- invitaciones paralelas
- primera aceptación gana
- cancelación automática

---
