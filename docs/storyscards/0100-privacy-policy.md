# TuM2-0100 — Política de Privacidad (actualización claims)

Estado: TODO  
Prioridad: P0

## Objetivo
Actualizar Política de Privacidad para cubrir explícitamente el flujo de reclamo de titularidad.

## Debe incluir
- Tratamiento de datos del claim.
- Tratamiento de documentación/evidencia adjunta.
- Revisión manual interna cuando aplique.
- Cifrado, masking y controles de acceso.
- Uso para prevención de fraude y deduplicación.
- Plazos de retención.
- Acceso interno restringido por rol.

## Dependencias
- TuM2-0125, 0129, 0130.
- TuM2-0102 consentimiento de evidencia.
- TuM2-0104 retención y acceso interno.

## Guardrails de costo Firestore
- Definir minimización de datos: recolectar solo lo estrictamente necesario para validación.
- Evitar duplicación de datos sensibles en múltiples documentos.
