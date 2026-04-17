# TuM2-0067 — Implementar carga de señales operativas

Estado: DONE

## 1. Objetivo

Permitir que el OWNER gestione señales operativas manuales de su comercio para reflejar el estado real del local en tiempo casi real, impactando correctamente en la experiencia pública del vecino y en la proyección derivada de `merchant_public`.

Esta tarjeta cubre la capa de “información viva” que complementa a los horarios base. Los horarios expresan el funcionamiento esperado; las señales operativas expresan el estado real actual.

---

## 2. Contexto

TuM2 se posiciona como una capa digital del comercio real hiperlocal. En ese contexto, una ficha pública útil no puede depender únicamente de horarios cargados una vez. Tiene que poder reflejar contingencias y capacidades operativas actuales del negocio.

Ejemplos reales:
- Un comercio normalmente abierto puede cerrar por un imprevisto.
- Un comercio puede estar abierto pero operando además con delivery.
- Un comercio puede recibir pedidos por WhatsApp y eso debe estar visible.
- Un OWNER puede necesitar forzar un “abierto ahora” cuando el horario base no refleja una situación excepcional.

Esta tarjeta debe convivir con las reglas no negociables del proyecto:
- `merchant_public` nunca se escribe desde cliente.
- La proyección pública debe recalcularse desde Cloud Functions.
- La lógica derivada de `isOpenNow` debe centralizarse en backend.
- Todas las decisiones deben respetar el patrón dual-collection `merchants` + `merchant_public`.

---

## 3. User Story

**Como dueño de un comercio, quiero actualizar rápidamente señales operativas como “cerrado temporalmente”, “delivery propio” o “pedidos por WhatsApp”, para que los vecinos vean el estado real de mi local y no se acerquen al comercio con información desactualizada.**

Historia crítica de negocio:
**Como dueño que sufrió un imprevisto, quiero marcar “Cerrado temporalmente” para evitar que vecinos vayan hasta el local y encuentren la persiana baja.**

---

## 4. Alcance IN / OUT

### IN (MVP Fase 2)
- Pantalla OWNER para edición manual de señales operativas.
- Persistencia en colección `merchant_operational_signals/{merchantId}`.
- Toggles MVP:
  - `temporaryClosed`
  - `hasDelivery`
  - `acceptsWhatsappOrders`
  - `openNowManualOverride`
- Registro de frescura del dato:
  - `updatedAt`
  - `updatedBy`
- Recalcular proyección pública luego de cada cambio.
- Prioridad de señales manuales sobre horarios base para determinar `isOpenNow`.
- Visualización del timestamp de última actualización en la UI OWNER.
- Validaciones de combinaciones conflictivas.
- Analytics mínimos de uso.

### OUT (MVP)
- Expiración automática de señales.
- Programación futura de señales.
- Señales por franjas horarias.
- Detección automática basada en comportamiento.
- Moderación comunitaria o reputacional de señales.
- Push notifications al OWNER por señales “viejas”.
- Señales avanzadas por rubro fuera del set MVP.

---

## 5. Supuestos

- Existe un `merchantId` asociado al OWNER autenticado.
- La colección `merchant_operational_signals` ya forma parte del modelo canónico del sistema.
- La proyección pública se recalcula desde Cloud Functions sobre `merchant_public`.
- Existe o existirá una función central `computeMerchantPublicProjection()` que consolida horario, señales y campos derivados.
- `updatedAt` debe ser `serverTimestamp`, no generado por cliente.
- El OWNER solo puede editar señales de su propio comercio.
- `openNowManualOverride` tiene alcance MVP simple: forzar estado abierto manualmente, pero no reemplaza el cierre temporal.
- Si no existe documento de señales, el sistema debe resolver con defaults seguros.

---

## 6. Arquitectura propuesta

### Diagrama conceptual

