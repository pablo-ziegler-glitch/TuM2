# TuM2-0130 — Seguridad y protección de datos sensibles en claims

Estado propuesto: TODO  
Prioridad: P0 (MVP crítica)  
Épica madre: TuM2-0125 — Reclamo de titularidad de comercio  
Depende de: TuM2-0126, TuM2-0127, TuM2-0128, TuM2-0129

## Sync 0127 implementado (2026-04-16)
- Auto-validación usa `merchant_claim_private.fingerprintPrimary` solo para señal interna de reuse (`risk_signal_contact_reuse`).
- No se exponen fingerprints/hashes al claimant.
- Logging técnico de auto-validación se mantiene sin PII (sin email/teléfono/documentos).

## 1. Objetivo
Definir el modelo integral de protección, almacenamiento, exposición controlada y auditoría de datos sensibles del dominio `merchant_claims`.

Decisión central MVP:
- datos revisables por humanos: cifrado reversible + masking,
- datos para matching/antifraude: fingerprints/hashes derivados,
- Admin: oculto por defecto + reveal temporal + permisos + auditoría.

## 2. Contexto
El dominio claims maneja PII y documentación sensible con impacto directo en revisión manual, conflictos de titularidad y transición posterior a OWNER.

Enfoques inválidos para TuM2:
- guardar todo en claro,
- hashear todo aunque se deba revisar visualmente,
- “resolver seguridad después”,
- confiar solo en ocultamiento de UI.

## 3. Problema que resuelve
- Sobreexposición de PII en sistemas internos.
- Modelo técnico incorrecto (hash donde se necesita revisión humana, claro donde no corresponde).
- Fugas por listados, logs, adjuntos, reveals y exports.
- Riesgo legal/reputacional por falta de minimización y trazabilidad.
- Inconsistencia entre capas (storage seguro / admin inseguro o viceversa).

## 4. Objetivo de negocio
Maximizar simultáneamente:
- protección real,
- minimización de datos,
- operabilidad de revisión humana,
- matching/antifraude efectivo,
- baja exposición interna,
- trazabilidad auditable,
- riesgo legal controlado.

## 5. Alcance IN
- Clasificación de datos del claim.
- Definición de cifrado reversible vs fingerprint/hash.
- Reglas de masking y reveal temporal.
- Auditoría de reveal y acceso sensible.
- Protección de documentos y adjuntos.
- Restricciones de exportación/exposición.
- Integración con Admin, validación automática y legales.

## 6. Alcance OUT
- Flujo completo claim (0126).
- Lógica de clasificación automática completa (0127).
- Diseño completo de pantallas Admin (0128).
- Matriz documental por categoría (0129).
- Lógica completa OWNER (0131), phone phase 2 (0132), disputas avanzadas (0133).

## 7. Supuestos
- Email claim = email autenticado.
- Teléfono opcional en MVP.
- Habrá adjuntos potencialmente sensibles.
- No existe imposibilidad absoluta de copia en cliente web una vez revelado.
- Sí existe control de exposición: minimizar, restringir, limitar, auditar.

## 8. Dependencias
Funcionales:
- TuM2-0126, 0127, 0128, 0129, 0131, 0133.

Legales:
- TuM2-0100, 0101, 0102, 0103, 0104.

Arquitectura:
- colecciones claims,
- storage de adjuntos,
- auditoría interna,
- permisos admin/super admin.

## 9. Principios rectores
- Minimización primero.
- Hash no reemplaza cifrado cuando hay revisión humana.
- Cifrado reversible no implica exposición libre.
- Masking por defecto siempre.
- Reveal solo cuando haga falta y auditado.
- No propagar sensibles a logs/proyecciones públicas.
- No mezclar dominio claim sensible con datos públicos de comercio.

## 10. Arquitectura de datos sensible
### Grupo A — Sensibles revisables por humanos
Almacenamiento: cifrado reversible.  
Exposición: enmascarada por defecto, reveal controlado.

### Grupo B — Derivados de matching/antifraude
Almacenamiento: fingerprint/hash derivado.  
Exposición: no orientado a lectura humana.

### Grupo C — Operativos no sensibles
Almacenamiento: claro cuando no sea PII ni sensible.

## 11. Clasificación de datos del claim
Sensibles personales:
- nombre/apellido,
- email visible,
- teléfono,
- observaciones con PII,
- metadatos sensibles de adjuntos.

Sensibles de evidencia:
- contratos, comprobantes, facturas, habilitaciones y adjuntos vinculantes.

