# TuM2-0102 — Consentimiento de evidencia y documentación

Estado: TODO  
Prioridad: P0  
Motivo de actualización: impacto directo de la épica de claims sobre aceptación informada de evidencia visual/documental, revisión manual restringida, uso acotado y resguardo de adjuntos sensibles.

## 1. Objetivo
Actualizar el consentimiento específico del flujo de claim para que el usuario acepte de forma clara que la evidencia aportada:
- se usa para validar titularidad,
- puede pasar por validación automática y revisión manual restringida,
- no se publica automáticamente,
- puede requerir información adicional,
- y no garantiza aprobación ni acceso OWNER inmediato.

## 2. Contexto
El claim ahora procesa material sensible (fotos, documentos, observaciones, evidencia adicional), con controles de seguridad y revisión definidos por producto.

Este consentimiento complementa:
- 0100 (privacidad general),
- 0101 (reglas de uso y responsabilidades),
- 0104 (retención y acceso interno).

## 3. Problema que resuelve
- Evita consentimiento genérico insuficiente en el paso más sensible del claim.
- Evita confusión sobre uso/publicación de adjuntos.
- Da base explícita para revisión manual y pedidos de más información.
- Alinea UX de carga de evidencia con operación real del sistema.

## 4. User Stories
- Usuario: entender por qué se pide cada evidencia y cómo se usa.
- Usuario: saber que la evidencia no se hace pública por defecto.
- Plataforma: tener aceptación específica y trazable del uso de adjuntos.
- Admin: contar con base de consentimiento para revisión interna cuando aplica.

## 5. Objetivo de negocio
Lograr consentimiento informado, específico y proporcional en el punto correcto del journey, sin saturar UX ni depender solo de textos legales generales.

## 6. Alcance IN
- Consentimiento específico ligado al envío del claim.
- Cobertura de fotos, documentos y evidencia adicional.
- Finalidades acotadas de uso.
- Declaración de validación automática + posible revisión manual restringida.
- Aclaración de no publicación automática.
- Aclaración de no aprobación automática.
- Posibilidad de solicitar más información.
- Alineación con 0100/0101/0104/0130.

## 7. Alcance OUT
- No reemplaza privacidad, términos, derechos del usuario ni retención.
- No define en detalle técnico cifrado/masking ni matriz completa por categoría.

## 8. Supuestos
- Claim es flujo central del MVP.
- Usuario aporta evidencia visual/documental en la mayoría de casos.
- Puede haber rubros con refuerzo documental.
- Puede haber revisión manual en casos dudosos/conflictivos.

## 9. Dependencias
- 0126, 0127, 0128, 0129, 0130, 0133.
- 0100, 0101, 0103, 0104.

## 10. Arquitectura del consentimiento
Debe presentarse como consentimiento específico en el paso final del claim, cubriendo:
- qué evidencia se carga,
- para qué se usa,
- quién puede revisarla (bajo acceso restringido),
- no publicación automática,
- posibilidad de más info,
- ausencia de garantía de aprobación,
- referencia a documentos legales relacionados.

## 11. Evidencia cubierta
Debe incluir explícitamente:
- foto de fachada / evidencia visual principal,
- imágenes complementarias si aplica,
- documentos de vínculo,
- comprobantes/habilitaciones/constancias,
- observaciones del caso,
- evidencia adicional solicitada en more-info/revisión especial.

## 12. Finalidades declaradas
- Validar existencia del comercio y vínculo reclamado.
- Decidir avance/rechazo/more-info del claim.
- Detectar inconsistencias, duplicados y conflictos.
- Proteger integridad del sistema (seguridad/antifraude).
- Habilitar ownership solo si proceso resulta aprobado.

## 13. Validación automática y revisión manual
El consentimiento debe aclarar que la evidencia puede ser evaluada por:
- controles automáticos,
- personal autorizado cuando el caso lo requiera.

## 14. No publicación automática
Debe quedar claro que la evidencia del claim:
- no se publica automáticamente,
- no se vuelve contenido público del comercio por defecto,
- no se comparte con otros reclamantes.

## 15. Acceso interno restringido
La evidencia solo puede ser accedida por procesos/personas autorizadas cuando sea necesario para validar, resolver conflicto o proteger el sistema.

## 16. Resguardo y protección
Alineado con 0130, debe reflejar:
- protección proporcional de datos sensibles,
- exposición interna minimizada,
- visualización limitada/enmascarada cuando corresponda.

## 17. No garantía de aprobación
Cláusula explícita:
subir evidencia no garantiza aprobación del claim ni acceso owner inmediato.

## 18. Posibilidad de más información
Debe contemplar que TuM2 puede requerir evidencia adicional cuando lo aportado no alcance para decisión razonable.

## 19. Variabilidad por categoría
Debe dejar abierta la aplicación de matriz por categoría (0129):
- base común,
- refuerzo por rubro,
- evidencia adicional según contexto/riesgo.