```text
OWNER App (Flutter)
   |
   | write
   v
merchant_operational_signals/{merchantId}
   |
   | onWrite trigger (Cloud Functions)
   v
computeMerchantPublicProjection()
   |
   | write
   v
merchant_public/{merchantId}
   |
   | read
   v
Ficha pública / búsqueda / abierto ahora / farmacias / listados
```

### Justificación

Esta arquitectura mantiene intacta la regla central del proyecto: los clientes no escriben proyecciones públicas. El OWNER escribe únicamente el documento fuente operativo; Cloud Functions recalcula la proyección pública derivada y consistente.

### Alternativas y trade-offs

**Alternativa A — Cálculo en cliente**
- Ventaja: menos complejidad backend inicial.
- Desventaja: inconsistencia entre plataformas, riesgo de manipulación, bugs de sincronización, lógica duplicada.
- Veredicto: descartada.

**Alternativa B — Escritura directa de `isOpenNow` en cliente**
- Ventaja: implementación rápida.
- Desventaja: rompe regla no negociable, aumenta superficie de fraude y errores.
- Veredicto: descartada.

**Alternativa C — Documento fuente + proyección derivada en Cloud Functions**
- Ventaja: consistencia, auditabilidad, seguridad, compatibilidad con dual-collection.
- Desventaja: más trabajo backend y latencia eventual de trigger.
- Veredicto: opción correcta para TuM2.

---

## 7. Datos impactados

### Colección principal
`merchant_operational_signals/{merchantId}`

### Estructura propuesta MVP

```json
{
  "merchantId": "merchant_123",
  "temporaryClosed": false,
  "hasDelivery": false,
  "acceptsWhatsappOrders": false,
  "openNowManualOverride": false,
  "updatedAt": "serverTimestamp",
  "updatedBy": "uid_owner_123"
}
```

### Documento derivado impactado
`merchant_public/{merchantId}`

Campos afectados indirectamente:
- `isOpenNow`
- `badges`
- `operationalSignalsSummary` (si se implementa snippet derivado)
- `sortBoost` (solo si el algoritmo lo considera)
- `lastOperationalUpdateAt` o equivalente derivado, si se define

### Defaults seguros
Si no existe documento:
- `temporaryClosed = false`
- `hasDelivery = false`
- `acceptsWhatsappOrders = false`
- `openNowManualOverride = false`

---

## 8. Reglas de negocio

### Prioridad operativa para determinar `isOpenNow`

Orden de evaluación recomendado:

1. Si `temporaryClosed == true` → `isOpenNow = false`
2. Si `temporaryClosed == false` y `openNowManualOverride == true` → `isOpenNow = true`
3. Si no hay overrides manuales, evaluar horarios base (`merchant_schedules`)
4. Si no hay horarios válidos, fallback seguro → `isOpenNow = false`

### Razón de negocio
El cierre temporal debe dominar la lógica porque es el caso más crítico de frustración de usuario. Si un comercio está marcado como cerrado temporalmente, el sistema no debe mostrarlo como abierto aunque el horario base diga lo contrario.

### Restricciones de combinación
- `temporaryClosed = true` y `openNowManualOverride = true` es combinación conflictiva.
- Para MVP, debe resolverse de dos maneras:
  - UI: impedir activación simultánea.
  - Backend: si llega combinación inválida, `temporaryClosed` tiene prioridad absoluta.

### Frescura del dato
Todo cambio debe actualizar `updatedAt` para permitir exposición de la recencia del dato tanto en UI OWNER como eventualmente en la ficha pública.

---

## 9. Subtareas por capa

### 9.1 Flutter Mobile — OWNER

#### Pantalla
Nueva vista dentro del módulo OWNER para “Señales operativas”.

#### Componentes
- Switch/ListTile: `Cerrado temporalmente`
- Switch/ListTile: `Tiene delivery propio`
- Switch/ListTile: `Acepta pedidos por WhatsApp`
- Switch/ListTile: `Forzar abierto ahora`
- Texto auxiliar: `Última actualización`
- Estado visual de guardado / error / sincronización

