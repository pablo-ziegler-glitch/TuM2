# Prompt técnico archivado — TuM2-0127

Fecha de recepción: 2026-04-16  
Fuente: conversación Codex (implementación productiva solicitada)

## Resumen fiel del prompt recibido
Se solicitó implementación end-to-end de **TuM2-0127 (Validación automática inicial de claims)** sobre repo real, sin mocks, con foco explícito en:
- seguridad,
- costo Firestore,
- trazabilidad,
- idempotencia.

Requisitos centrales pedidos:
- auditoría previa de `functions/`, `schema/types/`, `docs/storyscards/`, rules e índices;
- reutilizar arquitectura existente y no romper reglas canónicas (dual-collection, Admin SDK only para custom claims, backend authoritative);
- motor de reglas explícito (sin scoring opaco) con función pura + orquestador IO;
- transición automática al entrar a `submitted`;
- precedencia cerrada de outcomes:
  1. `rejected`
  2. `conflict_detected`
  3. `duplicate_claim`
  4. `needs_more_info`
  5. `under_review`
- reason codes estructurados y estables para identidad/evidencia/conflicto/riesgo;
- dedupe/conflicto con queries acotadas, indexadas y con `limit` bajo;
- no mutar `merchant_public`, no conceder OWNER automático, no exponer señales antifraude al claimant;
- outputs consumibles por Admin 0128 y compatibles con 0131 (`owner_pending` sin promoción a owner);
- tests unitarios (dominio), integración/emulador (idempotencia, no-op, writes mínimos, seguridad), y actualización documental.

## Constraints de negocio incluidos en el prompt
- Ambientes válidos: `tum2-dev-6283d`, `tum2-staging-45c83`, `tum2-prod-bc9b4`.
- Uso canónico de `zoneId` y `categoryId` (evitar legacy `zone/category`).
- Rubros MVP canónicos pedidos en prompt:
  - Farmacias
  - Kioscos
  - Almacenes
  - Veterinarias
  - Tiendas de comida al paso
  - Casas de comida / Rotiserías
  - Gomerías
- Prohibición explícita en prompt: no introducir Panaderías/Confiterías como nuevas categorías de negocio en la tarjeta.

## Requerimiento operativo adicional
El prompt pidió explícitamente que, desde esta tarjeta en adelante, los prompts técnicos queden archivados en un archivo asociado a la tarjeta de negocio.
