# TuM2-0104 — Retención y acceso interno a datos sensibles

Estado: TODO  
Prioridad: P0  
Motivo de actualización: impacto directo de la épica de claims sobre conservación de evidencia, acceso interno restringido, masking, reveal temporal, auditoría y límites de eliminación inmediata.

## 1. Objetivo
Definir la política operativa de conservación y acceso interno del expediente sensible de claims:
- qué se conserva,
- por cuánto tiempo (en términos funcionales),
- quién accede y bajo qué condiciones,
- cómo se minimiza exposición interna,
- cuándo aplica masking/reveal/auditoría,
- y por qué no siempre corresponde eliminación inmediata total.

## 2. Contexto
El claim maneja PII y evidencia sensible (documentos, fotos, datos declarativos, flags de conflicto/duplicado, trazas de revisión).  
Además, producto ya definió:
- cifrado reversible para datos revisables por humanos,
- fingerprints/hashes para matching/antifraude,
- masking por defecto en Admin,
- reveal temporal y auditado,
- límites razonables a supresión inmediata por seguridad/conflicto/auditoría.

## 3. Problema que resuelve
- Evita retención “todo para siempre” o borrado prematuro que rompe trazabilidad.
- Evita acceso interno inconsistente o sobreexposición cotidiana.
- Da marco formal para resolver tensión entre derechos del usuario y seguridad del proceso.
- Permite auditar si acceso interno fue proporcional o excesivo.

## 4. User Stories
- Usuario: confiar en que evidencia sensible no queda expuesta libremente ni retenida sin criterio.
- Usuario: entender por qué ciertos datos pueden conservarse razonablemente aunque solicite eliminación.
- Admin: acceder solo a lo necesario para revisar.
- Plataforma: conservar lo suficiente para validar/auditar/proteger sin sobreexponer.

## 5. Objetivo de negocio
Equilibrar:
- mínima exposición interna,
- retención suficiente para operar y auditar,
- protección antifraude/conflicto,
- respuesta razonable a derechos del usuario,
- costo operativo controlado.

## 6. Alcance IN
- Principios de retención del dominio claims.
- Clasificación funcional de información sensible y conservación diferencial.
- Reglas de acceso interno por necesidad operativa.
- Masking por defecto en herramientas internas.
- Reveal temporal/auditado.
- Lineamientos para documentos/adjuntos.
- Conservación por estado de claim (activo, more-info, conflicto, rechazado, aprobado).
- Límites de exportación masiva de PII.
- Alineación con 0100/0102/0103/0130.

## 7. Alcance OUT
- No fija aún todos los plazos exactos (si requieren validación legal final).
- No detalla implementación técnica fina de claves, buckets o cifrado.
- No reemplaza 0130 ni 0103; los complementa.

## 8. Supuestos
- Claim puede contener datos sensibles.
- Parte requiere revisión humana restringida.
- Parte sirve a matching/antifraude.
- No todo rol interno debe ver todo.
- Deben conservarse trazas mínimas legítimas.

## 9. Dependencias
- 0100, 0101, 0102, 0103.
- 0126, 0128, 0130, 0133.
- `merchant_claims`, storage de adjuntos, auditoría de reveal/acceso.

## 10. Arquitectura de política
Organizar en 4 bloques:
1. Qué se conserva.
2. Conservación funcional por estado y tipo de dato.
3. Quién accede y bajo qué restricciones.
4. Límites de masking/reveal/exportación/eliminación.

## 11. Principios rectores
- Minimización de datos y de acceso.
- Retención proporcional a fin legítimo.
- No conservar indefinidamente sin causa.
- No borrar de inmediato si compromete conflicto/fraude/auditoría.
- Masking por defecto en UI interna.
- Reveal solo cuando haga falta, temporal y auditado.
- No exportación masiva trivial de PII.

## 12. Tipos de información cubiertos
- PII del reclamante (nombre, email, teléfono opcional).
- Evidencia visual (fachada e imágenes complementarias).
- Evidencia documental (constancias, contratos, comprobantes, habilitaciones).
- Datos operativos del expediente (estado, fechas, decisiones, flags).
- Derivados de seguridad (fingerprints/hashes/señales antifraude).
- Trazas de acceso/reveal cuando aplique.

## 13. Conservación funcional por estado
Claim en curso:
- conservar evidencia y datos sensibles necesarios para revisión/decisión.

More-info:
- conservar evidencia previa como contexto obligatorio.

Conflicto/disputa:
- retención más prudente para comparabilidad y trazabilidad.

Rechazado:
- no implica eliminación instantánea universal; puede requerir período razonable por seguridad/auditoría.

Aprobado:
- conservar respaldo histórico razonable; no toda evidencia requiere igual exposición operativa.

## 14. Conservación diferencial por tipo de dato
Datos operativos (estado/timestamps/decisiones/flags):
- retención más prolongada para trazabilidad básica.

Evidencia documental/visual:
- conservación activa durante caso y período posterior razonable según riesgo.

Derivados antifraude:
- conservación con lógica propia para detectar reintentos/patrones abusivos.

Regla clave:
conservar no equivale a exponer ampliamente.

## 15. Acceso interno por need-to-know
- No todo admin necesita ver todo.
- No toda revisión requiere reveal completo.
- Acceso debe atarse a función operativa concreta.
- Modo normal: resumen + masking; reveal como excepción justificada.

## 16. Masking por defecto
En Admin, sensibles ocultos/parcelados por defecto:
- nombre,
- email,
- teléfono,
- documentos identificatorios.

## 17. Reveal temporal y auditado
Reveal debe ser:
- explícito,
- no automático,
- temporal,
- registrado,
- excepcional, no modo estándar.