#### Comportamiento
- Carga inicial desde `merchant_operational_signals/{merchantId}`
- Si no existe doc, mostrar defaults y crear al primer save
- Guardado con feedback inmediato
- Deshabilitar o bloquear `openNowManualOverride` cuando `temporaryClosed == true`
- Mostrar explicación breve de impacto:
  - “Cerrado temporalmente” oculta el estado abierto aunque el horario indique lo contrario
  - “Forzar abierto ahora” reemplaza temporalmente el horario base

#### Estado
- Riverpod provider para fetch y save
- Estados:
  - loading
  - loaded
  - saving
  - success
  - error
  - offline-pending (opcional MVP light)

#### UX crítica
- No mostrar términos técnicos como override
- Lenguaje claro y operativo
- Evitar microcopy ambiguo

---

### 9.2 Backend — Firestore

#### Fuente editable
`merchant_operational_signals/{merchantId}`

#### Seguridad
El OWNER autenticado solo puede escribir el documento de su comercio.

#### Validaciones mínimas
- Tipos booleanos válidos
- `updatedAt` escrito por backend / servidor
- `updatedBy == auth.uid` o asignado server-side
- Documento solo editable por owner o admin

#### Recomendación de ownership
La regla no debe depender de lecturas extras evitables. Dado que existe deuda conocida en rules por lecturas redundantes, se debe minimizar el costo de autorización. Idealmente resolver ownership con estructura o claims cuando sea posible, o con la menor cantidad de lecturas adicionales.

---

### 9.3 Cloud Functions

#### Trigger
`onWrite` o `onDocumentWritten` sobre:
`merchant_operational_signals/{merchantId}`

#### Responsabilidades
- Leer señales actuales
- Leer horarios base del comercio
- Recalcular `isOpenNow`
- Recalcular badges operativos derivados
- Actualizar `merchant_public/{merchantId}`
- Escribir `updatedAt` derivado si corresponde
- Mantener consistencia cross-feature:
  - búsqueda
  - ficha pública
  - vista abierto ahora
  - vista farmacia de turno si aplica

#### Requisito crítico
No duplicar lógica de prioridad entre múltiples funciones. Toda lógica debe centralizarse en una sola unidad de negocio reutilizable, idealmente dentro de `computeMerchantPublicProjection()` o helper equivalente.

#### Impacto en deuda técnica
Esta tarjeta toca componentes sensibles:
1. `buildSearchKeywords()` no implementado en la proyección pública
2. `nightlyRefreshOpenStatuses` con riesgo de escalabilidad
3. Inconsistencias de naming en tipos (`zone/category` vs `zoneId/categoryId`)

La implementación de señales no debe introducir nueva dispersión lógica ni más nomenclaturas inconsistentes.

---

## 10. Frontend

### Stack
- Flutter Mobile
- `go_router`
- `flutter_riverpod`

### Estado
- Provider para cargar y mutar señales del merchant actual
- Estado optimista moderado: puede reflejar toggle visual inmediato, pero debe revertir si falla persistencia

### Errores y flujos críticos
- Error de red al guardar
- Doc inexistente al cargar
- Conflicto de estados
- OWNER sin merchant asociado
- Token con claims stale luego de onboarding

### Offline
Para MVP, aceptable un manejo básico:
- Si no hay conectividad, informar “No se pudo actualizar”
- Opcional: cola local simple si ya existe patrón utilitario reusable
- No inventar sincronización compleja si no está definida en arquitectura Flutter actual

### Accesibilidad
- Labels claros
- Área táctil cómoda
- Contraste suficiente
- Estados visuales no dependientes solo del color
- Texto auxiliar explicando impacto

### Performance
- 1 lectura del doc de señales
- 1 escritura por cambio o 1 submit agrupado según UX elegida
- Preferible submit explícito si se quiere reducir writes
- Preferible autosave si se prioriza inmediatez
- Recomendación MVP: **guardar por acción con debounce leve o botón “Guardar cambios”** según lo que mejor calce con OWNER UX.
- Para evitar múltiples writes consecutivos innecesarios, se recomienda botón de guardar en MVP.