Derivados para matching:
- fingerprint email normalizado,
- fingerprint teléfono normalizado,
- huellas documentales (si aplica),
- `ipHash` para abuso (sin IP cruda).

Operativos no sensibles:
- `claimId`, `userId`, `merchantId`,
- `claimStatus`,
- flags de conflicto/duplicado,
- timestamps y estado de revisión.

## 12. Qué va cifrado reversible
Todo dato sensible que pueda necesitar lectura humana posterior:
- nombre/apellido,
- email de revisión,
- teléfono,
- documentos/adjuntos sensibles,
- campos texto libre con identificatorios.

Regla: si un humano autorizado debe ver valor real, hash solo no alcanza.

## 13. Qué va en fingerprint/hash
Para dedupe/matching/antifraude sin exposición:
- fingerprint email,
- fingerprint teléfono,
- fingerprint referencias documentales relevantes,
- huellas técnicas de deduplicación,
- `ipHash`.

No se diseña para lectura humana ni visualización en Admin.

## 14. Qué puede ir en claro
Solo no sensible y necesario:
- estado del claim,
- `categoryId`,
- `zoneId`,
- `merchantId`,
- flags operativos,
- timestamps,
- completitud y tipo de evidencia esperada.

## 15. Masking en Admin
Regla general: todo sensible oculto por defecto.

Ejemplos:
- nombre parcial,
- email parcial,
- teléfono parcial,
- documentos no plenos al abrir detalle.

Listado admin: sin PII completa.

## 16. Reveal temporal
Reveal = acción explícita de admin autorizado para ver temporalmente un dato sensible.

Reglas:
- nunca automático al abrir claim,
- granular por dato o bloque acotado,
- TTL de visibilidad,
- reset al expirar o cambiar contexto,
- auditoría obligatoria.

## 17. Auditoría de reveal
Cada reveal registra mínimo:
- actor,
- timestamp,
- `claimId`,
- tipo de dato revelado,
- superficie de acceso,
- motivo opcional.

## 18. Aclaración crítica sobre copia
No prometer imposibilidad absoluta de copia en web.

Sí exigir:
- oculto por defecto,
- reveal restringido y temporal,
- permisos,
- auditoría,
- no export masivo de PII,
- no exposición innecesaria.

## 19. Documentos y adjuntos sensibles
Reglas:
- sin URLs públicas directas,
- sin previsualización masiva en listados,
- descarga/apertura bajo permisos,
- asociación estricta al claim,
- exposición solo para decisión del caso.

## 20. Uso en validación automática (0127)
Preferir:
- fingerprints,
- metadatos,
- flags derivados,
- completitud documental.

Evitar:
- lectura repetida de PII en claro,
- procesamiento costoso de adjuntos completos sin necesidad.

## 21. Uso en Admin Web (0128)
Modelo de exposición:
- listado: sin PII completa,
- detalle: PII enmascarada,
- reveal: puntual, temporal, auditado,
- documentos: acceso controlado por permiso.

## 22. Retención y minimización
La retención de sensibles debe cubrir solo necesidades de:
- validación,
- auditoría razonable,
- cumplimiento,
- antifraude,
- conflictos abiertos.

Reglas:
- no retención indefinida sin política,
- no duplicar PII en colecciones,
- no copiar PII a proyecciones públicas.

Plazos exactos: se sincronizan con TuM2-0104.

## 23. Exportación, copia y descarga
- Sin export masivo de sensibles en MVP.
- Sin CSV/reportes con PII completa por defecto.
- Descarga de adjuntos solo excepcional, restringida y auditada.

## 24. Logs y observabilidad
- No loggear PII en claro salvo excepción extrema controlada.
- No loggear payloads/documentos completos.
- Loggear IDs, flags y referencias.
- Observar reveals/decisiones sin exponer valores reales.

## 25. Frontend (funcional)
Usuario final:
- explicar uso restringido de información,
- explicar minimización de datos,
- mantener lenguaje claro y no técnico.

Admin:
- estado visible: oculto/revelado/expirado/sin permiso,
- interacción explícita de reveal,
- señal clara de acceso auditado.

## 26. Backend (funcional)
Autoridad backend para:
- persistencia protegida,
- generación de fingerprints,
- serving enmascarado por defecto,
- reveal con control de permisos,
- auditoría y límites de exposición.

Guardrails:
- nunca delegar protección al cliente,
- nunca devolver más PII de la necesaria,
- nunca poblar `merchant_public` con datos de claim.

