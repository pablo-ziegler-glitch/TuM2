# TuM2-0132 — Verificación de teléfono del usuario para fase 2

Estado: BACKLOG (Post-MVP)  
Prioridad: P1

## Objetivo
Agregar verificación de teléfono en fase 2 para flujos sensibles o de mayor riesgo.

## Definición actual
- MVP: teléfono opcional y sin verificación.
- Fase 2: habilitar verificación en claims sensibles, owner flows de mayor riesgo, disputas y políticas antifraude reforzadas.

## Alcance futuro
- Alta/verificación de teléfono.
- Re-verificación ante cambios.
- Uso como señal adicional de confianza.
- Integración en scoring de claims.

## Dependencias
- Auth/profile.
- TuM2-0127 validación de claims.
- TuM2-0100/0101/0102 legal y consentimiento.

## Guardrails de costo Firestore
- Estado de verificación desacoplado en perfil resumido (lectura única).
- Evitar refetch agresivo de estado de verificación.
- Solo registrar eventos de cambio de estado, no heartbeat de verificación.
