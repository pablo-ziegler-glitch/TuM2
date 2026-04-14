# TuM2-0102 — Consentimiento y tratamiento de evidencia documental (claims)

Estado: TODO  
Prioridad: P0

## Objetivo
Definir consentimiento explícito previo al envío de claim para tratamiento de evidencia/documentación.

## Debe incluir
- Aceptación explícita antes de enviar claim.
- Autorización de revisión por equipo interno.
- Tratamiento de adjuntos/documentos.
- Uso exclusivo para validación de titularidad y seguridad.
- Vínculo con políticas de retención y acceso restringido.

## Dependencias
- TuM2-0126 flujo claim.
- TuM2-0129 evidencia por categoría.
- TuM2-0130 seguridad de sensibles.
- TuM2-0100 y 0104.

## Guardrails de costo Firestore
- El consentimiento debe registrarse de forma compacta y versionada (sin writes redundantes por re-render o reingreso).
