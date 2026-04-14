# TuM2-0054 — Auth completa (actualización para dominio claim)

Estado: DONE (actualizado)  
Prioridad: P0

## Objetivo de esta actualización
Alinear autenticación con reglas del dominio claim de titularidad.

## Reglas canónicas incorporadas
- El email del claim es siempre el email autenticado actual.
- No existe campo alternativo de email en claim (MVP).
- Teléfono en MVP: opcional y sin verificación.
- Verificación de teléfono se mueve a TuM2-0132 (fase 2).

## Definiciones funcionales
- Auth debe exponer email autenticado como fuente única del claim.
- Se debe contemplar `owner_pending` en post-login/splash/guards.
- Preparar capacidad técnica para fase 2 de phone verification sin bloquear MVP.
- Definición pendiente de negocio/legal: si email no verificado bloquea claim o solo incrementa riesgo manual.

## Integración con claims
- Claim se inicia solo con sesión válida.
- Identidad de claim se deriva de `uid + email autenticado`.
- Cambios de email autenticado deben quedar auditables respecto de claims abiertos.

## Dependencias
- TuM2-0004 roles.
- TuM2-0126 flujo claim.
- TuM2-0131 integración claim-roles.
- TuM2-0100/0101/0102 lineamientos legales.

## Guardrails de costo Firestore
- Evitar múltiples lecturas de perfil/auth en cascada para construir identidad de claim.
- Estado auth/claim resumido y cacheado con TTL para splash/guards.
- Sin polling agresivo en pantalla de login/splash para estado de claim.