## 27. Reglas de negocio obligatorias
1. Sensible = privado por defecto.
2. Revisión humana = cifrado reversible + reveal controlado.
3. Matching/antifraude = fingerprints/hashes derivados.
4. Listados admin sin PII completa.
5. Reveal temporal y auditado.
6. No promesa falsa de imposibilidad de copia web.
7. Sin URLs públicas directas a documentos sensibles.
8. Sin exports triviales con PII completa.
9. Sin duplicación innecesaria de sensibles.
10. Alineación obligatoria con legales vigentes.

## 28. Guardrails de costo y performance
- Generar fingerprint una sola vez por transición relevante.
- Evitar releer adjuntos pesados innecesariamente.
- No hidratar sensibles en listados.
- Evitar storage duplicado de documentos.
- Auditoría append-only con payload mínimo.

## 29. Datos impactados
Dominios:
- `merchant_claims`,
- storage de adjuntos,
- logs de auditoría de reveal/acceso,
- fingerprints de matching,
- estados y flags del claim.

Derivados útiles:
- valores enmascarados de display,
- entradas de auditoría,
- metadata de adjuntos,
- historial de acceso sensible.

## 30. Analytics y KPI
Eventos:
- `claim_sensitive_data_reveal_requested`
- `claim_sensitive_data_revealed`
- `claim_sensitive_data_reveal_denied`
- `claim_sensitive_data_reveal_expired`
- `claim_sensitive_document_opened`
- `claim_sensitive_access_audited`

KPI:
- reveals por claim,
- % claims resueltos sin reveal completo,
- reveals por admin,
- accesos a documentos sensibles,
- denegaciones por permisos.

North Star local:
% de claims correctamente resueltos con mínima exposición sensible.

## 31. Edge cases
- Reveal sin permisos.
- Reveal y sesión expirada/cambio de foco.
- Reveals simultáneos sobre mismo dato.
- Formato inesperado de adjunto sensible.
- Observaciones con PII no estructurada.
- Dedupe por fingerprint con dato visible aún oculto.
- Intento de export no permitido.
- Dato que excede retención y requiere cleanup.

## 32. QA plan
- QA funcional: clasificación, masking, reveal, expiración, acceso a docs.
- QA seguridad: permisos, no exposición en listados, no fuga en logs, no URLs públicas.
- QA integración: coherencia con 0126/0127/0128/0129/0131/0133 y 0100–0104.
- QA costo: sin carga excesiva de docs, sin hidratar sensibles de más, auditoría razonable.

## 33. Definition of Done
- Datos claim clasificados.
- Definido qué va cifrado reversible.
- Definido qué va como fingerprint/hash.
- Definido masking por defecto.
- Reveal temporal/auditado formalizado.
- Definida protección de adjuntos y no-export masivo.
- Minimización documentada.
- Alineación explícita con Admin, validación automática y legales.

## 34. Plan de rollout
Fase 1: cierre de definición con 0126/0127/0128/0129/0131 y legales 0100–0104.  
Fase 2: implementación MVP (clasificación, masking, reveal auditado básico, fingerprints).  
Fase 3: endurecimiento (permisos finos, controles de documentos, retención más detallada).  
Fase 4: mejoras (monitoreo de exposición, revisión periódica de accesos, automatización de cleanup).

## 35. Documentos a sincronizar
Crear/mantener:
- `docs/storyscards/0130-merchant-claim-sensitive-data-protection.md`
- `docs/storyscards/0126-merchant-claim-flow.md`
- `docs/storyscards/0127-merchant-claim-auto-validation.md`
- `docs/storyscards/0128-admin-merchant-claims-review.md`
- `docs/storyscards/0129-merchant-claim-evidence-by-category.md`
- `docs/storyscards/0131-owner-claim-role-integration.md`
- `docs/storyscards/0133-merchant-claim-conflicts-and-duplicates.md`

Actualizar por impacto:
- `docs/storyscards/0100-privacy-policy.md`
- `docs/storyscards/0101-terms-and-conditions.md`
- `docs/storyscards/0102-claim-evidence-consent.md`
- `docs/storyscards/0103-user-rights-claims-data.md`
- `docs/storyscards/0104-sensitive-data-retention-access.md`
- `docs/storyscards/0004-role-segment-architecture.md`

## 36. Cierre ejecutivo
TuM2-0130 formaliza el modelo de seguridad del claim para evitar riesgo interno/legal y sostener operación real:
- revisables por humano: cifrado reversible + masking,
- matching/antifraude: fingerprints derivados,
- reveal temporal y auditado,
- protección reforzada de documentos,
- minimización de datos,
- alineación obligatoria con privacidad, términos, consentimiento y retención.
