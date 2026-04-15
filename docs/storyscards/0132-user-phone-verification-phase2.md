# TuM2-0132 — Verificación de teléfono del usuario para fase 2

Estado propuesto: TODO  
Prioridad: P2 (Fase 2 / No bloquea MVP)  
Épica madre: TuM2-0125 — Reclamo de titularidad de comercio  
Depende de: TuM2-0054, TuM2-0126, TuM2-0131

## 1. Objetivo
Definir la verificación de teléfono como capa adicional de confianza para fase 2 en flujos sensibles de TuM2 (claims conflictivos, owner operations críticas, disputas y refuerzos de identidad operativa).

Decisión cerrada:
- MVP: teléfono opcional y sin verificación.
- Fase 2: capacidad selectiva de phone verification donde aporte valor real.

## 2. Contexto
El MVP ya opera con:
- email autenticado como identidad base del claim,
- usuario logueado,
- evidencia comercial,
- transición a OWNER solo por backend autorizado,
- estado `owner_pending`.

Phone verification debe evolucionar de forma progresiva, no como requisito universal prematuro.

## 3. Problema que resuelve
- Evita exigir verificación demasiado temprano (fricción/costo).
- Evita quedar sin estrategia de confianza adicional futura.
- Permite graduar confianza por riesgo/caso.
- Puede reforzar contacto y destrabar revisiones sensibles.
- Evita contaminar MVP con OTP innecesario.

## 4. Objetivo de negocio
Maximizar:
- confianza adicional en flujos sensibles,
- baja fricción en MVP,
- aplicación selectiva por riesgo,
- compatibilidad con claims/roles,
- costo controlado.

## 5. Alcance IN
- Rol funcional de teléfono verificado en ecosistema TuM2.
- Definición explícita de no bloqueo MVP.
- Criterios opcional/recomendado/requerido en fase 2.
- Relación con claim, `owner_pending` y `OWNER`.
- Impacto en Auth/perfil/UX.
- Lineamientos de seguridad/privacidad del dato teléfono.

## 6. Alcance OUT
- Implementación técnica de proveedor OTP/canal.
- Costeo detallado SMS/WhatsApp/voice.
- Integración backend final con proveedor.
- Scoring antifraude avanzado.
- Reemplazo de email como identidad principal del claim.

## 7. Supuestos
- Teléfono no requerido en MVP.
- Email sigue siendo identidad principal del claim.
- OWNER no depende de phone verification en MVP.
- Estado sensible siempre backend-driven.
- Debe diseñarse con control de costo y antiabuso.

## 8. Dependencias
Funcionales:
- TuM2-0054, 0126, 0131, 0130, 0133.

Legales:
- privacidad, términos, consentimiento específico si aplica.

## 9. Principios rectores
- No bloquear MVP por teléfono.
- No reemplazar email autenticado.
- Señal complementaria, no atajo de aprobación.
- Aplicación selectiva según riesgo.
- No exponer teléfono completo innecesariamente.
- No mezclar phone verification con grants de permisos.
- No sustituir evidencia documental por OTP.

## 10. Arquitectura propuesta
Capacidad de confianza en perfil, desacoplada del claim base e integrable cuando sea necesario.

Estados sugeridos:
- no informado,
- informado no verificado,
- verificación pendiente,
- verificado,
- expirado/invalidado (si aplica futuro).

## 11. Rol del teléfono verificado
No es:
- prueba suficiente de titularidad,
- reemplazo de evidencia documental,
- sustituto de revisión manual,
- condición automática de OWNER.

Sí puede ser:
- señal adicional de confianza,
- refuerzo en carriles sensibles,
- requisito futuro de acciones owner críticas,
- señal útil para contacto/recuperación.

## 12. Casos de uso futuros recomendados
- Claims sensibles/conflictivos.
- Operaciones owner críticas.
- Disputas o duplicados.
- Refuerzo de identidad operativa.
- Procesos de contacto/recuperación definidos por producto.

## 13. Casos donde no debe exigirse
En MVP y salvo excepción futura explícita:
- login estándar,
- navegación customer,
- inicio de claim básico,
- claims de bajo riesgo con evidencia suficiente.

## 14. Criterio opcional / recomendado / requerido
Opcional:
- perfil general,
- claim MVP estándar,
- uso normal sin conflicto.

Recomendado:
- `owner_pending` delicado,
- rubros sensibles,
- fricción documental.

Requerido:
- solo en fase posterior y en flujos explícitos de alto riesgo.

## 15. Relación con claim
Regla central: claim base MVP no depende de teléfono verificado.

En fase 2 puede usarse como condición adicional en:
- conflicto,
- mayor sensibilidad,
- necesidad de confianza reforzada.

No reemplaza: fachada, documentación, revisión admin, aprobación backend.

## 16. Relación con owner_pending y OWNER
- `phone_verified=true` no implica OWNER.
- `phone_verified=false` no implica rechazo automático en MVP.
- Es atributo complementario de confianza, no núcleo del modelo de permisos.

## 17. Relación con Auth y perfil
Auth fase 2 debe contemplar:
- persistencia del estado de verificación,
- lectura clara post-login/refresh,
- UX desacoplada del login base.

Ubicación natural producto: perfil/cuenta/confianza del usuario.