### Seguridad cliente
- Nunca calcular ni persistir `isOpenNow` desde cliente
- Nunca escribir `merchant_public`
- Nunca confiar en defaults de UI como fuente de verdad

---

## 11. Backend

### Arquitectura
- Firestore como fuente de datos operativos
- Cloud Functions TypeScript como capa derivada
- `merchant_public` actualizado exclusivamente por backend

### API / contratos
No se requiere callable dedicada para MVP si el documento puede escribirse con rules seguras. Sin embargo, hay dos opciones:

**Opción A — Escritura directa a Firestore**
- Menos latencia
- Menos código
- Más dependencia de rules

**Opción B — Callable `updateOperationalSignals`**
- Validación más fuerte
- Auditoría más clara
- Más control de anti-abuso
- Compatible con App Check estricto

#### Recomendación
Para consistencia con la dirección del proyecto y mejor control de validación, **considerar callable** si el módulo OWNER va a crecer.  
Para MVP estricto y menor costo de implementación, **Firestore directo** puede ser aceptable si las rules quedan sólidas.

### Validación
- Booleanos obligatorios
- Sanitización de payload
- No aceptar campos extra peligrosos
- Ignorar o rechazar unknown fields
- Server timestamp para auditoría

### Auth/Authz
- Solo OWNER del merchant
- ADMIN full access
- CUSTOMER sin permisos de escritura

### Rate limiting
No es crítico en OWNER normal, pero sí conviene evitar spam toggling:
- App layer: deshabilitar múltiples submits simultáneos
- Backend: opcional throttling si se usa callable

### Concurrencia
- Dos dispositivos OWNER cambiando estado
- Estrategia MVP: last write wins
- Mostrar siempre timestamp más reciente

### Logs
Registrar:
- merchantId
- actor uid
- señales cambiadas
- valores previos/nuevos
- resultado de proyección

---

## 12. Seguridad

### Threat model
Actores:
- OWNER legítimo
- Usuario autenticado no owner intentando escribir señales ajenas
- Cliente manipulando requests
- Script automatizado intentando togglear estados
- Error humano del propio OWNER

### Riesgos OWASP / app threats
- Broken Access Control
- IDOR sobre `merchant_operational_signals/{merchantId}`
- Manipulación de payload
- Desincronización entre fuente y proyección
- Bypass de reglas desde cliente modificado
- Abuse toggling para aparecer abierto/cerrado de forma engañosa

### Controles requeridos
- Rules estrictas por ownership
- No exponer escritura de proyección pública
- Server timestamp
- Logging
- App Check habilitado en staging/prod si se usa callable o servicios sensibles
- Validaciones server-side si existe callable
- Reglas que impidan campos no esperados, si se puede modelar de forma robusta

### Cifrado / secretos
- Sin secretos en cliente
- Sin lógica sensible en app
- Nada de custom claims desde cliente

### Hardening
- Mantener nombres de campos canónicos
- Centralizar lógica derivada
- Evitar lecturas innecesarias en rules por impacto de costo y performance

---

## 13. UX / Producto

### Fricción a resolver
El OWNER necesita actuar rápido. La pantalla no debe sentirse burocrática.

### Decisiones UX recomendadas
- No esconder señales en submenús profundos
- Usar nombres operativos reales
- Mostrar impacto de cada toggle
- Mostrar cuándo fue la última actualización
- Confirmación liviana solo para el caso más riesgoso: `Cerrado temporalmente`

### Estados vacíos
Si no hay doc:
- Mostrar toggles en falso
- Texto: “Todavía no configuraste señales operativas”

### Feedback
- Guardando…
- Cambios guardados
- No se pudo guardar
- Última actualización: hace X min