## 20. Conflictos, duplicados y disputas
Debe contemplar uso de evidencia para tratamiento interno de:
- duplicados,
- conflictos,
- disputas de titularidad,
sin exposición de documentación a terceros reclamantes.

## 21. Minimización y proporcionalidad
Debe expresar principio de mínimo necesario:
- pedir base suficiente,
- refuerzo razonable cuando haga falta,
- evitar recolección indiscriminada.

## 22. Relación con 0100/0101/0103/0104
- 0100: marco general de tratamiento.
- 0101: reglas/obligaciones del claim.
- 0103: derechos del usuario.
- 0104: retención y acceso interno.

0102 aporta el consentimiento puntual del acto de carga/envío de evidencia.

## 23. Frontend y UX
Requisitos:
- consentimiento visible antes del envío,
- lenguaje claro y comprensible,
- asociado al acto de envío,
- resumen corto + acceso a textos completos.

## 24. Backend y operación
El consentimiento debe respaldar que backend:
- almacena evidencia,
- la procesa para validación,
- la relaciona con estados del claim,
- permite revisión autorizada cuando corresponde,
- aplica controles de seguridad y auditoría.

## 25. Seguridad (enunciado)
Debe dejar cubierto que la evidencia:
- entra en circuito protegido,
- no se hace pública por defecto,
- puede revisarse bajo acceso controlado,
- se resguarda con medidas razonables.

Sin promesas absolutas técnicamente falsas.

## 26. Microcopy sugerido
- “Usaremos esta documentación para validar tu reclamo”.
- “Tu evidencia se revisa de forma protegida y no se publica automáticamente”.
- “Podríamos pedirte más información si hace falta”.
- “Enviar esta documentación no garantiza la aprobación del reclamo”.

## 27. Datos impactados
Marco de consentimiento sobre:
- fotos/adjuntos/documentos,
- observaciones del claim,
- evidencia adicional,
- validaciones internas,
- acceso interno restringido,
- trazabilidad de aceptación del usuario.

## 28. Riesgos si no se actualiza
- aceptación ambigua,
- confusión sobre destino de archivos,
- debilidad ante revisión manual/more-info,
- desalineación entre UX y marco legal,
- menor confianza del usuario en paso de carga.

## 29. Edge cases
- pedido de más info tras envío inicial,
- rubro sensible con refuerzo documental,
- conflicto con múltiples revisiones internas,
- rechazo con conservación temporal razonable,
- usuario pregunta si su evidencia será pública,
- adjunto con datos más sensibles de lo necesario.

## 30. BDD / aceptación
- Dado usuario en paso final, cuando envía claim, entonces ve consentimiento claro sobre uso de evidencia.
- Dado evidencia subida, cuando acepta, entonces entiende uso para validación y no publicación automática.
- Dado revisión manual, cuando caso se deriva, entonces consentimiento ya lo contempla.
- Dado more-info, cuando se solicita ampliación, entonces consentimiento ya cubre esa posibilidad.
- Dado expectativa de aprobación automática, cuando revisa consentimiento, entonces encuentra cláusula explícita de no garantía.

## 31. QA plan
- QA documental: claridad y completitud del consentimiento.
- QA funcional: presencia/visibilidad en punto correcto del flujo.
- QA de consistencia: alineación con 0100/0101/0104/0130.
- QA UX: texto claro, no invisible ni excesivamente pesado.

## 32. Definition of Done
- Consentimiento cubre explícitamente evidencia visual/documental.
- Finalidades de uso claras y acotadas.
- Validación automática y revisión manual declaradas.
- No publicación automática explícita.
- Posibilidad de más info explícita.
- No aprobación automática explícita.
- Alineación cerrada con 0100, 0101, 0104 y 0130.

## 33. Plan de rollout
1. Actualizar 0102 interna.
2. Revisar coherencia con 0100/0101/0103/0104.
3. Ajustar UX del claim en punto de consentimiento.
4. Validar wording final contra implementación real antes de producción.

## 34. Sincronización documental obligatoria
- `docs/storyscards/0102-claim-evidence-consent.md`
- `docs/storyscards/0100-privacy-policy.md`
- `docs/storyscards/0101-terms-and-conditions.md`
- `docs/storyscards/0103-user-rights-claims-data.md`
- `docs/storyscards/0104-sensitive-data-retention-access.md`
- `docs/storyscards/0126-merchant-claim-flow.md`
- `docs/storyscards/0129-merchant-claim-evidence-by-category.md`
- `docs/storyscards/0130-merchant-claim-sensitive-data-protection.md`

## 35. Cierre ejecutivo
Con esta actualización, 0102 deja de ser un consentimiento genérico y pasa a cubrir explícitamente el acto de subir evidencia en claims:
- uso para validación del reclamo,
- revisión automática/manual restringida cuando corresponda,
- no publicación automática,
- posibilidad de pedir más información,
- y ausencia de garantía de aprobación o acceso owner inmediato.