## 18. Auditoría de acceso interno
Accesos sensibles relevantes (reveal/apertura documentos) pueden quedar auditados para:
- seguridad,
- trazabilidad,
- control interno,
- revisión post-incidente.

## 19. Exportación y copias internas
- Sin export masiva trivial de PII/documentos.
- Sin listados descargables con sensibles completos por defecto.
- Cualquier export excepcional: restringido, justificado y alineado a permisos.

## 20. Relación con derechos del usuario (0103)
Solicitud de ver/corregir/limitar/desistir/eliminar debe evaluarse con límites legítimos de:
- trazabilidad,
- conflicto,
- antifraude,
- auditoría,
- cumplimiento.

## 21. Conflicto/disputa
En conflicto, la retención debe ser más conservadora para preservar integridad del expediente y defensa de decisiones.

## 22. Antifraude/duplicados
Puede conservarse parte de información/derivados para:
- detectar duplicados,
- limitar reintentos abusivos,
- sostener controles de integridad.

## 23. Relación con 0130
0130 define “cómo” proteger/mostrar (cifrado, masking, fingerprint, reveal).  
0104 define “cuánto tiempo”, “quién accede” y “con qué límites” de conservación/exposición.

## 24. Frontend y UX
Evitar promesas engañosas:
- “borrado inmediato total”,
- “nadie interno verá nunca datos”.

Usar mensajes honestos:
- conservación protegida y proporcional,
- acceso interno restringido,
- retención razonable por seguridad/auditoría/conflicto.

## 25. Backend y operación interna
Debe habilitar operación que:
- minimiza reexposición de documentos,
- conserva trazas útiles,
- reduce exposición cuando el caso ya no requiere acceso frecuente,
- no depende de justificaciones en texto libre.

## 26. Seguridad (enunciado)
- Conservación ≠ exposición abierta.
- Reveal no permanente.
- Datos sensibles no forman parte del dominio público.
- Estrategia realista ante entorno web: minimizar/restringir/auditar/desalentar.

## 27. Microcopy sugerido
- “Tu evidencia se conserva de forma protegida mientras sea necesaria para validar el reclamo y resguardar el proceso”.
- “El acceso interno a documentación sensible es restringido”.
- “Algunos datos pueden mantenerse por razones de seguridad, conflicto o auditoría”.
- “No mostramos esta información públicamente”.

## 28. Datos impactados
Retención/acceso de:
- email claim, nombre, teléfono opcional,
- evidencia visual y documental,
- historial de revisión,
- flags conflicto/duplicado,
- eventos de reveal,
- derivados de seguridad/matching.

## 29. Riesgos si no se actualiza
- Criterio difuso de conservación.
- Sobreexposición interna de sensibles.
- Borrado prematuro sin trazabilidad.
- Retención excesiva sin marco.
- Inconsistencias entre UX/legal/operación.

## 30. Edge cases
- Rechazado retenido por período razonable.
- Conflicto que exige conservar más tiempo.
- Desistimiento con trazas mínimas obligatorias.
- Reveal puntual para revisión posterior.
- Solicitud de eliminación con implicancias de seguridad activas.
- Reducción de visibilidad operativa sin eliminación total inmediata.

## 31. BDD / aceptación
- Dado claim sensible, cuando se conserva, política cubre conservación razonable por validación/conflicto/seguridad/auditoría.
- Dado admin revisor, cuando accede a sensible, acceso está restringido y no libre indiscriminado.
- Dado solicitud de eliminación, cuando se evalúa, puede limitarse/diferirse por motivos legítimos.
- Dado conflicto activo, cuando sigue revisión, política cubre retención prudente y exposición controlada.
- Dado claim cerrado, cuando ya no requiere exposición frecuente, política permite reducir visibilidad sin asumir eliminación inmediata total.

## 32. QA plan
- QA documental: coherencia con 0100/0102/0103/0130.
- QA claridad: principios de retención y acceso restringido.
- QA seguridad: reveal/auditoría y no promesas absolutas.
- QA consistencia: conflicto/antifraude/derechos del usuario.

## 33. Definition of Done
- Principios de conservación de claims definidos.
- Acceso interno por necesidad operativa definido.
- Masking por defecto y reveal controlado ratificados.
- Cobertura de conflicto/fraude/auditoría/derechos integrada.
- Sin promesa de borrado inmediato universal.
- Exportación/exposición masiva limitada conceptualmente.
- Alineación cerrada con 0100, 0103 y 0130.

## 34. Plan de rollout
1. Actualizar 0104 interna.
2. Revisar consistencia con 0100/0102/0103/0130.
3. Alinear Admin/reveal/UX del claim.
4. Validar wording legal final contra implementación real antes de producción.

## 35. Sincronización documental obligatoria
- `docs/storyscards/0104-sensitive-data-retention-access.md`
- `docs/storyscards/0100-privacy-policy.md`
- `docs/storyscards/0102-claim-evidence-consent.md`
- `docs/storyscards/0103-user-rights-claims-data.md`
- `docs/storyscards/0128-admin-merchant-claims-review.md`
- `docs/storyscards/0130-merchant-claim-sensitive-data-protection.md`
- `docs/storyscards/0133-merchant-claim-conflicts-and-duplicates.md`

## 36. Cierre ejecutivo
Con esta actualización, 0104 formaliza que:
- evidencia y PII de claim no se exponen libremente,
- acceso interno es por need-to-know,
- masking por defecto + reveal puntual/auditado,
- conservación razonable de trazas/evidencia cuando exista necesidad legítima,
- eliminación inmediata total no siempre es compatible con seguridad, conflicto, antifraude o auditoría.
