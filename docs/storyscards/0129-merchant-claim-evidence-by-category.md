# TuM2-0129 — Evidencia y documentación por categoría de comercio

Estado: READY_TO_QA  
Prioridad: P0 (MVP crítica)  
Épica madre: TuM2-0125 — Reclamo de titularidad de comercio  
Dependencia directa del flujo: TuM2-0126 — Flujo de claim del comercio  
Actualización clave incorporada: criterio documental flexible para Tiendas de comida al paso / puestos móviles.

## Estado real de implementación (corte 2026-04-19)
### Hecho
- Se implementó policy canónica versionada en backend (`functions/src/lib/merchantClaimEvidencePolicy.ts`) con `policyVersion` explícita y fallback seguro.
- Se agregó allowlist MVP de categorías de claim (`pharmacy`, `kiosk`, `almacen`, `veterinary`, `fast_food`, `casa_de_comidas`, `gomeria`) y bloqueo explícito de categorías no MVP (`claim_category_not_allowed`).
- `merchantClaimAutoValidation` consume policy centralizada y persiste snapshot de evaluación (`evidencePolicyVersion`, `requiredEvidenceSatisfied`, `sufficiencyLevel`, `manualReviewReasons`, `riskHints`).
- El detalle admin (`getMerchantClaimReviewDetail`) expone policy aplicada + faltantes + suficiencia para revisión consistente.
- Mobile claim consume policy por `categoryId` con copy y validación local contextual, incluyendo `fast_food` flexible y requerimientos reforzados para `pharmacy`/`veterinary`.
- En mobile se habilitó carga de evidencia en **imagen o PDF** con tipos permitidos explícitos: `image/jpeg`, `image/jpg`, `image/png`, `image/webp`, `application/pdf` (máx 8MB por archivo).
- Legal links (Términos, Privacidad, Consentimiento de evidencia) pasan a consumirse desde un único origen lógico (`legalDocumentsConfigProvider` con Remote Config + fallback estable).
- Se agregó control de concurrencia optimistic-lock con `expectedUpdatedAtMillis` en `upsertMerchantClaimDraft` y `submitMerchantClaim` para evitar carreras multi-dispositivo.

### Pendiente para cierre definitivo
- QA E2E completa en emuladores para flujos cruzados mobile/admin con evidencia real.
- Verificación manual operativa de copy final por producto/legal para todas las categorías MVP.
- Ejecución operativa de migración de categorías legacy en datos existentes (dry-run + apply + rollback plan).

## Sync 0127 implementado (2026-04-16)
- El motor backend aplica validación mínima por categoría con `categoryId` canónico.
- `pharmacy` exige `regulatory_document`.
- `veterinary` exige `reinforced_relationship_evidence`.
- `fast_food` acepta combinación flexible (`operational_point_photo` y/o `alternative_relationship_evidence`) con flag de revisión manual por ambigüedad.

## 1. Objetivo
Definir la matriz canónica de evidencia y documentación por categoría de comercio para el dominio de claims de TuM2, estableciendo:

- qué evidencia mínima debe presentar el reclamante en MVP,
- qué variaciones aplican según categoría,
- qué casos pueden avanzar con validación automática,
- qué casos deben derivarse a revisión manual,
- cómo adaptar la UX de carga de evidencia sin romper conversión,
- y cómo hacerlo preservando seguridad, trazabilidad legal y costo operativo bajo.

Esta tarjeta debe convertir una regla ambigua del tipo “subí documentación” en una política clara, operable y mantenible, diferenciando correctamente entre:

- categorías más reguladas,
- comercios generales de baja fricción,
- y categorías de operación más informal o móvil, como comida al paso.

## 2. Contexto
TuM2 necesita permitir que usuarios legítimos reclamen la titularidad de un comercio sin imponer un proceso documental excesivo, pero tampoco puede abrir la puerta a apropiaciones indebidas o claims débiles.

El flujo base del claim ya define que el usuario envía:

- email autenticado,
- teléfono opcional sin verificación MVP,
- rol declarado,
- comercio reclamado,
- evidencia mínima,
- consentimiento explícito,
- y posterior validación automática / manual según riesgo.

