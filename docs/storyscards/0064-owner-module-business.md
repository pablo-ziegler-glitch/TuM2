# TuM2-0064 — Implementar módulo OWNER

Estado propuesto: UPDATE REQUIRED  
Prioridad: P0  
Motivo de actualización: impacto directo de la nueva épica de reclamo de titularidad sobre Dashboard OWNER, incorporación formal de `owner_pending` y separación entre revisión de claim y ownership aprobado.

## 1. Objetivo
Actualizar el módulo OWNER para distinguir explícitamente:
- usuario sin ownership,
- usuario `owner_pending`,
- usuario `OWNER` aprobado.

Regla central: reclamar un comercio no equivale a gestionarlo.

## 2. Contexto
La definición original de 0064 como dashboard operativo del dueño sigue vigente para OWNER aprobado, pero ahora es insuficiente sin una superficie intermedia para pending.

Con claims formales, hay usuarios que:
- ya reclamaron,
- aún no están aprobados,
- pueden estar en revisión/conflicto/more-info,
- requieren UX contextual sin acceso operativo pleno.

## 3. Problema que resuelve
- Evita mostrar herramientas operativas a no aprobados.
- Evita pending sin superficie clara.
- Evita desalineación entre Auth/Shell y módulo OWNER.
- Evita mezclar revisión de titularidad con operación real.
- Protege semántica del dashboard como centro de control del dueño real.

## 4. User Stories
- Como OWNER aprobado, quiero un dashboard operativo claro para gestionar mi comercio.
- Como pending, quiero una pantalla de revisión que explique estado y próximos pasos.
- Como pending con conflicto/more-info, quiero entender por qué aún no tengo acceso pleno.
- Como plataforma, quiero bloquear acceso operativo prematuro.
- Como admin/sistema, quiero que la aprobación se traduzca en entrada clara a OWNER real.

## 5. Objetivo de negocio
Garantizar simultáneamente:
- valor inmediato para OWNER real,
- claridad para pending,
- cero acceso operativo anticipado.

## 6. Alcance IN
- `owner_pending` incorporado explícitamente en carril OWNER.
- Dashboard operativo reservado a OWNER aprobado.
- Variante contextual pending (OWNER-02).
- Diferenciación panel operativo vs panel de revisión.
- Entry points y restricciones por estado.
- Tratamiento de more-info/conflicto/rechazo.
- Reinterpretación quick actions y banners por estado.
- Alineación con Auth/Shell/Roles.

## 7. Alcance OUT
- No rediseña todos los módulos hijos (productos/horarios/señales).
- No redefine arquitectura técnica de backend/rules.
- No reemplaza 0126/0128/0131/0133; absorbe su impacto en módulo OWNER.

## 8. Supuestos
- OWNER compuesto incluye CUSTOMER.
- `owner_pending` formalizado.
- transición a OWNER solo backend-authoritative.
- pending puede convivir con experiencia customer enriquecida.
- módulo OWNER pleno no se habilita antes de aprobación.

## 9. Dependencias
- TuM2-0004, 0054, 0053, 0126, 0128, 0131, 0133.

## 10. Arquitectura propuesta
Superficie A — OWNER-01 Dashboard operativo pleno (solo OWNER aprobado).  
Superficie B — OWNER-02 Pending/Revisión (solo `owner_pending`, informativa/contextual).  
Superficie C — Sin acceso owner (CUSTOMER puro).

## 11. Justificación
Evita dos errores:
- dashboard pleno para pending (riesgo/expectativa incorrecta),
- ausencia total de superficie pending (ansiedad/confusión).

Solución: separar explícitamente gestión real vs seguimiento de proceso.

## 12. Alternativas y trade-offs
- Mismo dashboard con botones deshabilitados: UX pobre y semántica riesgosa.
- Sin superficie pending: journey ciego.
- Elegida: OWNER-01 real + OWNER-02 contextual.

Trade-off: requiere más precisión de diseño, pero elimina deuda funcional y de permisos.

