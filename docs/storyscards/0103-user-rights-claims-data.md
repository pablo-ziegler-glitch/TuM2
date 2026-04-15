# TuM2-0103 — Derechos del usuario sobre datos del claim

Estado propuesto: UPDATE REQUIRED  
Prioridad: P0  
Motivo de actualización: impacto directo de la épica de claims sobre acceso, rectificación, actualización, desistimiento, limitación y eventual eliminación de datos/evidencia bajo límites legítimos de seguridad, auditoría, conflicto y antifraude.

## 1. Objetivo
Definir qué derechos conserva el usuario sobre información y evidencia de su claim, y bajo qué condiciones TuM2 puede atender, limitar o diferir solicitudes cuando existan motivos legítimos del sistema.

Debe responder con claridad:
- qué puede consultar,
- qué puede corregir/completar,
- cuándo puede desistir,
- cuándo puede pedir eliminación o limitación,
- y qué límites aplican por seguridad, trazabilidad y conflictos.

## 2. Contexto
El claim maneja datos más sensibles que un perfil normal (identidad, evidencia visual/documental, estados de revisión, flags de conflicto/duplicado, trazas internas).

Esto exige una política más fina que “podés editar tu información”:
- hay datos corregibles,
- hay trazas históricas no reescribibles,
- hay retención razonable por seguridad/auditoría/conflicto.

## 3. Problema que resuelve
- Evita promesas absolutas incompatibles con operación segura.
- Evita improvisación en soporte/admin ante pedidos de corrección o supresión.
- Evita confundir “corregir” con “borrar todo el expediente”.
- Da marco claro para equilibrio entre derechos del usuario e integridad del proceso.

## 4. User Stories
- Usuario: tener control razonable sobre su información de claim.
- Usuario: poder corregir errores materiales sin rehacer todo innecesariamente.
- Usuario: entender por qué ciertos datos pueden conservarse temporalmente.
- Plataforma: respetar derechos sin romper seguridad, antifraude ni trazabilidad.

## 5. Objetivo de negocio
Ofrecer derechos reales, proporcionados y accionables, sin comprometer:
- resolución de conflictos,
- auditoría,
- prevención de fraude,
- consistencia histórica del claim.

## 6. Alcance IN
- Derecho a consultar estado e información principal del propio claim.
- Derecho a corregir/actualizar/completar cuando corresponda.
- Derecho a desistir/cerrar claim cuando aplique.
- Derecho a solicitar eliminación/limitación con restricciones legítimas.
- Límites por seguridad, auditoría, fraude y conflicto.
- Distinción datos editables vs trazas no editables.
- Lineamientos UX para comunicar derechos y límites.

## 7. Alcance OUT
- No reemplaza privacidad, términos, consentimiento ni retención.
- No define por sí sola todos los procedimientos operativos legales complejos.

## 8. Supuestos
- Usuario solo ejerce derechos sobre su propia información.
- Claim puede permanecer activo en revisión.
- Evidencia puede ser sensible.
- Puede haber conflicto/disputa que requiera conservar expediente.
- Ciertas trazas internas deben preservarse.

## 9. Dependencias
- 0100, 0101, 0102, 0104.
- 0126, 0128, 0130, 0133.
- Relación con Auth/perfil para datos derivados de cuenta.

## 10. Arquitectura propuesta del documento
Estructura recomendada:
- derecho a conocer estado/expediente propio,
- derecho a corregir/actualizar,
- derecho a completar evidencia,
- derecho a desistir,
- derecho a solicitar eliminación/limitación (con límites),
- límites por seguridad/fraude/conflicto/auditoría,
- canales razonables de ejercicio.

## 11. Derecho a conocer estado del propio claim
El usuario puede ver su estado y pasos pendientes (`under_review`, `needs_more_info`, conflicto, aprobado, rechazado, etc.).

Límite:
no implica acceso a notas internas sensibles, lógica antifraude ni datos de terceros.

## 12. Derecho a consultar información aportada
Debe poder conocer, con alcance razonable:
- datos declarados,
- comercio/categoría reclamados,
- estado de evidencia,
- material principal asociado al expediente.

No implica descarga irrestricta de todo ni exposición de información archivada sensible fuera de controles.

## 13. Derecho a corregir información inexacta
Debe poder corregir/completar cuando tenga sentido operativo (error de carga, evidencia equivocada, dato declarativo incorrecto).

Regla:
corregir no debe borrar trazabilidad histórica del caso.

## 14. Derecho a completar evidencia
Si hay `needs_more_info`, el usuario puede aportar evidencia adicional/corregida para sostener su solicitud.

## 15. Derecho a retirar/desistir del claim
Debe existir posibilidad de retirar/cancelar cuando el flujo lo permita.

Límite:
desistir no implica borrado instantáneo absoluto de toda traza; aplica política de conservación razonable.

## 16. Derecho a solicitar eliminación/supresión
Se reconoce posibilidad de solicitud, pero no como derecho absoluto e inmediato en todos los casos.

Puede limitarse/diferirse por:
- seguridad,
- auditoría,
- prevención de fraude,
- conflicto/disputa,
- cumplimiento aplicable.

## 17. Derecho a limitar tratamiento (ciertos casos)
Puede contemplarse limitación/revisión del tratamiento cuando haya inexactitud u objeción razonable.

Límite:
no debe impedir trazas mínimas necesarias para seguridad y decisiones ya tomadas.

## 18. Datos editables vs trazas no editables
Potencialmente corregibles:
- datos declarativos,
- evidencia adicional en ventanas habilitadas,
- ciertos campos antes de decisión final.