El problema es que la evidencia no puede ser idéntica para todos los rubros:

- una farmacia exige mayor rigurosidad,
- una veterinaria puede requerir refuerzo intermedio,
- un kiosco o almacén puede funcionar con una base simple,
- y una tienda de comida al paso / puesto móvil no debería medirse con la misma vara documental que un local fijo tradicional.

La documentación existente de 0129 ya define una base común y anticipa diferencias por categoría, pero todavía no baja una matriz completa ni cierra el criterio flexible necesario para puestos móviles de comida al paso.

## 3. Problema que resuelve
Sin esta tarjeta correctamente expandida:

- 0126 queda forzado a pedir evidencia genérica y potencialmente incorrecta,
- 0127 no puede decidir bien entre aprobar, pedir más info o derivar a revisión,
- 0128 revisa claims sin criterio documental homogéneo,
- la UX corre el riesgo de pedir demasiado o demasiado poco,
- y los equipos de producto / soporte / admin no tienen una política consistente para justificar decisiones.

Riesgos concretos que esta tarjeta elimina:
- Exceso de fricción: pedir documentación pesada a categorías informales o móviles baja conversión legítima.
- Claims débiles o ambiguos: si la exigencia es demasiado laxa en todas las categorías, aumenta el fraude y la apropiación de comercios ajenos.
- Inconsistencia en revisión: sin matriz por categoría, cada admin revisa con criterio subjetivo.
- Mal diseño UX: el flujo puede pedir “fachada del local” a un puesto móvil que no tiene frente tradicional.
- Mayor costo operativo: si la validación automática no tiene reglas por categoría, casi todo termina en revisión manual.

## 4. User Stories
### 4.1 Usuario reclamante
Como usuario autenticado, quiero saber exactamente qué evidencia necesito según el tipo de comercio, para completar el claim sin subir documentos innecesarios.

### 4.2 Usuario reclamante
Como persona que administra un puesto móvil o seminformal, quiero que la plataforma acepte pruebas razonables de operación real, aunque no tenga la misma documentación que un local fijo.

### 4.3 Usuario reclamante
Como dueño real de un comercio regulado, quiero entender por qué se me pide mayor documentación, para confiar en el proceso.

### 4.4 Sistema / producto
Como plataforma, quiero aplicar criterios distintos por categoría para equilibrar conversión, seguridad y carga operativa.

### 4.5 Admin
Como revisor, quiero tener una matriz clara por categoría para tomar decisiones consistentes y justificables.

### 4.6 Backend / validación automática
Como capa de validación, quiero reglas documentales claras y parametrizables por categoría para evitar decisiones arbitrarias y reducir revisión manual innecesaria.

## 5. Objetivo de negocio
La política documental por categoría debe maximizar simultáneamente:

- conversión legítima de claims,
- calidad y confianza del dato,
- seguridad antifraude,
- consistencia operativa,
- bajo costo de revisión,
- y baja fricción UX.

La decisión de producto correcta no es pedir “lo máximo posible”, sino pedir lo mínimo suficiente para cada categoría.

## 6. Alcance IN
Esta tarjeta incluye:

- matriz documental por categoría para MVP,
- base común mínima obligatoria,
- documentación adicional o reforzada por rubro,
- reglas de obligatoriedad,
- criterios de laxitud controlada,
- copy y microcopy contextual del paso de evidencia,
- señales que fuerzan revisión manual,
- alineación con validación automática,
- alineación con revisión admin,
- tratamiento especial para Tiendas de comida al paso / puestos móviles,
- guardrails de seguridad y costo para evidencia y adjuntos.

## 7. Alcance OUT
Esta tarjeta no implementa en profundidad:

- cifrado reversible y masking de sensibles, que se profundiza en 0130,
- revisión manual Admin Web completa, que se profundiza en 0128,
- validación automática completa, que se profundiza en 0127,
- verificación telefónica, que queda en 0132 fase 2,
- transiciones de rol OWNER / owner_pending, que se profundizan en 0131,
- políticas legales completas, que se reparten en 0100, 0102, 0103 y 0104.