### Edge cases UX
- Señal vieja: mostrar advertencia sutil si pasó mucho tiempo
- Merchant sin horarios: aclarar que “Abierto ahora” depende de horarios o señal manual
- Conflicto entre toggles: prevenir antes de guardar

---

## 14. Testing

### Unit tests
- Prioridad de señales sobre horarios
- Resolución de conflictos
- Defaults si no existe doc
- Timestamp update

### Integration tests
- Escritura de señal → trigger → actualización en `merchant_public`
- OWNER válido puede escribir
- CUSTOMER no puede escribir
- ADMIN sí puede

### E2E
- OWNER entra a pantalla
- Activa `temporaryClosed`
- Ve confirmación de guardado
- Ficha pública refleja comercio cerrado

### Seguridad
- Test de IDOR
- Test de payload malicioso
- Test de escritura a merchant ajeno
- Test de campos extra

### Carga
- No crítico por volumen MVP, pero sí validar que múltiples toggles no disparen cascadas excesivas

### Mocks
- Mock de Firestore
- Mock de Cloud Functions local
- Mock de provider Riverpod

---

## 15. Criterios de aceptación (BDD)

### Escenario 1 — Activar “Cerrado temporalmente”
```gherkin
Given un OWNER autenticado con un merchant asociado
And el comercio tiene horarios cargados que indican que está abierto ahora
When el OWNER activa la señal "Cerrado temporalmente"
And guarda los cambios
Then el documento merchant_operational_signals del comercio se actualiza
And el campo temporaryClosed queda en true
And el campo updatedAt se actualiza con timestamp de servidor
And Cloud Functions recalcula la proyección pública
And merchant_public.isOpenNow queda en false
And la ficha pública muestra el comercio como cerrado
```

### Escenario 2 — Activar “Pedidos por WhatsApp”
```gherkin
Given un OWNER autenticado con un merchant asociado
When activa la señal "Pedidos por WhatsApp"
And guarda los cambios
Then el documento merchant_operational_signals se actualiza
And acceptsWhatsappOrders queda en true
And la proyección pública refleja la disponibilidad de pedidos por WhatsApp
```

### Escenario 3 — Conflicto entre cierre temporal y forzar abierto
```gherkin
Given un OWNER autenticado con un merchant asociado
When intenta dejar activas simultáneamente las señales "Cerrado temporalmente" y "Forzar abierto ahora"
Then la interfaz impide la combinación o corrige el conflicto
And en backend temporaryClosed tiene prioridad absoluta
```

### Escenario 4 — Señales inexistentes
```gherkin
Given un OWNER autenticado con un merchant asociado
And no existe documento en merchant_operational_signals para ese merchant
When entra a la pantalla de señales operativas
Then ve todos los toggles en false por default
And puede guardar una configuración inicial
```

---

## 16. Analytics

### Eventos mínimos
- `owner_operational_signal_opened`
- `owner_operational_signal_saved`
- `owner_operational_signal_save_failed`

### Parámetros sugeridos
- `merchant_id`
- `signal_temporary_closed`
- `signal_has_delivery`
- `signal_accepts_whatsapp_orders`
- `signal_open_now_manual_override`
- `save_result`
- `source_screen`

### KPI North Star asociado
Confiabilidad operativa percibida por el vecino.

### KPIs secundarios
- % de comercios OWNER con señales configuradas
- frecuencia de actualización por merchant
- % de fichas públicas con datos operativos recientes
- correlación entre señales activas y conversiones de contacto

---

## 17. Riesgos

### 1. Señales viejas o abandonadas
**Impacto real:** pérdida de confianza del usuario final.

Mitigaciones MVP:
- Mostrar `updatedAt`
- Exponer recencia en UI OWNER
- Diseñar base para futura expiración

### 2. Override manual incorrecto
**Impacto real:** un comercio puede aparecer abierto sin estarlo.

Mitigaciones:
- Priorizar `temporaryClosed`
- Señal de frescura
- Reportes/moderación en fase posterior

