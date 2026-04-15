# TuM2-0101 — Términos y Condiciones

Estado propuesto: UPDATE REQUIRED  
Prioridad: P0  
Motivo de actualización: impacto directo de la épica de claims sobre declaraciones del usuario, legitimidad del reclamo, revisión administrativa, conflictos y acceso al rol OWNER.

## 1. Objetivo
Actualizar Términos y Condiciones para cubrir explícitamente el reclamo de titularidad de comercio y dejar claras las reglas de:
- declaración del usuario,
- validación/revisión,
- aprobación o rechazo,
- conflictos/duplicados,
- y acceso eventual al rol OWNER.

## 2. Contexto
El claim ahora es un flujo sensible con impacto en permisos (`owner_pending` y eventual `OWNER`).  
Por eso 0101 debe cubrir que:
- enviar claim no otorga ownership automático,
- puede haber validación automática y revisión manual,
- puede haber conflicto o disputa,
- OWNER solo se habilita por backend autorizado.

## 3. Problema que resuelve
- Evita que el usuario interprete claim como derecho adquirido.
- Da respaldo para pedir más info, rechazar o escalar.
- Cubre contractualmente duplicados y conflictos de titularidad.
- Alinea documento legal con comportamiento real del producto.

## 4. User Stories
- Usuario: entender qué acepta al reclamar y qué no se garantiza.
- Plataforma: exigir veracidad y legitimidad de lo presentado.
- Admin: operar revisión/rechazo/conflicto con marco contractual claro.
- Producto: evitar grants owner por expectativas incorrectas.

## 5. Objetivo de negocio
Equilibrar:
- claridad para usuario,
- margen operativo razonable para plataforma,
- y seguridad jurídica del flujo de ownership.

## 6. Alcance IN
- Sección específica de claim de titularidad.
- Declaraciones de veracidad/legitimidad del usuario.
- Regla explícita de no aprobación automática.
- Facultades de revisión, more-info, rechazo, suspensión o escalamiento.
- Tratamiento de duplicados/conflictos/disputas.
- Relación entre claim y acceso OWNER.
- Alineación con 0100/0102/0103/0104.

## 7. Alcance OUT
- No reemplaza Política de Privacidad ni consentimiento específico.
- No reemplaza retención ni derechos de usuario.
- No es texto legal final “publicable” definitivo, sino definición de cobertura obligatoria.

## 8. Supuestos
- Claim es flujo central del MVP.
- Email claim = email autenticado.
- Teléfono MVP opcional/sin verificación.
- Puede haber validación automática + revisión manual.
- Puede haber `owner_pending`, conflicto y duplicado.
- OWNER solo por aprobación backend.

## 9. Dependencias
- 0126, 0127, 0128, 0129, 0130, 0131, 0133.
- 0100, 0102, 0103, 0104.

## 10. Arquitectura propuesta del documento
Agregar sección “Reclamo de titularidad de comercio” con:
- naturaleza del claim,
- declaraciones del usuario,
- facultades de TuM2,
- no aprobación automática,
- conflictos/duplicados,
- acceso OWNER,
- límites de responsabilidad.

## 11. Naturaleza del claim (a declarar)
El claim es:
- solicitud formal de un usuario autenticado,
- sujeta a validación y revisión,
- basada en información/evidencia aportada por el usuario,
- no equivalente a asignación automática de control operativo.

## 12. Declaraciones del usuario
Debe aceptar que:
- actúa de buena fe,
- la información es veraz y actualizada según su conocimiento,
- tiene legitimidad para reclamar o representar,
- la documentación no es falsa ni engañosa,
- comprende que puede haber revisión, conflicto o rechazo.

## 13. Veracidad e integridad
Debe prohibirse expresamente:
- documentación falsa/manipulada,
- simulación de titularidad,
- reclamos sin legitimidad,
- uso abusivo para bloquear/hostigar/interferir.

TuM2 puede aplicar medidas proporcionales: rechazo, suspensión, restricción de acciones futuras.

## 14. No aprobación automática
Regla contractual crítica:
- enviar claim no implica aprobación,
- enviar claim no implica rol OWNER,
- enviar claim no implica control del comercio.

Acceso owner solo tras validación y transición autorizada.

## 15. Validación automática y revisión manual
Términos deben contemplar controles de:
- completitud,
- coherencia,
- duplicados,
- conflictos,
- legitimidad aparente.

Posibles outcomes: aprobación, rechazo, más información, escalamiento.

## 16. owner_pending y estados intermedios
Debe reconocerse estado intermedio de revisión (aunque wording público no use siempre el identificador técnico):
- usuario puede estar “en revisión”,
- puede ver estado contextual,
- no obtiene por eso acceso operativo pleno.

## 17. Duplicados, conflictos y disputas
Debe quedar base para que TuM2 pueda:
- frenar avance,
- pedir más información,
- mantener revisión,
- rechazar/suspender,
- aplicar medidas razonables de moderación.

Conflicto bloquea cualquier expectativa de asignación automática.

## 18. Facultad de pedir más información
Debe quedar explícita la facultad de requerir información adicional cuando lo enviado no sea suficiente para decidir razonablemente.

## 19. Facultad de rechazo o suspensión
Debe contemplar rechazo/suspensión por causas razonables, incluyendo:
- falsedad/engaño,
- evidencia insuficiente,
- conflicto no resuelto,
- duplicado/abuso,
- riesgo para integridad del sistema,
- incumplimiento del flujo.