## 8. Supuestos
Se asumen como verdaderas estas condiciones:

- el usuario ya está autenticado,
- el email del claim se toma siempre desde Auth,
- el teléfono en MVP es opcional y no verificado,
- la categoría del comercio reclamado ya existe o puede inferirse del comercio seleccionado,
- la UX del claim debe variar por categoría sin romper el flujo general,
- la evidencia binaria se guarda en Storage, no en Firestore,
- la capa automática puede usar reglas por categoría para preclasificación,
- la categoría Tiendas de comida al paso puede incluir estructuras móviles, desmontables o semi-fijas,
- no todos los comercios tienen un local fijo con “fachada” clásica.

## 9. Dependencias
Dependencias funcionales:
- TuM2-0125 — Épica de claims.
- TuM2-0126 — Flujo claim.
- TuM2-0127 — Validación automática.
- TuM2-0128 — Revisión manual admin.
- TuM2-0130 — Seguridad de sensibles.
- TuM2-0133 — Conflictos y duplicados.

Dependencias legales:
- TuM2-0100 — Política de privacidad.
- TuM2-0102 — Consentimiento de evidencia.
- TuM2-0103 — Derechos del usuario sobre datos del claim.
- TuM2-0104 — Retención y acceso interno.

Dependencias de producto / integración:
- TuM2-0054 — Auth completa.
- TuM2-0064 — Módulo OWNER contextual.

## 10. Actores involucrados
Usuario reclamante:
sube evidencia, completa el claim y responde pedidos de información.

Admin revisor:
evalúa casos dudosos, conflictivos o insuficientes.

Sistema TuM2:
aplica reglas documentales por categoría para decidir si alcanza la validación automática o si debe escalar.

Producto / UX:
define el nivel correcto de fricción por categoría y el copy que la acompaña.

Legal / Seguridad:
define cómo se informa el consentimiento, la retención y la protección de la evidencia.

## 11. Arquitectura propuesta
### 11.1 Propuesta central
La definición documental por categoría debe resolverse con una matriz canónica centralizada, consumida por:

- el flujo de UI del claim,
- la validación automática,
- la revisión manual admin,
- el copy contextual de ayuda,
- y los criterios de derivación.

### 11.2 Diagrama conceptual
```text
categoryId
   ↓
ClaimEvidencePolicy
   ├─ requiredVisualEvidence
   ├─ requiredRelationshipEvidence
   ├─ optionalSupportingEvidence
   ├─ copyOverrides
   ├─ autoValidationTolerance
   ├─ manualReviewTriggers
   └─ riskLevel / strictnessLevel
        ↓
0126 UI flow
0127 auto validation
0128 admin review
0102 consent text
0130 sensitive-data handling
```

### 11.3 Justificación
Esto evita:

- hardcodes dispersos en Flutter,
- decisiones documentales inconsistentes,
- duplicación de reglas entre cliente, backend y admin,
- y costos de mantenimiento altos cuando cambie una categoría.

### 11.4 Alternativas y trade-offs
Alternativa A — Misma documentación para todas las categorías  
Ventaja: simple.  
Desventaja: mala conversión, mala UX y exceso de revisión manual.

Alternativa B — Reglas totalmente libres y manuales  
Ventaja: flexibilidad.  
Desventaja: inconsistencia, riesgo legal y antifraude débil.

Alternativa C — Recomendada  
Base común + variaciones por categoría + niveles de rigurosidad.  
Es el mejor equilibrio entre simplicidad, seguridad y escalabilidad.

## 12. Principio rector de diseño documental
La regla principal de esta tarjeta es:

No pedir la misma documentación a categorías con realidades operativas distintas.

Esto implica que el sistema debe tener tres niveles documentales:

Nivel 1 — Flexible  
Comercios simples o móviles con baja formalidad visible pero operación real verificable.

Nivel 2 — Base estándar  
Comercios generales de local fijo no especialmente regulados.

Nivel 3 — Reforzado  
Comercios regulados o de mayor sensibilidad operativa.