### 3. Lógica duplicada entre frontend y backend
**Impacto real:** inconsistencia entre pantallas.

Mitigación:
- Fuente de verdad única en Cloud Functions para `isOpenNow`

### 4. Reglas de seguridad costosas o frágiles
**Impacto real:** costos y latencia innecesaria, más posibilidad de errores de permisos.

Mitigación:
- Mantener rules simples
- No repetir patrón de deuda `getUserRole()` con lecturas extra por request si puede evitarse

### 5. Exceso de writes por toggles
**Impacto real:** costo incremental y ruido operacional.

Mitigación:
- Guardado agrupado o debounce
- Evitar autosave hiperagresivo

---

## 18. Edge cases

- OWNER autenticado pero sin merchant asociado
- Documento de señales inexistente
- Horarios inexistentes
- Cierre temporal activo mientras horario indica abierto
- Override abierto activo fuera del horario normal
- Conflicto de dos sesiones del mismo OWNER
- Red lenta / offline
- Trigger fallido y desincronización temporal con `merchant_public`
- Comercio inactivo o invisible pero con señales activas
- Migración desde documento legacy si existiera

---

## 19. APIs / servicios involucrados

- Firebase Auth
- Firestore
- Cloud Functions TypeScript
- Analytics
- Remote Config (para rollout controlado si se desea feature flag)

No requiere Google Places ni integraciones externas.

---

## 20. DevOps

### CI/CD
- Validar rules
- Validar tests de Cloud Functions
- Validar tipos TypeScript
- Deploy por ambiente separado:
  - `tum2-dev-6283d`
  - `tum2-staging-45c83`
  - `tum2-prod-bc9b4`

### Entornos
- Probar en dev con emuladores
- Staging para QA funcional
- Prod con rollout gradual si se usa flag

### Feature flag
Recomendado:
- `owner_operational_signals_enabled`

### Versionado
- Mantener schema version si la estructura crece
- Ejemplo futuro: `signalsSchemaVersion`

### Rollback
- Desactivar feature flag
- Mantener trigger idempotente
- No borrar datos salvo migración explícita

### Observabilidad
- Logs estructurados de trigger
- Alertas por errores repetidos en proyección
- Eventual métrica de desincronización entre fuente y proyección

---

## 21. Escalabilidad / Performance

### Costo operativo
Cada actualización de señales dispara:
- 1 write a doc fuente
- 1 trigger
- lecturas auxiliares
- 1 write a proyección pública

Para MVP es aceptable por bajo volumen relativo del módulo OWNER.

### Cuellos posibles
- Trigger leyendo demasiadas fuentes
- Duplicación de recalculados
- Escrituras innecesarias por toggle individual

### Recomendaciones
- Consolidar recalculado de proyección
- Evitar N lecturas secuenciales
- No recalcular más de lo necesario
- Reusar helpers comunes con horarios

### Cache / CDN
No aplica directamente en el write path, sí en consumo web/app pública de `merchant_public`

---

## 22. Costos

### Componentes caros
- Writes repetidos por toggle
- Triggers frecuentes
- Rules con lecturas extra
- Logging excesivo no filtrado

### Optimización
- Guardado agrupado
- Rules eficientes
- Proyección compacta
- Evitar recalculados redundantes
- Logs con nivel adecuado

---

## 23. Riesgos / deuda técnica asociada

Esta tarjeta debe explicitar impacto sobre deuda existente:

1. **`buildSearchKeywords()` no implementado en proyección**
   - No mezclar esta tarjeta con search keywords salvo que el snippet derivado lo requiera.

2. **`ZoneSelectorSheet` hardcodeado**
   - No impacta directamente.

3. **`getUserRole()` con lectura extra en rules**
   - Evitar ampliar ese patrón en nuevas rules.

4. **`nightlyRefreshOpenStatuses` no escala**
   - Esta tarjeta no debe depender de ese proceso batch como fuente principal.
   - El estado operativo manual debe resolverse por trigger inmediato.

