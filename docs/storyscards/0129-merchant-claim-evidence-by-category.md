# TuM2-0129 — Evidencia y documentación por categoría de comercio

Estado: TODO  
Prioridad: P0 (MVP crítica)

## Objetivo
Definir documentación mínima y adicional por categoría para mantener un flujo simple y confiable.

## Base común obligatoria (MVP)
- Nombre y apellido.
- Email autenticado.
- Teléfono opcional (sin verificación MVP).
- Rol declarado.
- Comercio reclamado.
- Foto de fachada.
- Una prueba documental básica de vínculo.

## Variaciones por categoría
- Comercios generales: fachada + constancia/documento comercial equivalente.
- Farmacias: evidencia más estricta y dato habilitante cuando aplique.
- Veterinarias: evidencia reforzada similar a comercios regulados/intermedios.

## Alcance IN
- Matriz por categoría.
- Reglas de obligatoriedad.
- Copy/UX de carga de evidencia.
- Señales que fuerzan revisión manual extra.

## Dependencias
- TuM2-0126 flujo claim.
- TuM2-0127 validación automática.
- TuM2-0128 revisión manual.
- TuM2-0100/0102 tratamiento legal de evidencia.

## Guardrails de costo Firestore
- Metadata de reglas por categoría cacheable con TTL en cliente/admin.
- No descargar evidencia binaria en listados.
- Validaciones que usen solo campos necesarios; evitar lecturas de documentos completos cuando no haga falta.
