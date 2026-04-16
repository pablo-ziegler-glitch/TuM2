# TuM2-0100 — Política de Privacidad

Estado propuesto: UPDATE REQUIRED  
Prioridad: P0  
Motivo de actualización: impacto directo de la épica de claims sobre recolección, tratamiento, acceso, revisión manual, auditoría y retención de datos personales/sensibles.

## 1. Objetivo
Actualizar la política para cubrir explícitamente el dominio de reclamo de titularidad de comercio (`merchant_claims`) y dejar claro:
- qué datos se recopilan,
- para qué se usan,
- cómo se protegen,
- quién accede y bajo qué controles,
- cómo se conserva/retiene la información,
- y qué derechos tiene el usuario.

## 2. Contexto
El claim incorpora tratamiento sensible adicional respecto de una app de descubrimiento:
- identidad del reclamante,
- evidencia visual/documental,
- señales derivadas de seguridad (matching/antifraude),
- validación automática + posible revisión manual.

La política debe reflejar decisiones de producto ya cerradas:
- email del claim = email autenticado,
- teléfono MVP opcional,
- revisión humana restringida cuando aplica,
- masking por defecto en Admin y reveal controlado/auditado,
- uso de fingerprints/hashes derivados para seguridad.

## 3. Problema que resuelve
- Evita desalineación entre producto real y documento legal.
- Evita zonas grises sobre acceso interno a datos sensibles.
- Da marco comunicacional a antifraude/dedupe y auditoría.
- Reduce riesgo legal/reputacional frente a disputas de claims.

## 4. User Stories
- Usuario: entender qué datos se piden en claim y para qué.
- Usuario: confiar en que documentación sensible no se expone libremente.
- Plataforma: sostener base legal coherente con operación real del claim.
- Equipo interno: contar con cobertura explícita para revisión humana controlada.

## 5. Objetivo de negocio
Lograr transparencia, cobertura legal realista, escalabilidad documental y consistencia con la arquitectura de seguridad sin promesas técnicas falsas.

## 6. Alcance IN
- Claim incorporado explícitamente en política.
- Datos tratados en claim y finalidades.
- Validación automática + revisión manual controlada.
- Tratamiento de evidencia sensible.
- Uso de señales de seguridad/antifraude.
- Principios de minimización, protección, acceso restringido y retención general.
- Referencia a derechos del usuario y sincronización con 0101/0102/0103/0104.

## 7. Alcance OUT
- No es texto legal final publicable línea por línea.
- No reemplaza T&C, consentimiento específico, política de retención ni política detallada de derechos.

## 8. Supuestos
- Claim es funcionalidad central del MVP.
- Email autenticado es identidad canónica del claim.
- Puede haber evidencia visual/documental sensible.
- Puede haber revisión humana restringida.
- Datos de claim no son públicos.

## 9. Dependencias
- 0126, 0127, 0128, 0129, 0130, 0131, 0133.
- 0101, 0102, 0103, 0104.

## 10. Arquitectura propuesta del documento
Agregar sección específica “Claims de titularidad y datos asociados” con subtemas:
- datos recopilados,
- finalidades,
- validación automática/manual,
- protección y acceso interno,
- conservación general,
- derechos del usuario.

## 11. Tipos de datos a contemplar
- Datos de cuenta: email autenticado, identificadores de usuario.
- Contacto: teléfono opcional.
- Declarativos del claim: rol declarado, observaciones, vínculo alegado.
- Comercio reclamado: nombre, categoría, ubicación/referencias.
- Evidencia visual: fotos del comercio/puesto.
- Evidencia documental: pruebas de vínculo.
- Operativos derivados: estado claim, flags de conflicto/duplicado, trazabilidad.
- Seguridad/control: fingerprints/hashes derivados y auditoría de acceso cuando corresponda.

## 12. Finalidades de uso
- Procesar reclamo de titularidad.
- Validar legitimidad del vínculo usuario-comercio.
- Aprobar/rechazar/pedir más info.
- Prevenir fraude, duplicados y abuso.
- Resolver conflictos/disputas de titularidad.
- Proteger integridad del sistema.
- Habilitar acceso owner cuando corresponda.
- Mantener trazabilidad razonable de decisiones.

