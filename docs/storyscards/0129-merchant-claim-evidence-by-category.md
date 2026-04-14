# TuM2-0129 — Evidencia y documentación por categoría de comercio

Estado propuesto: TODO  
Prioridad: P0 (MVP crítica)  
Épica madre: TuM2-0125 — Reclamo de titularidad de comercio  
Depende de: TuM2-0126 — Flujo de claim del comercio, TuM2-0127 — Validación automática inicial de claims, TuM2-0128 — Revisión manual de claims en Admin Web

## 1. Objetivo
Definir la matriz canónica de evidencia requerida para reclamar titularidad de un comercio, diferenciada por categoría, para:
- mantener el claim simple,
- sostener confianza probatoria razonable,
- evitar pedir documentación excesiva.

Principio: pedir lo mínimo suficiente para decidir con seguridad razonable.

## 2. Contexto
No todos los rubros tienen el mismo riesgo/regulación/tipo de prueba.  
El claim debe adaptarse por categoría sin volverse burocrático.

Decisiones ya cerradas:
- email de claim = email autenticado,
- teléfono opcional sin verificación en MVP,
- validación automática previa a revisión manual,
- tratamiento reforzado de sensibles (TuM2-0130).

## 3. Problema que resuelve
- Inconsistencia de requisitos entre casos.
- Fricción excesiva por pedir “todo a todos”.
- Baja capacidad antifraude por pedir demasiado poco.
- Revisión manual caótica sin estándar por rubro.
- Menor precisión de auto-validación sin requisitos claros.
- Recolección de datos sensibles irrelevantes.

## 4. Objetivo de negocio
Equilibrar:
- claridad para usuario,
- consistencia para Admin,
- suficiencia probatoria,
- baja fricción,
- alineación con auto-validación,
- minimización de datos.

## 5. Alcance IN
- Evidencia mínima común para todos los claims.
- Evidencia adicional por categoría.
- Diferencia entre obligatorio, opcional y refuerzo.
- Criterios de suficiencia documental.
- Criterios de derivación manual por rubro.
- Lineamientos UX para carga de evidencia.
- Lineamientos de minimización de datos.
- Criterios para pedidos posteriores de más información.

## 6. Alcance OUT
- Flujo completo usuario (TuM2-0126).
- Lógica de validación automática (TuM2-0127).
- Operatoria completa Admin (TuM2-0128).
- Diseño técnico de cifrado/fingerprints (TuM2-0130).
- Integración roles/owner_pending (TuM2-0131).
- Phone verification fase 2 (TuM2-0132).
- Disputas complejas completas (TuM2-0133).

## 7. Supuestos
- Usuario autenticado.
- Email del claim tomado de auth.
- Teléfono opcional en MVP.
- Comercio identificado o referenciado de forma controlada.
- Flujo corto y simple.
- No pedir documentación innecesaria.

Categorías canónicas MVP:
- Farmacias
- Kioscos
- Almacenes
- Veterinarias
- Tiendas de comida al paso
- Casas de comida / Rotiserías
- Gomerías

Excluidas de MVP:
- Panaderías
- Confiterías

## 8. Dependencias
Funcionales:
- TuM2-0126, 0127, 0128, 0130, 0133.

Cruzadas:
- TuM2-0004, 0054, 0100 a 0104.

## 9. Principios rectores
- Base común para todos los rubros.
- Exigencia gradual según riesgo/categoría.
- No pedir DNI/bancarios/invasivos por defecto.
- Separar evidencia mínima de evidencia de refuerzo.
- Pedir más solo cuando agrega valor real.
- No igualar rubros regulados con rubros simples.
- No recolectar sensibles irrelevantes.
- Matriz simple de explicar, operar y auditar.

## 10. Arquitectura de evidencia
Modelo de 3 capas:
1. Capa A: evidencia mínima común.
2. Capa B: evidencia específica por categoría.
3. Capa C: evidencia de refuerzo (solo conflicto, revisión manual o alta sensibilidad).

## 11. Evidencia mínima común obligatoria
### Identificación solicitante
- email autenticado,
- nombre/apellido si aplica por perfil,
- rol declarado: dueño/co-dueño/representante autorizado.

### Identificación comercio
- comercio seleccionado/identificado,
- `categoryId`,
- referencia territorial suficiente (`zoneId`/dirección referencial).

### Evidencia visual obligatoria
- foto de fachada del comercio.

### Evidencia documental mínima
- al menos una prueba básica de vínculo con el local.

Ejemplos válidos:
- habilitación del local,
- factura de servicio del local,
- contrato de alquiler del local,
- constancia tributaria/comercial vinculada,
- documento comercial con vínculo operativo identificable.