5. **`enforceAppCheck: false` en callables admin**
   - Si se implementa callable para signals, definir App Check correctamente en staging/prod.

6. **Comentarios JSON en indexes**
   - No agregar cambios que rompan deploy.

7. **Inconsistencia `zone/category` vs `zoneId/categoryId`**
   - Mantener naming canónico en cualquier cambio nuevo.

---

## 24. Checklist técnico

- [ ] Crear/confirmar schema de `merchant_operational_signals`
- [ ] Implementar provider Flutter de lectura/escritura
- [ ] Crear pantalla OWNER de señales operativas
- [ ] Validar conflicto entre `temporaryClosed` y `openNowManualOverride`
- [ ] Actualizar rules de Firestore
- [ ] Implementar trigger Cloud Functions
- [ ] Centralizar prioridad de señales sobre horarios
- [ ] Actualizar `merchant_public`
- [ ] Agregar analytics mínimos
- [ ] Agregar tests unit/integration
- [ ] Validar en emuladores
- [ ] Validar en staging
- [ ] Preparar flag de rollout si aplica

---

## 25. Checklist UX

- [ ] Copy claro y operativo
- [ ] Toggle de cierre temporal destacado
- [ ] Explicación breve del impacto
- [ ] Última actualización visible
- [ ] Feedback de guardado
- [ ] Manejo claro de error de red
- [ ] Prevención de combinaciones inválidas
- [ ] Accesibilidad de labels y contraste
- [ ] Sin jerga técnica visible al usuario

---

## 26. QA Plan

### Casos funcionales
- Guardado inicial
- Edición posterior
- Cierre temporal
- Delivery
- WhatsApp
- Forzar abierto
- Conflictos

### Casos de seguridad
- Usuario no owner
- Merchant ajeno
- Payload alterado
- Escritura de campos no permitidos

### Casos de resiliencia
- Offline
- Trigger demorado
- Reintento tras error
- Documento faltante

### Casos de regresión
- Búsqueda pública
- Ficha pública
- Vista Abierto ahora
- Otros consumidores de `merchant_public`

---

## 27. Definition of Done

La tarjeta se considera terminada cuando:

- El OWNER puede cargar señales operativas desde la app.
- Las señales quedan persistidas de forma segura.
- El backend recalcula correctamente la proyección pública.
- `temporaryClosed` domina la lógica de abierto/cerrado.
- La ficha pública refleja el cambio sin escritura directa desde cliente.
- Existe cobertura básica de testing.
- Se validó funcionamiento en dev y staging.
- No se rompe ninguna regla no negociable de arquitectura.

---

## 28. Plan de rollout

### Fase 1 — Dev
- Implementación funcional completa
- Validación en emuladores
- Test de reglas y trigger

### Fase 2 — Staging
- QA manual
- Validación UX
- Verificación de consistencia entre OWNER y ficha pública

### Fase 3 — Producción controlada
- Deploy a `tum2-prod-bc9b4`
- Activación gradual si se usa flag
- Monitoreo de errores y uso

---

## 29. Decisiones abiertas para futura expansión

- ¿Autosave instantáneo o botón “Guardar cambios”?
- ¿Se expondrá `updatedAt` también al vecino?
- ¿Se aplicará expiración automática a `temporaryClosed`?
- ¿Conviene migrar esta edición a callable en vez de write directo?
- ¿Se agregarán señales por rubro en una segunda etapa?
- ¿Se agregará campo explicativo opcional para cierre temporal?

Para MVP, ninguna de estas preguntas bloquea la implementación básica.

---

## 30. Nota de consistencia de roadmap

En el backlog maestro, la carga de horarios corresponde a **TuM2-0066** y la carga de señales operativas corresponde a **TuM2-0067**. Esta expansión documenta correctamente la tarjeta **TuM2-0067**. El backlog disponible confirma la existencia de ambas tareas separadas. fileciteturn1file0 fileciteturn1file1