## 13. Redefinición del propósito
- OWNER aprobado: centro de control operativo.
- owner_pending: referencia de estado y seguimiento para llegar a ownership efectivo.

El carril OWNER ahora separa claramente gestión concedida vs revisión en curso.

## 14. OWNER-01 Dashboard operativo pleno
Aplica solo a OWNER confirmado por backend + token actualizado.

Debe mostrar:
- estado del comercio,
- visibilidad/publicación,
- quick actions operativas,
- alertas operativas (perfil/horarios/publicación),
- acceso a módulos de gestión.

No debe mostrar:
- banners pending viejos,
- CTAs de seguimiento claim como protagonistas.

## 15. OWNER-02 Pending/Revisión
Aplica a `owner_pending` con claim activo.

Debe mostrar:
- mensaje central de revisión,
- estado claim y próximos pasos,
- explicación de acceso aún no completo,
- CTA a seguimiento o completar info,
- contexto del comercio reclamado,
- banners de more-info/revisión especial cuando aplique.

No debe mostrar:
- edición operativa plena (horarios/productos/señales/perfil),
- quick actions plenas sin contexto.

## 16. Relación OWNER-01 vs OWNER-02
Ambas pertenecen al mismo módulo conceptual, con objetivos distintos:
- OWNER-01: operar comercio.
- OWNER-02: acompañar proceso para poder operarlo.

## 17. more_info en pending
Si claim está en `needs_more_info`, OWNER-02 debe priorizar acción:
- hero/banner orientado a completar info,
- CTA principal accionable,
- explicación clara de por qué aún no hay acceso pleno.

No debe quedar en pending genérico pasivo.

## 18. conflicto en pending
En conflicto/revisión especial:
- copy prudente (“solicitud requiere revisión especial”),
- sin revelar terceros ni detalles internos,
- sin señales de “aprobación cercana”.

## 19. rechazado/cerrado
Si claim se cierra negativamente y no hay claim vivo:
- retirar OWNER-02,
- retirar banners/CTAs pending,
- volver a experiencia customer pura.

Sin “fantasmas” de claim cerrado.

## 20. transición pending → owner
Cuando backend consolida aprobación y Auth refresca token:
- entrar a OWNER-01 real,
- limpiar residuos pending,
- transición clara y positiva.

## 21. quick actions y permisos
OWNER:
- quick actions visibles y operativas.

Pending:
- no mostrar quick actions operativas plenas,
- o reemplazarlas por accesos informativos/contextuales.

No usar deshabilitados sin explicación como diseño principal.

## 22. banners y alertas
Banners operativos (solo OWNER):
- visibilidad, perfil, horarios, publicación.

Banners de proceso (pending):
- solicitud en revisión,
- más información requerida,
- revisión especial,
- aún sin acceso completo.

Separar gestión vs proceso.

## 23. relación con Shell/Auth/Roles
Shell decide superficie de entrada según `resolvedAccessState`.
Auth provee estado resuelto (`customer|pending|owner`) tras refresh canónico.
Módulo OWNER representa ese estado; no lo infiere ni lo decide.
0004 define el ciclo; 0064 lo materializa en UX.

## 24. frontend (funcional)
Estados mínimos a contemplar:
- loading inicial,
- owner aprobado,
- pending lineal,
- pending more-info,
- pending conflictivo,
- customer sin acceso owner,
- error de carga,
- transición pending→owner tras refresh real.

No alcanza con cambiar textos sobre misma composición.

## 25. backend (autoridad)
Disponibilidad del dashboard operativo depende de backend:
- ownership real,
- pending activo/cerrado,
- autorización de recursos operativos.

Sin bypass cliente.

## 26. seguridad
1. pending no accede a capacidades operativas plenas.
2. claim activo no equivale a ownership concedido.
3. conflicto/more-info no abren módulos operativos.
4. dashboard pleno exclusivo de OWNER aprobado.
5. UX no debe inducir permisos inexistentes.