## 13. Validación automática y revisión manual
La política debe declarar que el claim puede incluir:
- Validación automática inicial (completitud, consistencia, duplicado/conflicto).
- Revisión manual por personal autorizado en casos de duda, conflicto, sensibilidad o insuficiencia documental.

## 14. Protección de datos sensibles
Sin exponer detalle técnico innecesario, debe declarar:
- medidas técnicas/organizativas de protección,
- acceso interno restringido por necesidad operativa,
- información sensible enmascarada por defecto en herramientas internas,
- registros de acceso/reveal cuando corresponda.

## 15. Cifrado, hashing y derivados
Debe contemplar que TuM2 puede:
- proteger sensibles con mecanismos apropiados,
- generar valores derivados para dedupe/antifraude,
- usar datos mínimos necesarios para seguridad.

Evitar frases inexactas como “todo anonimizado” o “nadie interno puede ver nada”.

## 16. Acceso interno
Debe dejar claro que datos de claim:
- no son públicos,
- no son de acceso abierto interno,
- se acceden solo por personal/procesos autorizados cuando sea necesario.

## 17. Minimización de datos
Principio explícito: recolectar lo mínimo necesario para validar titularidad, proteger sistema y operar el proceso.

Alinear con MVP: no pedir por defecto datos invasivos/redundantes (DNI general, selfie obligatoria, datos bancarios, etc.).

## 18. Retención y conservación general
Sin fijar aquí todos los plazos finos (0104), sí debe declarar:
- conservación mientras sea necesaria para validación, seguridad, auditoría razonable, conflictos y cumplimiento,
- no retención indefinida sin causa,
- conservación proporcional al riesgo/necesidad.

## 19. Derechos del usuario
Conectar con 0103:
- acceso a información sobre tratamiento,
- corrección de datos inexactos,
- consultas sobre eliminación/limitación según marco aplicable y restricciones razonables de seguridad/auditoría.

Evitar prometer supresión absoluta inmediata en todos los casos.

## 20. Información compartida con terceros
Debe contemplar uso de proveedores necesarios (infraestructura/auth/storage/procesamiento) bajo finalidad del servicio.

Debe dejar claro que información de claim:
- no se publica,
- no se comparte con otros reclamantes/comercios de forma abierta,
- no se vende como dato personal.

## 21. Prevención de fraude, abuso y protección de la integridad de la plataforma
TuM2 podrá utilizar la información proporcionada por las personas usuarias, la documentación y evidencia cargada en el marco de reclamos de titularidad de comercios, reportes y otras funciones sensibles de la plataforma, así como ciertos datos derivados, metadatos, registros de actividad y señales técnicas razonablemente necesarias, con las siguientes finalidades:
- validar la legitimidad y consistencia de reclamos y reportes;
- detectar, prevenir e investigar fraudes, abusos, inconsistencias, duplicaciones, intentos de apropiación indebida de comercios, documentación presuntamente falsa o engañosa, y otros usos contrarios a la integridad de la plataforma;
- proteger a otras personas usuarias, comercios, al sistema de revisión y a la operatoria general de TuM2;
- aplicar medidas internas de seguridad, moderación, limitación o restricción de funcionalidades cuando existan motivos razonables para ello;
- conservar, cuando corresponda, trazas, registros y evidencia mínima necesaria durante un plazo razonable para fines de auditoría, seguridad, prevención de fraude, resolución de conflictos y cumplimiento de obligaciones legales o regulatorias aplicables.

La información tratada con estas finalidades no será utilizada como contenido público del comercio por el solo hecho de haber sido aportada en un reclamo o reporte. El acceso interno a datos personales o evidencia sensible vinculados a estos procesos se encuentra sujeto a criterios de necesidad operativa, acceso restringido, medidas de protección razonables y, cuando corresponda, mecanismos de auditoría interna.

En caso de detectarse indicios razonables de fraude, abuso o uso indebido de reclamos, reportes u otras funciones sensibles, TuM2 podrá utilizar la información disponible para revisar el caso y adoptar medidas de protección de la plataforma, de conformidad con los Términos y Condiciones y demás políticas aplicables.