## 20. Acceso al rol OWNER
Acceso owner:
- es eventual y condicionado,
- no deriva de registrarse/navegar/reclamar por sí solo,
- puede limitarse/suspenderse/revocarse ante incumplimientos graves.

## 21. Limitación de responsabilidad razonable
Términos deben aclarar que TuM2:
- no garantiza aprobación,
- no garantiza resolución inmediata,
- no garantiza ausencia de conflicto futuro,
- no garantiza suficiencia automática de toda evidencia.

Sin eximir diligencia razonable de la plataforma.

## 22. Conductas prohibidas ligadas al claim
Incluir explícitamente:
- reclamo sin legitimidad,
- documentación falsa/manipulada,
- apropiación indebida,
- hostigamiento/interferencia,
- reclamos abusivos repetidos,
- intento de eludir validaciones.

## 23. Relación con privacidad y consentimiento
Términos deben remitir a:
- 0100 (privacidad),
- 0102 (consentimiento evidencia),
- 0104 (retención/acceso),
- 0103 (derechos del usuario).

## 24. Frontend y UX
Flujo claim debe exponer acceso visible a términos aplicables antes del envío final.  
No basta aceptación genérica histórica si ahora hay flujo sensible con impacto de ownership.

## 25. Backend y operación interna
Debe ser compatible con operación real:
- registro de decisiones,
- tratamiento de conflicto,
- solicitud de más info,
- limitación de accesos,
- cambios de rol controlados y auditables.

## 26. Seguridad contractual
Debe reflejar que:
- permisos operativos no se conceden sin aprobación,
- plataforma aplica controles razonables,
- conflicto puede implicar bloqueo/revisión reforzada.

## 27. Microcopy habilitado
Compatibles:
- “Enviar esta solicitud no te da acceso inmediato a la gestión del comercio”.
- “TuM2 puede pedirte más información antes de resolver el reclamo”.
- “La aprobación depende de la validación de la información aportada”.

Evitar copy que sugiera activación inmediata automática.

## 28. Datos/elementos impactados
Marco contractual sobre:
- información declarada,
- evidencia/documentación,
- estado claim,
- decisiones de revisión,
- conflictos/duplicados,
- habilitación/restricción de acceso owner.

## 29. Riesgos si no se actualiza
- interpretaciones de “claim = derecho adquirido”,
- menor respaldo para rechazar casos inválidos,
- debilidad ante conflictos/disputas,
- contradicción entre UX y contrato.

## 30. Edge cases (cobertura conceptual)
- usuario cree que ya es owner por enviar claim,
- duplicados reiterados,
- conflicto entre reclamantes,
- comercio ya vinculado,
- rechazo por evidencia insuficiente,
- escalamiento por revisión especial,
- suspensión/revocación posterior por inconsistencias graves.

## 31. BDD / aceptación
- Dado usuario que inicia claim, cuando revisa términos, entiende que no hay OWNER automático.
- Dado usuario que aporta evidencia, cuando continúa, declara veracidad y legitimidad.
- Dado claim en revisión/more-info, cuando TuM2 lo detiene/escala, términos cubren esa facultad.
- Dado conflicto/duplicado, cuando sistema bloquea o reconduce, términos cubren tratamiento especial.
- Dado claim aprobado, cuando accede a owner, términos ya definían que acceso dependía de validación y aprobación.

## 32. QA plan
- QA documental: coherencia con claim flow real.
- QA legal/producto/seguridad: cláusulas de no aprobación automática, veracidad, conflicto y suspensión.
- QA de consistencia: alineación con 0100/0102/0103/0104 y arquitectura de roles/claims.

## 33. Definition of Done
- Claim contemplado expresamente en T&C.
- Declaración de veracidad/legitimidad incorporada.
- No aprobación automática explícita.
- Facultades de revisión/more-info/rechazo/escalamiento explicitadas.
- Duplicados/conflictos cubiertos.
- Relación claim↔owner formalizada.
- Alineación documental con 0100, 0102, 0131 y 0133.

## 34. Plan de rollout
1. Actualizar 0101 interna.
2. Revisar consistencia con 0100/0102/0103/0104.
3. Alinear wording del claim UX.
4. Validar texto publicable final contra implementación real antes de producción.

## 35. Sincronización documental obligatoria
- `docs/storyscards/0101-terms-and-conditions.md`
- `docs/storyscards/0100-privacy-policy.md`
- `docs/storyscards/0102-claim-evidence-consent.md`
- `docs/storyscards/0103-user-rights-claims-data.md`
- `docs/storyscards/0104-sensitive-data-retention-access.md`
- `docs/storyscards/0126-merchant-claim-flow.md`
- `docs/storyscards/0131-owner-claim-role-integration.md`
- `docs/storyscards/0133-merchant-claim-conflicts-and-duplicates.md`

## 36. Cierre ejecutivo
Con esta actualización, 0101 deja explícito que:
- el claim es solicitud sujeta a validación,
- el usuario declara veracidad y legitimidad,
- TuM2 puede revisar/pedir más info/rechazar/escalar,
- duplicados y conflictos tienen tratamiento especial,
- y OWNER se habilita solo tras aprobación del proceso, no por envío del formulario.