## 27. UX / microcopy
OWNER:
- “Así está tu comercio ahora”
- “Revisá cómo aparece tu comercio en TuM2”

Pending:
- “Tu solicitud está en revisión”
- “Todavía no tenés acceso completo a la gestión del comercio”
- “Te avisaremos si necesitamos más información”
- “Cuando termine la revisión, vas a poder administrarlo desde acá”

Evitar:
- “Ya casi sos dueño”
- “Panel bloqueado”
- copy técnico interno de permisos.

## 28. datos impactados
- estado resuelto de acceso (Auth),
- flag `owner_pending`,
- rol efectivo,
- claimStatus resumido,
- merchant reclamado vs merchant administrado,
- visibilidad quick actions,
- banners de proceso/operación,
- rutas del carril owner.

## 29. riesgos si no se actualiza
- UX owner plena a no aprobados,
- pending sin superficie clara,
- dashboard usado como parche de revisión,
- mezcla de alertas operativas y de claim,
- contradicción Auth/Shell/Owner.

## 30. edge cases
- claim enviado y acceso temprano al carril owner,
- pending pasa a more-info,
- conflicto activo sostenido,
- rechazo con UI pending cacheada,
- owner recién aprobado con banners viejos,
- ruta operativa vieja cacheada,
- claim cerrado mientras navega,
- futuro multi-claim/multi-merchant.

## 31. BDD / aceptación
- Dado OWNER aprobado, cuando entra al módulo, entonces ve dashboard operativo pleno.
- Dado pending, cuando entra al carril owner, entonces ve revisión/seguimiento y no dashboard pleno.
- Dado pending con more-info, cuando abre módulo, entonces prioriza completar información.
- Dado conflicto, cuando entra al carril owner, entonces ve revisión especial sin herramientas operativas.
- Dado rechazo definitivo, cuando estado se actualiza, entonces sale de pending y vuelve a carril customer.
- Dado aprobación reciente, cuando Auth refresca token y Shell actualiza, entonces OWNER-01 reemplaza pending.

## 32. QA plan
- QA funcional: owner, pending lineal, pending more-info, pending conflicto, rechazo, transición pending→owner, limpieza de residuos.
- QA UX: OWNER-01 y OWNER-02 se entienden como experiencias distintas.
- QA seguridad: pending sin acceso operativo pleno.
- QA integración: alineación Auth/Shell y ausencia de caminos paralelos.

## 33. Definition of Done
- Distinción formal owner aprobado vs owner_pending.
- Dashboard operativo reservado al OWNER real.
- Variante pending definida y completa.
- Cubiertos more-info/conflicto/rechazo/aprobación reciente.
- Quick actions reinterpretadas por estado.
- Alertas de gestión separadas de alertas de proceso.
- Impacto sobre Auth/Shell documentado.

## 34. Plan de rollout
1. Actualizar documentación de producto de módulo OWNER.
2. Sincronizar con Shell y Auth.
3. Ajustar diseños OWNER-01/OWNER-02.
4. Validar journey claim enviado → aprobación → acceso operativo real.

## 35. Sincronización documental obligatoria
- `docs/storyscards/0064-owner-module-business.md`
- `docs/storyscards/0004-role-segment-architecture.md`
- `docs/storyscards/0054-auth-complete.md`
- `docs/storyscards/0053-mobile-shell.md`
- `docs/storyscards/0131-owner-claim-role-integration.md`
- `docs/storyscards/0126-merchant-claim-flow.md`
- `docs/storyscards/0133-merchant-claim-conflicts-and-duplicates.md`

## 36. Cierre ejecutivo
TuM2-0064 deja de ser una única experiencia homogénea y formaliza:
- OWNER-01 operativo para OWNER aprobado,
- OWNER-02 contextual para `owner_pending`.

Esto protege permisos, reduce confusión y alinea el módulo con el ciclo real de claims y roles: reclamar no equivale a gestionar.