## 13. Base común obligatoria para todas las categorías
Toda categoría debe partir de esta base común:

- email autenticado,
- teléfono opcional sin verificación MVP,
- rol declarado,
- comercio reclamado,
- consentimiento explícito,
- al menos una evidencia visual principal,
- al menos una prueba mínima de vínculo,
- posibilidad de observación opcional.

Esto mantiene alineación con 0126 y la épica madre.

## 14. Matriz documental por categoría — MVP
### 14.1 Comercios generales de local fijo
Aplica a:

- kioscos,
- almacenes,
- rotiserías / casas de comida con local fijo,
- gomerías con local fijo.

Obligatorio:
- foto principal del frente / punto de venta,
- una prueba básica de vínculo,
- datos base del claim.

Aceptable como prueba básica:
- documentación comercial simple,
- foto con branding visible,
- material identificatorio del comercio,
- comprobante simple si existe.

Derivar a revisión manual si:
- la evidencia es ambigua,
- no se puede asociar razonablemente al comercio,
- hay conflicto o duplicado.

### 14.2 Farmacias
Criterio general:
rubro regulado y de alta sensibilidad pública.

Obligatorio:
- foto principal del frente,
- prueba documental más fuerte,
- dato habilitante cuando aplique,
- consistencia alta con identidad del comercio.

Regla:
no usar el mismo nivel de laxitud que categorías generales.

Derivar a revisión manual si:
- falta evidencia reforzada,
- existe inconsistencia entre nombre y prueba,
- ya existe owner activo o conflicto.

### 14.3 Veterinarias
Criterio general:
rubro intermedio / reforzado.

Obligatorio:
- foto principal del frente,
- prueba documental más fuerte que un comercio general,
- evidencia de vínculo con nivel medio-alto de confianza.

Derivar a revisión manual si:
- la evidencia no alcanza el umbral reforzado,
- el comercio es ambiguo,
- hay conflicto o duplicado.

### 14.4 Tiendas de comida al paso / puestos móviles
Criterio general:
categoría de documentación flexible y contextual.

Esta categoría incluye:

- food carts,
- carros,
- stands,
- trailers gastronómicos,
- puestos móviles,
- estructuras desmontables o semi-fijas,
- puntos de venta pequeños sin fachada tradicional.

Regla canónica:
para esta categoría, no se debe exigir como base el mismo tipo de documentación que a un local fijo tradicional.

Obligatorio en MVP:
- email autenticado,
- teléfono opcional,
- rol declarado,
- comercio / puesto identificado,
- foto principal del puesto o punto de venta operando,
- una prueba simple de vínculo.

Reemplazo funcional de “fachada”:
en esta categoría, el concepto de “fachada” se redefine como:

Foto clara del puesto o punto de venta operando.

Se aceptan como válidas:

- foto del carro,
- foto del tráiler,
- foto del stand,
- foto del puesto armado,
- foto del punto de venta con branding, cartel o mercadería visible,
- foto del puesto atendiendo o instalado en contexto real.

Prueba simple de vínculo aceptable:
al menos una de estas:

- foto del reclamante operando el puesto,
- branding o nombre visible en el puesto,
- material identificatorio del emprendimiento,
- perfil/red social asociable al nombre comercial,
- comprobante simple si existe,
- evidencia contextual razonable del vínculo.

No obligatorio como piso documental MVP:

- habilitación compleja,
- constancia equivalente a local fijo tradicional,
- múltiples documentos formales,
- documentación pesada difícil de conseguir para un microemprendimiento móvil.

Derivar a revisión manual si:
- la evidencia visual es demasiado ambigua,
- no se puede distinguir el puesto reclamado,
- el nombre comercial es genérico o dudoso,
- hay múltiples claims sobre la misma identidad,
- la evidencia contradice la categoría,
- existe conflicto fuerte con otro comercio o owner.

Justificación:
ser laxos aquí no significa ser inseguros. Significa pedir evidencia realista para la categoría, manteniendo una señal mínima de legitimidad.

