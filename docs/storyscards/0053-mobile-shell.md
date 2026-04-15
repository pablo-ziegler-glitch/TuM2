# TuM2-0053 — Shell mobile

Estado propuesto: UPDATE REQUIRED  
Prioridad: P0  
Motivo de actualización: impacto directo de la nueva épica de reclamo de titularidad de comercio sobre entry points, navegación contextual, guards, visibilidad de módulos y experiencia `owner_pending`.

## 1. Objetivo
Actualizar la shell para dejar de asumir una experiencia binaria (`customer` vs `owner`) y soportar formalmente el estado intermedio `owner_pending`.

La shell debe orquestar:
- superficie principal al abrir app,
- visibilidad de tabs/accesos,
- banners y CTAs contextuales,
- rutas bloqueadas/habilitadas,
- convivencia entre experiencia customer y claim activo.

La shell no concede permisos; traduce estado de acceso real resuelto por Auth.

## 2. Contexto
Con la épica de claims, existe un estado sostenido donde el usuario:
- inició reclamo,
- aún no fue aprobado,
- puede estar en revisión/conflicto/more-info,
- requiere UX distinta a customer puro pero sin acceso owner pleno.

La shell es crítica para evitar contradicciones post-login, estados stale y rutas incoherentes.

## 3. Problema que resuelve
- pending sin contexto útil,
- accesos owner prematuros por mala distinción pending/owner,
- guards dispersos o inconsistentes,
- Auth resuelve bien pero shell lo representa mal,
- seguimiento de claim oculto o improvisado.

## 4. User Stories (negocio)
- Como customer, quiero una experiencia limpia sin módulos irrelevantes.
- Como pending, quiero contexto claro y acceso a seguimiento del claim.
- Como pending, quiero saber qué falta y próximos pasos sin buscar pantallas ocultas.
- Como owner aprobado, quiero acceso owner consistente en cuanto backend lo confirma.
- Como plataforma, quiero shell simple/segura sin session switches ni duplicaciones.

## 5. Objetivo de negocio
La shell debe acompañar el ciclo:
- customer limpio,
- customer enriquecido con contexto pending,
- owner pleno solo cuando corresponde.

Resultado esperado: menos confusión, menos soporte, mejor percepción de control y menor riesgo de accesos ambiguos.

## 6. Alcance IN
- Incorporación explícita de `owner_pending` en lógica shell.
- Definición de superficies para customer/pending/owner.
- Entry points contextuales de claim.
- Banners/CTAs contextuales.
- Alineación shell con guards y estado de sesión.
- Impacto sobre rutas owner y seguimiento claim.
- Transición pending→owner y salida de pending por cierre/rechazo.
- Lineamientos UX para evitar shell fragmentada.

## 7. Alcance OUT
- No rediseña todas las pantallas.
- No reescribe por completo navegación.
- No reemplaza detalle de 0064/0126/0054; integra sus efectos en orquestación shell.

## 8. Supuestos
- shell base ya existe,
- CUSTOMER rol base,
- OWNER compuesto, sin switch de sesión,
- `owner_pending` estado formal,
- Auth entrega resolución confiable de acceso,
- pending no accede a módulo owner pleno.

## 9. Dependencias
- TuM2-0004, 0054, 0064, 0126, 0128, 0131, 0133.

## 10. Arquitectura propuesta
Superficie A — shell customer  
Superficie B — shell customer con contexto `owner_pending`  
Superficie C — shell owner

No son tres apps distintas; son variaciones de navegación/contexto sobre una shell base.

## 11. Justificación
Evita:
- shell paralela costosa para pending,
- shell customer muda para pending.

Solución MVP: base customer + enriquecimiento contextual pending + owner pleno reservado a aprobados.

## 12. Alternativas y trade-offs
- shell separada para pending: demasiado pesada para MVP,
- sin diferenciación pending: UX degradada,
- elegida: base común con variaciones contextuales por estado.

## 13. Superficie CUSTOMER
Debe mostrar:
- experiencia customer limpia,
- CTAs opcionales a reclamar comercio/beneficios owner.

No debe mostrar:
- accesos owner operativos.

## 14. Superficie owner_pending
Debe significar:
- usuario sigue siendo customer en permisos,
- journey de ownership activo reconocido por shell.

Debe mostrar (al menos uno según diseño):
- banner contextual,
- CTA “Revisar estado de tu solicitud”,
- entry point a tracking de claim,
- aviso de `needs_more_info` si aplica.

No debe mostrar:
- dashboard OWNER operativo pleno.

## 15. Superficie OWNER
Debe habilitar claramente:
- acceso módulo OWNER,
- rutas operativas de gestión,
- entry points owner primarios.

No debe mantener residuos visuales pending ya cerrados.

## 16. Entry points canónicos
CUSTOMER:
- reclamar comercio,
- conocer beneficios owner.

owner_pending:
- ver estado claim,
- completar info faltante,
- entender por qué aún no hay acceso owner.

OWNER:
- ir a dashboard owner,
- entrar a herramientas de gestión.

## 17. Guards y navegación protegida
Reglas:
- customer no entra a rutas owner protegidas,
- pending no entra a rutas owner plenas,
- owner aprobado sí,
- claim tracking disponible para claim vivo relevante,
- conflicto/more-info debe llevar a carril correcto, no error genérico.

La shell debe evitar ofrecer accesos que luego rebotan por permisos.

## 18. Relación con Auth
Shell consume estado ya resuelto desde Auth:
- `unauthenticated`
- `authenticated_customer`
- `authenticated_pending`
- `authenticated_owner`