### Consentimiento
- aceptación de tratamiento de documentación,
- declaración de legitimidad del reclamo.

## 12. Qué no pedir por defecto en MVP
- selfie con DNI,
- frente/dorso DNI como requisito base,
- datos bancarios,
- poder notarial complejo,
- múltiples comprobantes redundantes,
- formularios fiscales extensos,
- documentación altamente sensible sin justificación.

## 13. Matriz por categoría (MVP)
### Kioscos
- Obligatorio: fachada + 1 prueba documental básica.
- Riesgo: bajo/medio.
- Derivación manual: inconsistencia, duplicado, owner existente o vínculo débil.

### Almacenes
- Obligatorio: fachada + 1 prueba documental básica.
- Riesgo: bajo/medio.
- Derivación manual: ambigüedad local/nombre, conflicto o reclamo previo.

### Tiendas de comida al paso
- Obligatorio: fachada + 1 prueba documental básica.
- Riesgo: medio.
- Derivación manual: identidad visual débil, vínculo documental ambiguo o múltiples locales similares.

### Casas de comida / Rotiserías
- Obligatorio: fachada + 1 prueba documental básica.
- Riesgo: medio.
- Derivación manual: colisión entre marca visible y documentación, ubicación confusa o claim previo.

### Gomerías
- Obligatorio: fachada + 1 prueba documental básica.
- Riesgo: bajo/medio.
- Derivación manual: local no identificable, documentación genérica o conflicto.

### Veterinarias
- Obligatorio: fachada + 1 prueba documental básica.
- Refuerzo recomendado cuando hay dudas.
- Riesgo: medio/alto.
- Derivación manual: recomendada ante ambigüedad, sensibilidad o conflicto.

### Farmacias
- Obligatorio: fachada + prueba documental más sólida que rubros simples.
- Refuerzo: documentación habilitante/complementaria cuando corresponda.
- Riesgo: alto.
- Derivación manual: recomendada por defecto o en la mayoría de casos.

## 14. Regla de suficiencia mínima
Un claim está “documentalmente completo” solo si tiene:
- comercio identificado,
- categoría definida,
- rol declarado,
- foto de fachada,
- una prueba documental mínima de vínculo,
- consentimiento aceptado,
- coherencia básica comercio-evidencia.

Si falta alguno: no puede considerarse limpio para validación positiva.

## 15. Evidencia de refuerzo
Solo pedir en:
- conflicto,
- revisión manual,
- rubro sensible,
- inconsistencia documental,
- dudas de legitimidad.

Ejemplos:
- segunda foto del comercio,
- foto interior,
- documento adicional del establecimiento,
- prueba complementaria de vínculo,
- autorización de representante.

## 16. Evidencia prohibida o desaconsejada como requisito base
- selfie con DNI,
- video obligatorio,
- múltiples servicios obligatorios,
- documentos tributarios complejos para todos,
- documentación financiera,
- “subí todo lo que tengas”.

## 17. Relación con validación automática (TuM2-0127)
Permite validar automáticamente:
- presencia de evidencia mínima,
- faltantes por categoría,
- incompletitud documental,
- necesidad de carril manual reforzado por rubro.

No permite asumir:
- que adjuntar un archivo equivale a legitimidad definitiva,
- que todos los rubros tienen el mismo estándar.

## 18. Relación con revisión manual (TuM2-0128)
Admin debe poder ver por claim:
- qué era obligatorio para ese rubro,
- qué está presente,
- qué falta,
- qué evidencia pesa más para decidir.

## 19. Frontend (definición funcional)
Objetivo UX: breve, claro y guiado.

Reglas:
- no mostrar lista infinita inicial,
- adaptar requisitos por categoría,
- separar obligatorio/opcional,
- explicar por qué se pide cada evidencia.

Microcopy sugerido:
- “Subí una foto del frente del comercio”
- “Subí una prueba que muestre tu vínculo con el local”
- “Según el tipo de comercio, puede que necesitemos revisar documentación adicional”
- “Pedimos solo la información necesaria para validar tu reclamo”

## 20. Backend (definición funcional)
Debe:
- interpretar categoría canónica,
- validar evidencia obligatoria esperada,
- marcar faltantes,
- marcar si requiere revisión manual reforzada.

Guardrails:
- no exigir lo mismo a todos,
- no aceptar claim limpio sin mínimo documental,
- no confundir archivo presente con suficiencia final,
- no duplicar almacenamiento/exposición de adjuntos.

## 21. Seguridad y minimización de datos
Principio: mejor seguridad = recolectar menos.

Reglas:
- pedir solo lo necesario,
- no exponer adjuntos públicamente,
- no mostrar documentación completa en listados,
- no reutilizar evidencia sensible fuera de propósito claim,
- alineación obligatoria con consentimiento/privacidad/retención.