## 22. UX y referencias en flujo
La app debe mostrar referencia clara a política en momentos sensibles del claim:
- consentimiento,
- carga de evidencia,
- confirmación previa al envío.

## 23. Operación interna y backend
La política debe estar alineada con operación real:
- restricción de acceso,
- protección de almacenamiento,
- limitación de exposición,
- trazabilidad/auditoría cuando corresponda.

## 24. Seguridad (alineación con producto)
La política debe reflejar:
- email claim = email autenticado,
- teléfono opcional en MVP,
- datos sensibles no públicos,
- revisión humana restringida posible,
- acceso interno controlado/auditable,
- masking por defecto cuando corresponda.

Y evitar promesas absolutas técnicamente imposibles.

## 25. Lineamientos de microcopy
Mensajes compatibles:
- “Usaremos esta información solo para validar tu reclamo”.
- “Tu documentación se revisa de forma protegida”.
- “Solo pedimos la información necesaria”.
- “Algunos datos sensibles pueden ser revisados por personal autorizado cuando el caso lo requiera”.

## 26. Datos impactados
Conceptualmente: email, teléfono opcional, nombre/apellido, rol declarado, comercio reclamado, evidencia visual/documental, estado claim, datos derivados de seguridad y trazas internas de acceso/revisión.

## 27. Riesgos si no se actualiza
- Política desfasada vs operación real.
- Debilidad frente a reclamos de privacidad/acceso interno.
- Inconsistencia entre minimización declarada y práctica.
- Cobertura legal insuficiente para flujo sensible del MVP.

## 28. Edge cases a cubrir conceptualmente
- Solicitudes de tratamiento/eliminación parcial.
- Conflictos entre reclamantes sin exposición cruzada.
- Conservación razonable de evidencia tras rechazo.
- Evidencia con datos personales extra.
- Necesidad de conservar traza de seguridad tras cierre.

## 29. BDD / aceptación
- Dado usuario en claim, cuando consulta política, entiende qué datos se recopilan y finalidades.
- Dado carga de evidencia, cuando acepta continuar, la política cubre validación de titularidad y protección del sistema.
- Dado revisión manual, cuando caso se deriva, la política cubre acceso interno restringido.
- Dado uso de señales de seguridad, cuando sistema deduplica/protege, la política lo contempla.
- Dado consulta de derechos, cuando usuario revisa política, encuentra tratamiento, conservación general y vías de ejercicio.

## 30. QA plan
- QA documental: coherencia con flujo real y con 0101/0102/0103/0104.
- QA funcional: referencias visibles en claim donde corresponde.
- QA legal/producto/seguridad: evitar promesas exageradas o vacíos críticos.

## 31. Definition of Done
- Política contempla explícitamente dominio claims.
- Datos principales y finalidades descritos.
- Revisión manual controlada declarada.
- Minimización y protección reforzada incorporadas.
- Alineación explícita con 0130 y 0104.
- Derechos del usuario conectados con 0103.
- Documento deja de estar desfasado del producto real.

## 32. Plan de rollout
1. Actualizar 0100 en documentación interna.
2. Revisar consistencia integral con 0101/0102/0103/0104.
3. Ajustar referencias del flujo de claim.
4. Publicar texto final alineado a implementación antes de producción.

## 33. Sincronización documental obligatoria
- `docs/storyscards/0100-privacy-policy.md`
- `docs/storyscards/0101-terms-and-conditions.md`
- `docs/storyscards/0102-claim-evidence-consent.md`
- `docs/storyscards/0103-user-rights-claims-data.md`
- `docs/storyscards/0104-sensitive-data-retention-access.md`
- `docs/storyscards/0126-merchant-claim-flow.md`
- `docs/storyscards/0130-merchant-claim-sensitive-data-protection.md`

## 34. Cierre ejecutivo
Con esta actualización, 0100 deja de ser genérica y pasa a cubrir explícitamente el tratamiento de claims:
- datos y evidencia para validar titularidad,
- validación automática y revisión manual cuando corresponda,
- protección reforzada y acceso restringido,
- señales derivadas para seguridad/antifraude,
- conservación bajo criterios de necesidad y cumplimiento.
