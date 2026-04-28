# TuM2-0100 — Política de Privacidad

Estado: TODO  
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

Alineación analytics (0082, 2026-04-27):
- Telemetría funcional sin PII ni query cruda.
- Sin identificadores directos de entidad/usuario en payload analytics (`merchantId`, `productId`, `userId`, `deviceId`).
- Prioridad territorial por zona (`active_zone_id`/`entity_zone_id`) y buckets agregados.

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

## 11. Tipos de información que tratamos
A los fines de esta Política de Privacidad, TuM2 podrá tratar distintas categorías de información, que no reciben el mismo tratamiento ni tienen la misma visibilidad dentro de la plataforma:

a) Datos personales de usuarios finales.  
Incluyen, entre otros, los datos asociados a la cuenta del usuario, como nombre, correo electrónico, teléfono cuando corresponda, identificadores de la cuenta, preferencias, interacciones dentro de la plataforma, comunicaciones enviadas o recibidas y demás información vinculada al uso personal de TuM2.

b) Datos públicos del perfil comercial.  
Incluyen la información del comercio destinada a ser visible dentro de la plataforma, como nombre comercial, rubro, zona, dirección o referencia territorial, horarios, señales operativas, catálogo público, medios de contacto públicos, imágenes públicas del comercio y demás información que, por su naturaleza y finalidad, forme parte de la experiencia abierta de descubrimiento y consulta dentro de TuM2.

c) Datos privados del claim o reclamo de titularidad.  
Incluyen la información y documentación aportada por un usuario para acreditar su vínculo con un comercio, como datos identificatorios, rol declarado, documentación de respaldo, imágenes del frente del local, observaciones, estados del reclamo, resultados de validaciones, revisiones internas, conflictos, duplicados y demás información asociada al proceso de evaluación del reclamo. Esta información no es pública y se encuentra sujeta a medidas de acceso restringido y resguardo reforzado.

d) Datos agregados, estadísticos o anonimizados.  
Incluyen información tratada de modo tal que no identifique razonablemente a una persona humana determinada, o que se utilice de forma agrupada con fines estadísticos, analíticos, operativos, comerciales, de mejora de producto, personalización general, optimización de experiencia, ranking, segmentación, medición de rendimiento y desarrollo de nuevas funcionalidades o modelos comerciales.

e) Espacios comerciales, posicionamiento y media listing.  
TuM2 podrá ofrecer espacios de visibilidad, promoción, posicionamiento diferencial, recomendaciones destacadas, presencia preferente u otros formatos comerciales dentro de la plataforma. En esos casos, ciertos comercios podrán recibir una ubicación, tratamiento visual o exposición diferenciada en función de acuerdos comerciales, campañas, promociones internas, herramientas de marketing o funcionalidades pagas, sin que ello implique, por sí mismo, la venta de datos personales de usuarios finales.

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

## 16. Separación entre información pública del comercio e información privada del claim
TuM2 diferencia expresamente entre la información pública de un comercio y la información privada aportada en un reclamo de titularidad.

La información pública del comercio es aquella destinada a ser mostrada dentro de la plataforma para la experiencia de consulta, descubrimiento y contacto de vecinos y usuarios. En cambio, la información privada del claim incluye documentación, evidencia, datos sensibles o información de soporte aportada para validar la relación entre una persona y un comercio determinado, y no forma parte del contenido público del perfil comercial por el solo hecho de haber sido cargada.

La documentación y evidencia privada del claim no será publicada automáticamente como contenido visible del comercio ni quedará disponible para otros usuarios, otros reclamantes o terceros no autorizados, salvo obligación legal o supuesto excepcional debidamente fundado.

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

## 20. No venta de datos personales y uso de datos agregados o anonimizados
TuM2 no vende datos personales de usuarios finales en los términos de esta Política.

Lo anterior no impide que TuM2 pueda utilizar información agregada, estadística, desidentificada o anonimizada para fines de análisis, mejora de producto, desarrollo comercial, inteligencia de negocio, optimización operativa, personalización general, medición de campañas, construcción de métricas, elaboración de reportes o diseño de nuevas funcionalidades o modelos de negocio, siempre que dicho tratamiento no implique identificar razonablemente a una persona humana determinada.

Asimismo, TuM2 podrá facilitar espacios, herramientas o vínculos comerciales entre comercios, proveedores, anunciantes, aliados u otros terceros en el marco de funcionalidades comerciales de la plataforma, siempre que ello se realice conforme a la presente Política, a los Términos y Condiciones aplicables y a la normativa vigente.

## 21. Prevención de fraude, uso indebido y protección de la integridad de la plataforma
TuM2 podrá utilizar la información asociada a la cuenta del usuario, a sus reclamos de titularidad, reportes, interacciones dentro de la plataforma, documentación aportada, metadatos relacionados y señales técnicas o derivadas de seguridad para prevenir fraude, detectar conductas abusivas o engañosas, limitar usos indebidos, resolver conflictos, proteger la integridad del sistema y resguardar a otros usuarios, comercios y terceros vinculados a la operación de la plataforma.

A tales efectos, TuM2 podrá aplicar validaciones automáticas, revisiones manuales restringidas, controles internos de consistencia, detección de duplicados, identificación de patrones de abuso, auditorías internas de acceso, medidas de moderación y otras acciones razonables y proporcionales al riesgo detectado.

Cuando existan indicios razonables de fraude, uso abusivo o utilización indebida de los flujos de reclamo, reportes u otras funciones sensibles, TuM2 podrá tratar y conservar la información estrictamente necesaria para investigar, documentar, prevenir reiteraciones, sostener decisiones internas, resguardar evidencia del proceso y proteger el funcionamiento general de la plataforma.

## 22. Comunicaciones, recomendaciones y espacios promocionales
TuM2 podrá enviar comunicaciones operativas, informativas, promocionales o comerciales por correo electrónico, notificaciones push u otros canales habilitados por la plataforma, conforme a la configuración del usuario y a la normativa aplicable.

Las comunicaciones operativas o críticas para el funcionamiento del servicio, la seguridad de la cuenta, la gestión del reclamo, el estado del comercio, cambios relevantes del producto o cuestiones vinculadas al uso esencial de TuM2 podrán mantenerse activas en la medida necesaria para la correcta prestación del servicio.

Las comunicaciones promocionales o de marketing podrán incluir novedades, recomendaciones, promociones, sugerencias comerciales, campañas de visibilidad, posicionamiento o contenidos patrocinados, y el usuario podrá solicitar la baja u optar por no recibir este tipo de comunicaciones, sin que ello afecte las comunicaciones operativas esenciales.

TuM2 también podrá mostrar recomendaciones, destacados, promociones o posicionamientos diferenciados dentro de la plataforma sobre la base de criterios comerciales, analíticos, contextuales, territoriales, agregados o anonimizados, siempre respetando esta Política de Privacidad y la normativa aplicable.

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
3. Alinear copy y referencias de los flujos de claims y reportes.
4. Verificar coherencia de la lógica funcional con las reglas documentadas (sanción, limitación y moderación).
5. Publicar texto final alineado a implementación antes de producción.

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