## 15. Frontend / UX
### 15.1 Regla general
El flujo 0126 debe adaptar el copy y los ejemplos del paso de evidencia según categoría, sin cambiar la estructura base del wizard.

### 15.2 Regla crítica
La UI no debe usar un copy rígido universal como:

“Subí una foto de la fachada del local”

cuando la categoría no lo soporta.

### 15.3 Copy por categoría
General / local fijo:  
“Subí una foto clara del frente del comercio”

Comida al paso / puesto móvil:  
“Subí una foto clara de tu puesto o punto de venta”  
“Mostrá el carro, stand, tráiler o espacio donde atendés”  
“Si tenés cartel, nombre o branding visible, mejor”  
“Sumá una prueba simple que demuestre tu vínculo con este puesto”

### 15.4 Estados UX que deben resolverse
- evidencia incompleta,
- archivo inválido,
- tipo de evidencia no suficiente,
- copy de ayuda contextual por categoría,
- loading y error de upload,
- preview clara,
- pedido posterior de más información.

### 15.5 Accesibilidad
- ejemplos visuales entendibles,
- helper text breve,
- errores accionables,
- no depender solo de color,
- dejar claro qué es obligatorio y qué es opcional.

## 16. Backend / validación automática
### 16.1 Principio
La capa automática no debe validar igual todas las categorías.

### 16.2 Reglas esperadas
La validación inicial debe poder leer por categoría:

- qué tipo de evidencia visual es obligatoria,
- qué tipo de vínculo mínimo se exige,
- qué flexibilidad documental aplica,
- qué señales activan revisión manual.

### 16.3 Para comida al paso móvil
La validación automática debe tolerar más variabilidad documental y priorizar:

- existencia de foto principal válida,
- existencia de una prueba simple de vínculo,
- consistencia razonable entre nombre, rubro y evidencia,
- ausencia de conflicto obvio o duplicado.

### 16.4 No hacer
- escanear colecciones enteras,
- descargar binarios en validaciones masivas,
- o exigir información no alineada con la categoría.

## 17. Seguridad
### 17.1 Threat model
La categoría comida al paso móvil incrementa el riesgo de:

- identidad comercial ambigua,
- pruebas visuales débiles,
- nombres genéricos,
- reclamos oportunistas,
- dificultad para distinguir negocios similares.

### 17.2 Mitigaciones obligatorias
- al menos una evidencia visual fuerte,
- al menos una prueba simple de vínculo,
- no aprobar automáticamente casos ambiguos,
- derivar a revisión manual ante duda,
- fingerprints / hash para matching y antifraude donde aplique,
- masking y protección de sensibles según 0130,
- no exponer adjuntos públicamente.

### 17.3 OWASP / controles relevantes
- broken access control: solo propietario del claim o admin autorizado puede ver evidencia,
- IDOR: bloquear acceso a adjuntos ajenos,
- replay / duplicate submission: evitar claims basura por reenvío,
- abuse of upload endpoints: validar ownership, tipo y tamaño,
- PII exposure: no listar sensibles completos.

## 18. UX / Producto
### 18.1 Objetivo UX
El usuario debe sentir que el sistema entiende su realidad operativa.

### 18.2 Regla clave para comida al paso
No hacer que un usuario de puesto móvil sienta que “no encaja” en el producto por no tener local fijo.

### 18.3 Fricción adecuada
- baja fricción en categorías flexibles,
- fricción media en categorías generales,
- fricción mayor y justificada en categorías reguladas.

### 18.4 Microcopy a evitar
- “Adjunte acreditación documental formal”
- “Debe exhibir frente habilitado”
- “Suba fachada del local” como única opción universal

## 19. Datos impactados
Dominios / entidades:
- `merchant_claims`
- Storage de evidencia / adjuntos
- metadata de categorías / políticas documentales
- admin review metadata
- flags de validación
- motivos de derivación manual

Datos mínimos relevantes por política:
- `categoryId`
- `evidencePolicyVersion`
- `requiredEvidenceSatisfied`
- `manualReviewReason[]`
- `primaryVisualEvidenceType`
- `relationshipEvidenceType[]`
- `sufficiencyLevel`
- `riskHints`