No reescribibles libremente:
- historial de estados,
- decisiones y timestamps,
- flags de conflicto/duplicado,
- auditorías de acceso,
- trazas internas de seguridad.

## 19. Límite por conflicto/disputa
En conflicto activo, ciertos pedidos pueden limitarse temporalmente para preservar expediente íntegro y trazable.

## 20. Límite por antifraude/seguridad
Pedidos de eliminación/modificación pueden diferirse si comprometen detección de abuso, duplicados o protección del sistema.

## 21. Derecho a no acceder a datos de terceros
El usuario conserva derechos sobre su claim, pero no sobre información de otros reclamantes/owner ni notas internas sensibles de terceros.

## 22. Relación con evidencia/documentos
Acceso razonable sí; pero no implica:
- edición ilimitada de documentos ya revisados,
- descarga irrestricta en cualquier contexto,
- eliminación inmediata si caso sigue vivo o en retención legítima.

## 23. Relación con 0100/0101/0102/0104
0103 debe ser coherente con:
- 0100: marco general de tratamiento,
- 0101: reglas del proceso claim,
- 0102: consentimiento específico de evidencia,
- 0104: conservación y acceso interno.

Consentimiento no equivale a renuncia total de derechos.

## 24. Frontend y UX
El producto debe ofrecer puntos claros para:
- ver estado,
- responder more-info/corregir,
- desistir cuando aplique,
- entender límites de eliminación/restricción,
- acceder a documentos legales relacionados.

## 25. Backend y operación
Debe ser compatible con backend que:
- conserva trazas históricas,
- acepta correcciones razonables,
- cierra claims sin borrar todo de inmediato,
- responde solicitudes sin comprometer seguridad/auditoría.

## 26. Seguridad (principio)
Derechos del usuario y seguridad conviven:
- corregir ≠ reescribir historia,
- eliminar ≠ borrar toda traza siempre,
- acceso propio ≠ acceso a terceros.

## 27. Microcopy sugerido
- “Podés revisar el estado y la información principal de tu solicitud”.
- “Si te pedimos más información, vas a poder completarla desde acá”.
- “Si querés desistir del reclamo, podés hacerlo”.
- “Algunos datos o documentos pueden conservarse por un tiempo razonable por seguridad y auditoría”.
- “No compartimos información de otros reclamantes”.

## 28. Datos impactados
Marco de derechos sobre:
- datos declarados,
- evidencia visual/documental,
- estado e historial básico del claim,
- solicitudes de corrección/more-info/desistimiento,
- trazas mínimas de auditoría/seguridad.

## 29. Riesgos si no se actualiza
- promesas de control imposibles de cumplir,
- falta de vías claras para corregir/desistir,
- confusión entre corrección y supresión total,
- debilidad ante fraude/conflicto por falta de trazabilidad,
- soporte sin marco claro de actuación.

## 30. Edge cases
- documento equivocado,
- desistimiento antes de resolución,
- rechazo + solicitud de eliminación,
- conflicto activo con necesidad de conservación,
- solicitud de acceso a estado sin revelar terceros,
- corrección después de primera revisión.

## 31. BDD / aceptación
- Dado claim activo, cuando usuario consulta expediente, entonces ve estado e información principal propia sin datos de terceros.
- Dado more-info, cuando usuario entra al flujo, entonces puede corregir/completar razonablemente.
- Dado desistimiento permitido, cuando usuario lo ejecuta, entonces claim se cierra sin prometer borrado instantáneo total.
- Dado solicitud de eliminación, cuando plataforma evalúa, entonces puede limitar/diferir por motivos legítimos.
- Dado conflicto, cuando usuario revisa caso, entonces entiende estado sin acceder a info de otros reclamantes.

## 32. QA plan
- QA documental: coherencia entre derechos prometidos y operación real.
- QA funcional: corrección, more-info, desistimiento, visibilidad de estado.
- QA límites: claridad sobre eliminación no absoluta.
- QA seguridad: protección de terceros.
- QA consistencia: 0100/0101/0102/0104 + 0130/0133.

## 33. Definition of Done
- Derechos del usuario sobre claim definidos explícitamente.
- Consulta, corrección, completitud y desistimiento contemplados.
- Límites por seguridad/fraude/conflicto/auditoría explicitados.
- Protección de información de terceros formalizada.
- Alineación con 0100, 0101, 0102 y 0104 cerrada.

## 34. Plan de rollout
1. Actualizar 0103 en documentación interna.
2. Revisar consistencia con 0100/0101/0102/0104.
3. Diseñar puntos UX para consulta/corrección/desistimiento.
4. Validar wording final contra implementación real antes de producción.

## 35. Sincronización documental obligatoria
- `docs/storyscards/0103-user-rights-claims-data.md`
- `docs/storyscards/0100-privacy-policy.md`
- `docs/storyscards/0101-terms-and-conditions.md`
- `docs/storyscards/0102-claim-evidence-consent.md`
- `docs/storyscards/0104-sensitive-data-retention-access.md`
- `docs/storyscards/0126-merchant-claim-flow.md`
- `docs/storyscards/0130-merchant-claim-sensitive-data-protection.md`
- `docs/storyscards/0133-merchant-claim-conflicts-and-duplicates.md`

## 36. Cierre ejecutivo
Con esta actualización, 0103 reconoce derechos reales del usuario sobre su claim, dentro de límites compatibles con seguridad y trazabilidad:
- consultar estado e información principal,
- corregir o completar cuando corresponda,
- desistir en casos habilitados,
- solicitar revisión/eliminación con condiciones razonables,
- sin reescribir historia del expediente ni exigir borrado absoluto inmediato cuando existan motivos legítimos.