## 22. Datos impactados
En `merchant_claims`:
- categoría del comercio,
- tipos de evidencia requeridos,
- completitud documental,
- faltantes de evidencia,
- flags de revisión reforzada,
- clasificación de evidencia subida,
- observaciones de suficiencia.

Vinculados:
- referencias a comercio y usuario,
- adjuntos/documentos,
- razones de `needs_more_info` o conflicto.

## 23. Reglas de negocio detalladas
- Base común obligatoria para todos.
- Fachada obligatoria para todo rubro MVP.
- Una prueba documental mínima de vínculo obligatoria.
- La categoría modifica exigencia.
- Rubros sensibles no usan mismo carril documental que rubros simples.
- Ausencia de obligatorio dispara `needs_more_info`/freno equivalente.
- Documento presente no implica aprobación automática.
- Admin revisa contra estándar por categoría.
- Panaderías/Confiterías fuera de MVP.

## 24. Analytics y KPI
Eventos:
- `merchant_claim_evidence_step_viewed`
- `merchant_claim_facade_uploaded`
- `merchant_claim_document_uploaded`
- `merchant_claim_additional_evidence_requested`
- `merchant_claim_missing_evidence_detected`
- `merchant_claim_evidence_completed`

KPI:
- completitud documental por categoría,
- abandono en paso de evidencia,
- % claims suficientes al primer envío,
- % `needs_more_info` por categoría,
- tiempo de resolución por categoría,
- tasa de derivación manual por rubro.

North Star local:
% de claims con evidencia mínima suficiente en primer intento sin fricción excesiva.

## 25. Edge cases
- Categoría seleccionada errónea.
- Evidencia sugiere categoría distinta.
- Fachada genérica/no verificable.
- Documento sin vínculo claro al local.
- Nombre comercial distinto al documento.
- Farmacia/veterinaria con evidencia plausible pero incompleta.
- Comercio sin cartel visible o con homónimos cercanos.
- Reclamante representante (no dueño directo).
- Exceso de evidencia irrelevante.
- Claim en revisión que recibe evidencia nueva.

## 26. QA plan
- QA funcional: matriz por categoría, obligatoriedad correcta, opcional vs refuerzo.
- QA UX: comprensión de requisitos, claridad de copy, mensajes de error accionables.
- QA seguridad: no exposición indebida, no recolección excesiva.
- QA integración: coherencia con 0126/0127/0128/0130/0133.
- QA costo: evitar uploads redundantes y operaciones innecesarias.

## 27. Definition of Done
- Base común de evidencia cerrada.
- Criterio mínimo por categoría MVP definido.
- Obligatorio vs refuerzo formalizado.
- Rubros sensibles con carril más estricto documentado.
- Integración con validación automática y revisión manual formalizada.
- Minimización de datos aplicada.
- Edge cases principales cubiertos.
- Lista para implementación sin contradicciones.

## 28. Plan de rollout
Fase 1: cierre de matriz con 0126/0127/0128.  
Fase 2: implementación UI dinámica + reglas mínimas por categoría.  
Fase 3: medición de abandono/more-info/saturación manual/calidad evidencia.  
Fase 4: ajuste por rubro si queda demasiado exigente, laxo o costoso.

## 29. Documentos a sincronizar
Crear/mantener alineados:
- `docs/storyscards/0129-merchant-claim-evidence-by-category.md`
- `docs/storyscards/0126-merchant-claim-flow.md`
- `docs/storyscards/0127-merchant-claim-auto-validation.md`
- `docs/storyscards/0128-admin-merchant-claims-review.md`
- `docs/storyscards/0130-merchant-claim-sensitive-data-protection.md`
- `docs/storyscards/0133-merchant-claim-conflicts-and-duplicates.md`

Actualizar por impacto:
- `docs/storyscards/0100-privacy-policy.md`
- `docs/storyscards/0101-terms-and-conditions.md`
- `docs/storyscards/0102-claim-evidence-consent.md`
- `docs/storyscards/0104-sensitive-data-retention-access.md`
- `docs/storyscards/0054-auth-complete.md`
- `docs/storyscards/0064-owner-module-business.md`

## 30. Cierre ejecutivo
TuM2-0129 define el estándar documental MVP para no caer en extremos:
- ni pedir demasiado y romper conversión,
- ni pedir tan poco que debilite legitimidad.

Definición final:
- base común mínima,
- fachada obligatoria,
- prueba documental mínima obligatoria,
- endurecimiento por categoría solo cuando corresponde,
- mayor cuidado para farmacias/veterinarias,
- flujo liviano para rubros simples,
- refuerzo solo ante dudas/conflicto/sensibilidad,
- minimización estricta de datos.