## 20. Analytics y KPI
Eventos recomendados:
- `merchant_claim_evidence_requirements_viewed`
- `merchant_claim_evidence_upload_started`
- `merchant_claim_evidence_upload_completed`
- `merchant_claim_evidence_upload_failed`
- `merchant_claim_category_specific_help_viewed`
- `merchant_claim_submitted`
- `merchant_claim_sent_to_manual_review`

KPI:
- tasa de finalización por categoría,
- abandono en paso de evidencia por categoría,
- porcentaje de claims que pasan con evidencia suficiente al primer intento,
- porcentaje de derivación manual por categoría,
- tiempo medio hasta decisión por categoría,
- ratio de rechazo por evidencia insuficiente.

KPI crítico para comida al paso:
monitorear si la flexibilización mejora conversión legítima sin disparar conflictos ni fraude.

## 21. Escalabilidad / Performance
Reglas:
- no cargar adjuntos en listados,
- detalle de evidencia solo on-demand,
- metadatos livianos y versionados,
- reglas de categoría cacheables con TTL,
- validaciones basadas en metadata, no en blobs,
- queries siempre filtradas y con limit.

Cuellos a evitar:
- admin listados con previews binarias,
- validación automática que dependa de lecturas amplias,
- duplicación de metadata pesada en múltiples documentos.

## 22. Costos
Componentes caros:
- Storage uploads,
- downloads innecesarios de adjuntos,
- relecturas repetidas de políticas por categoría,
- validaciones que hagan fan-out,
- revisión manual excesiva por falta de matriz clara.

Optimización obligatoria:
- policy por categoría cacheable,
- metadata compacta,
- no descargar binarios salvo necesidad real,
- evitar writes redundantes al actualizar estado del claim,
- evitar reintentos de upload ocultos y costosos.

Esto es consistente con los guardrails ya definidos en la tarjeta placeholder de 0129.

## 23. Riesgos y deuda
Riesgos:
- que la categoría flexible quede demasiado laxa,
- que el copy no cambie y la UX siga pidiendo “fachada” a puestos móviles,
- que admin revise con sesgo de local fijo,
- que la validación automática no entienda bien la categoría.

Deuda que escalaría mal:
- reglas por categoría hardcodeadas en múltiples capas,
- usar strings de copy en vez de política central,
- no versionar la matriz documental,
- no distinguir evidencia visual principal de prueba de vínculo,
- no separar categorías de local fijo y móvil.

## 24. Checklist UX
- el usuario entiende qué evidencia necesita según categoría,
- la UI cambia el copy del paso de evidencia cuando corresponde,
- la categoría comida al paso no recibe copy de “fachada” rígida,
- el flujo se siente serio pero accesible,
- la evidencia obligatoria es clara,
- los errores son accionables,
- la laxitud no se percibe como “cualquier cosa sirve”.

## 25. Criterios BDD / aceptación
Escenario 1:
dado un comercio de categoría comida al paso móvil, cuando un usuario inicia el claim, entonces el sistema debe permitir evidencia visual del puesto como reemplazo funcional de la fachada de un local fijo.

Escenario 2:
dado un claim de comida al paso móvil, cuando el usuario no cuenta con documentación formal equivalente a un local tradicional, entonces el sistema no debe bloquear automáticamente el claim si existe evidencia visual suficiente y una prueba simple de vínculo.

Escenario 3:
dado un claim de comida al paso móvil con evidencia ambigua, cuando la capa automática no alcanza un umbral mínimo de confianza, entonces el caso debe derivarse a revisión manual.

Escenario 4:
dado un claim de una farmacia, cuando falta evidencia reforzada requerida por categoría, entonces el claim no debe considerarse suficiente bajo la misma política que un comercio general.

Escenario 5:
dado un comercio general de local fijo, cuando el usuario llega al paso de evidencia, entonces la UI debe pedir foto del frente y prueba básica de vínculo con copy estándar de local fijo.