## 18. Frontend (funcional)
UX esperada: breve, clara, no invasiva.

Estados UI:
- sin teléfono,
- teléfono no verificado,
- código enviado/pending,
- verificado,
- error/reintento bloqueado temporal.

Copy sugerido:
- “Podés verificar tu teléfono para sumar confianza a tu cuenta”.
- “Todavía no necesitás verificar tu teléfono para continuar”.

## 19. Backend (funcional)
Debe:
- almacenar estado de teléfono y verificación,
- invalidar estado al cambiar número,
- limitar reintentos/abuso,
- exponer señal a módulos autorizados.

Guardrails:
- backend authoritative de verificado,
- no grants owner por teléfono,
- no exponer número completo de más.

## 20. Reglas de seguridad obligatorias
1. Teléfono = dato sensible.
2. Verificación = backend authoritative.
3. No reemplaza claim approval ni evidencia documental.
4. No exposición completa innecesaria.
5. Rate limits y antiabuso.
6. Cambio de número invalida o separa verificación previa.
7. Sin escalación de permisos por phone verification.

## 21. Costos y eficiencia
Riesgos:
- OTP masivo,
- reenvíos sin control,
- obligatoriedad innecesaria.

Estrategia:
- no activar en MVP,
- aplicar selectivo en fase 2,
- límites de frecuencia,
- medir costo/valor antes de masificar.

## 22. Datos impactados
Dominios:
- perfil usuario,
- estado de verificación,
- señales de confianza para claims sensibles,
- owner_pending,
- legales/consentimiento.

Datos:
- phone,
- phoneVerified,
- verifiedAt,
- lastAttemptAt,
- pending state,
- re-verification required (futuro).

## 23. Reglas de negocio detalladas
- MVP: teléfono opcional y sin verificación.
- Email autenticado sigue como identidad principal.
- Phone verification es fase 2.
- Señal complementaria, no prueba de titularidad.
- No otorga OWNER automáticamente.
- Puede pedirse en flujos sensibles futuros.
- Cambio de teléfono invalida/revisa estado.
- Uso cubierto por privacidad/términos al activarse.

## 24. Analytics y KPI
Eventos:
- `phone_verification_prompt_viewed`
- `phone_verification_started`
- `phone_verification_code_sent`
- `phone_verification_completed`
- `phone_verification_failed`
- `phone_verification_abandoned`
- `phone_verification_required_for_sensitive_flow_viewed`

KPI:
- tasa de inicio/éxito,
- abandono,
- reintentos promedio,
- costo por verificación exitosa,
- impacto en resolución de casos sensibles.

North Star local:
% de flujos sensibles reforzados con phone verification sin fricción/costo desproporcionados.

## 25. Edge cases
- Teléfono cargado no verificado.
- Verificado y luego cambio de número.
- Reintentos excesivos.
- Claim sensible sin teléfono verificado.
- Claim legítimo MVP aprobado sin teléfono verificado.
- Conflicto que sugiere verificación.
- Fallo proveedor OTP sin romper flujo claim.
- OWNER sin teléfono verificado sigue OWNER si no era condición.

## 26. QA plan
- QA funcional: alta teléfono, verificación, cambio estado, error/reintento, no bloqueo MVP.
- QA UX: beneficio claro, no coerción, no confusión con OWNER.
- QA seguridad: no exposición indebida, backend authoritative, rate limits, sin grants indebidos.
- QA costo: envíos, retries, costo/valor, no activación masiva accidental.
- QA integración: auth/profile, claim sensible, owner_pending/OWNER, privacidad/consentimiento.

## 27. Definition of Done
- Documentado que no bloquea MVP.
- Documentado que teléfono MVP es opcional/sin verificación.
- Definido rol fase 2 como señal complementaria.
- Relación con claim/owner_pending/OWNER formalizada.
- Explícito que no reemplaza evidencia ni aprobación.
- Riesgos de costo/abuso identificados.
- Alineación con privacidad y protección de datos.
- Lista para priorizar/postergar sin romper MVP.

## 28. Plan de rollout
Fase 1: cerrar definición y dejar explícitamente fuera de MVP obligatorio.  
Fase 2: capacidad básica de verificación en perfil.  
Fase 3: integración selectiva en flujos sensibles.  
Fase 4: medición de adopción/costo/impacto antes de ampliar.

## 29. Documentos a sincronizar
Crear/mantener:
- `docs/storyscards/0132-user-phone-verification-phase2.md`
- `docs/storyscards/0054-auth-complete.md`
- `docs/storyscards/0126-merchant-claim-flow.md`
- `docs/storyscards/0131-owner-claim-role-integration.md`

Actualizar por impacto:
- `docs/storyscards/0100-privacy-policy.md`
- `docs/storyscards/0101-terms-and-conditions.md`
- `docs/storyscards/0103-user-rights-claims-data.md`
- `docs/storyscards/0130-merchant-claim-sensitive-data-protection.md`

## 30. Cierre ejecutivo
TuM2-0132 formaliza que phone verification:
- no contamina MVP,
- vive en fase 2 como señal de confianza,
- puede aplicarse a carriles sensibles,
- no reemplaza evidencia ni revisión admin,
- no concede OWNER,
- y debe tratarse siempre como dato sensible con costo controlado.