No reimplementa lógica de claims para inferir pending.

## 19. Relación con OWNER module (0064)
- owner aprobado: acceso real owner,
- pending: variante contextual informativa/revisión,
- customer puro: sin carril owner operativo.

## 20. Relación con claim flow (0126)
Tras envío de claim, shell debe reflejar proceso activo y dar acceso claro a seguimiento.

## 21. Rechazados/cerrados
Cuando pending termina:
- retirar banners pending,
- retirar entry points específicos si no aplican,
- volver a experiencia customer pura,
- evitar residuos visuales.

## 22. Conflictos y duplicados
Shell debe distinguir pending lineal vs pending en revisión especial.

No necesita jerga técnica, sí claridad de estado:
- revisión especial,
- more-info,
- no avance normal.

Nunca comunicar conflicto como “casi owner”.

## 23. Frontend (definición funcional)
Shell debe resolver:
- estructura base de navegación,
- visibilidad de tabs/secciones por estado,
- banners contextuales,
- CTAs principales,
- acceso tracking claim,
- acceso owner dashboard,
- fallback consistente ante cambios de estado.

Estados mínimos:
- no autenticado,
- customer,
- customer + pending,
- owner,
- customer tras cierre/rechazo,
- owner tras aprobación reciente.

## 24. Cambios de estado en sesión viva
Shell debe manejar:
- aprobación en sesión abierta,
- rechazo en sesión activa,
- paso a more-info/conflicto,
- limpieza de pending.

Sin flashes peligrosos ni rutas huérfanas.

## 25. Relación con Splash
Shell no debe montar experiencia “a medias” antes de que Auth termine resolución canónica.

Evitar:
- entrar como customer y saltar a owner segundos después,
- entrar como owner y degradar a pending,
- CTAs que desaparecen por estado mal resuelto.

## 26. UX / microcopy
Pending:
- “Tu solicitud está en revisión”
- “Revisá el estado de tu comercio”
- “Todavía no tenés acceso completo a la gestión”

More-info:
- “Necesitamos un dato más para seguir”
- “Completá la información de tu solicitud”

Owner aprobado:
- “Tu comercio ya está listo para ser gestionado”

Evitar copy técnico interno (“ownership pending”, “estado no sincronizado”).

## 27. Backend
Fuente de verdad: backend + token/claims resueltos por Auth.

Shell no persiste verdad paralela sobre pending/owner.

## 28. Seguridad
- Shell no ofrece rutas owner a customer/pending.
- Claim activo no habilita operación owner.
- Pending no equivale visual/funcionalmente a OWNER.
- Conflictos no degradan guards.
- Navegación minimiza exposición a pantallas no permitidas.

## 29. Datos impactados
- `resolvedAccessState`
- rol efectivo
- flag `owner_pending`
- estado resumido claim
- visibilidad de entry points
- rutas habilitadas
- banners contextuales
- estado visual persistido/caché

## 30. Riesgos si no se actualiza
- pending invisible,
- rutas owner mal ofrecidas,
- UX contradictoria con Auth,
- banners/CTAs obsoletos,
- más soporte por confusión,
- integración claims/ownership “pegada encima”.

## 31. Edge cases
- claim activo tras días sin abrir app,
- aprobación con sesión abierta,
- rechazo en navegación activa,
- conflicto que debe verse como revisión especial,
- more-info solicitado,
- duplicado terminal sin pending residual,
- owner recién aprobado con banners viejos,
- accesos viejos cacheados a owner.

## 32. BDD / aceptación
- Dado customer, cuando entra a shell, entonces ve experiencia base sin accesos owner operativos.
- Dado pending, cuando entra a shell, entonces ve contexto de revisión y tracking claim, sin owner pleno.
- Dado owner aprobado, cuando entra a shell, entonces ve entry points y dashboard owner real.
- Dado rechazo definitivo, cuando vuelve a shell, entonces ya no ve contexto pending.
- Dado claim conflictivo, cuando abre app, entonces ve revisión especial y no acceso owner.

## 33. QA plan
- QA funcional: render por estado, entry points, tracking claim, owner dashboard, limpieza banners.
- QA UX: pending entendido como revisión, no owner parcial.
- QA seguridad: shell no expone accesos indebidos.
- QA integración Auth: estado consumido consistente y no stale.

## 34. Definition of Done
- Shell distingue formalmente customer/pending/owner.
- Definida representación pending en navegación principal.
- Entry points y banners contextuales documentados.
- Alineación explícita con Auth y OWNER module.
- Cubiertos rechazo/conflicto/more-info/aprobación.
- Sin fragmentación innecesaria de shell.

## 35. Plan de rollout
1. Actualizar documentación funcional shell.
2. Sincronizar con Auth y OWNER module.
3. Validar guards y entry points.
4. Probar journeys: customer, pending revisión, pending more-info, pending conflicto, owner aprobado, pending cerrado/rechazado.

## 36. Sincronización documental obligatoria
- `docs/storyscards/0053-mobile-shell.md`
- `docs/storyscards/0054-auth-complete.md`
- `docs/storyscards/0004-role-segment-architecture.md`
- `docs/storyscards/0064-owner-module-business.md`
- `docs/storyscards/0131-owner-claim-role-integration.md`
- `docs/storyscards/0126-merchant-claim-flow.md`

## 37. Cierre ejecutivo
TuM2-0053 deja de modelar shell como binaria y reconoce una tercera superficie:
`customer + owner_pending`.

La shell debe:
- seguir simple para customer,
- acompañar tracking de claim en pending,
- habilitar owner solo cuando backend/Auth lo resuelvan como aprobado.