Escenario 6:
dado un claim de comida al paso móvil, cuando el usuario llega al paso de evidencia, entonces la UI debe mostrar copy contextual sobre “puesto o punto de venta” y no sobre “fachada del local” en términos rígidos.

## 26. Testing
Unit:
- policy resolver por categoría,
- sufficiency checks por categoría,
- mapping de copy contextual.

Integration:
- flujo claim por categoría general,
- flujo claim por farmacia,
- flujo claim por veterinaria,
- flujo claim por comida al paso móvil,
- envío con evidencia suficiente,
- envío con evidencia insuficiente,
- cambio correcto del copy UX.

Security:
- acceso a adjuntos propios vs ajenos,
- validación de tipo y ownership,
- protección de metadata sensible.

QA manual:
- revisar que comida al paso no herede copy incorrecto,
- revisar que farmacias tengan fricción reforzada,
- revisar consistencia entre mobile y admin.

## 27. QA plan
QA funcional:
- validar matriz completa por rubro,
- validar obligatoriedad,
- validar triggers de revisión manual.

QA UX:
- copy adecuado por categoría,
- claridad de ayuda,
- ejemplo visual correcto para comida al paso.

QA de seguridad:
- sin exposición pública de evidencia,
- sin acceso cruzado,
- sin información sensible en listados.

QA de costo:
- sin descarga de adjuntos en listados,
- sin lecturas redundantes de política,
- sin writes innecesarios por navegación.

## 28. Definition of Done
La tarjeta se considera cerrada cuando:

- existe una matriz documental completa y versionada por categoría,
- la base común está cerrada,
- las categorías reforzadas están definidas,
- la categoría Tiendas de comida al paso / puestos móviles tiene política flexible explícita,
- 0126 puede consumir esa política sin hardcodes ambiguos,
- 0127 y 0128 tienen criterios claros para automatización y revisión,
- el copy UX por categoría queda definido,
- los guardrails de costo, seguridad y tratamiento de evidencia están documentados,
- los edge cases principales quedan cubiertos.

## 29. Plan de rollout
Fase 1 — Definición:
- cerrar esta tarjeta,
- versionar policy por categoría,
- alinear copy con 0126.

Fase 2 — Integración MVP:
- integrar matriz en flujo claim,
- integrar check automático por categoría,
- integrar guía admin de revisión.

Fase 3 — Observación:
- medir abandono en paso de evidencia,
- medir desvío a revisión manual,
- ajustar umbrales por categoría si hace falta.

Fase 4 — Endurecimiento post-MVP:
- score antifraude más fino,
- subtipos de evidencia más ricos,
- posible personalización por zona o regulación.

## 30. Documentos / tarjetas a actualizar por impacto cruzado
Crear / mantener alineados:
- `docs/storyscards/0129-merchant-claim-evidence-by-category.md`
- `docs/storyscards/0126-merchant-claim-flow.md`
- `docs/storyscards/0127-merchant-claim-auto-validation.md`
- `docs/storyscards/0128-admin-merchant-claims-review.md`
- `docs/storyscards/0130-merchant-claim-sensitive-data-protection.md`

Actualizar por impacto:
- `docs/storyscards/0102-claim-evidence-consent.md`
- `docs/storyscards/0100-privacy-policy.md`
- `docs/storyscards/0104-sensitive-data-retention-access.md`

## 31. Cierre ejecutivo
TuM2-0129 define cuánta evidencia se pide, a quién y con qué lógica dentro del dominio de claims.

La decisión correcta para MVP no es uniformar toda la documentación, sino construir una política documental inteligente por categoría:

- base común mínima para todos,
- mayor rigor para rubros regulados,
- criterio estándar para comercios generales,
- y flexibilidad controlada para comida al paso / puestos móviles.

En especial, para Tiendas de comida al paso, la política correcta es:

- no exigir piso documental de local fijo tradicional,
- sí exigir evidencia visual real del puesto,
- sí exigir una prueba simple de vínculo,
- y escalar a revisión manual cuando la evidencia sea ambigua o conflictiva.

Esa combinación mantiene conversión, protege el sistema y baja el costo operativo total.
