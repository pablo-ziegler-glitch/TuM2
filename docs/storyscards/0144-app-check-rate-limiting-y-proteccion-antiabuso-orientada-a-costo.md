# TuM2-0144 — App Check, rate limiting y protección anti-abuso orientada a costo

## 1. Estado y metadata
- **Estado:** TODO
- **Prioridad:** P0
- **Dependencia madre:** TuM2-0135
- **Dependencias funcionales:** TuM2-0088, TuM2-0122, TuM2-0128, TuM2-0130

## 2. Objetivo
Reducir el costo provocado por abuso, scraping y llamadas no legítimas a funciones o recursos caros, endureciendo App Check y rate limiting sin frenar el MVP.

## 3. Contexto
Existe deuda conocida: `enforceAppCheck: false` en callables admin.
Eso no solo es un problema de seguridad; también es un problema económico.

## 4. Problema
Sin controles:
- bots y scripts pueden disparar lecturas y callables caros,
- scraping puede presionar búsquedas y datasets públicos,
- endpoints admin mal protegidos pueden volverse superficie de costo y riesgo.

## 5. Alcance IN
- App Check real en staging/prod,
- revisión de endpoints caros,
- rate limiting por callable/flujo donde aplique,
- defensa anti scraping básica,
- reglas de rechazo temprano para requests inválidas.

## 6. Alcance OUT
- WAF enterprise,
- antifraude comportamental avanzado,
- sistemas externos complejos.

## 7. Decisiones canónicas
- App Check obligatorio en staging/prod para superficies administrativas y callables sensibles.
- Rate limiting donde el costo potencial lo justifique.
- Validar auth, claims, payload y cuotas antes de hacer lecturas caras.

## 8. Arquitectura propuesta
```text
client request
   |
   +--> App Check validation
   +--> auth/claims validation
   +--> rate limit / abuse checks
   +--> payload validation
   |
   v
business logic / Firestore access
```

## 9. Frontend
- errores claros:
  - “No pudimos validar la solicitud”
  - “Intentá nuevamente en unos minutos”
- no exponer detalles técnicos de protección.

## 10. Backend
Prioridades:
- admin callables
- imports
- resolución de claims
- acciones sensibles owner/admin

Rate limit sugerido:
- por UID,
- por `ipHash` donde aplique,
- por ventana temporal,
- con structured logs.

Guardrail:
No leer 10 documentos para después descubrir que la request debía ser rechazada por cuota/autorización.

## 11. Seguridad
Esto es seguridad y costo a la vez:
- baja abuso,
- baja superficie de scraping,
- y baja costo marginal de tráfico ilegítimo.

## 12. UX / Producto
La protección no debe sentirse hostil para usuarios reales.
Se prioriza:
- mensajes neutros,
- retry prudente,
- soporte si una acción crítica queda bloqueada por error.

## 13. Datos impactados
- callables admin
- claims
- imports
- auth flows
- logs de abuso / rate limiting
- `ipHash` y señales auxiliares

## 14. APIs y servicios
- App Check
- Cloud Functions
- Firestore
- Auth
- Remote Config si hiciera falta parametrizar límites

## 15. Métricas internas
- `app_check_rejected_count`
- `rate_limit_rejected_count`
- `invalid_payload_rejected_count`
- `abuse_suspected_count`

## 16. Testing
- validadores,
- límites,
- ventanas temporales,
- request con App Check válido,
- request sin App Check,
- request sobre cuota,
- scripts básicos de abuso.

## 17. DevOps
- App Check activo en staging/prod,
- listas de debug acotadas solo a dev,
- alertas por picos de rechazo,
- documentación operativa.

## 18. Riesgos
- falsos positivos,
- fricción en entornos de prueba,
- olvidarse de proteger un callable caro.

## 19. Definition of Done
- callables críticos con App Check real,
- rechazo temprano implementado,
- rate limiting en superficies de mayor riesgo,
- métricas de abuso visibles.

## 20. Rollout
1. staging
2. claims/admin
3. imports
4. resto de callables caros
5. prod gradual

## 21. Checklist final
- [ ] App Check activo donde corresponde
- [ ] `enforceAppCheck` endurecido
- [ ] rate limiting básico
- [ ] rechazo temprano
- [ ] métricas de abuso/costo
