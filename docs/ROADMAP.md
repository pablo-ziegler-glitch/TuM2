# TuM2 — Roadmap
### Tarjeta: TuM2-0008

Roadmap de ejecución del producto organizado en 4 fases. Cada fase tiene precondiciones claras — no avanzar a la siguiente sin cerrar los bloqueantes de la anterior.

---

## Fases de ejecución

```
Fase A — Fundacional          Fase B — Núcleo MVP
────────────────────          ───────────────────
  Stack + modelos                Shell + auth
  Arquitectura pantallas          Owner completo
  Firebase base                   Customer core
  Branding base                   Web pública útil
  Bootstrap de datos              Analytics + QA
          │                              │
          ▼                              ▼
Fase C — Lanzamiento          Fase D — Expansión MVP+
────────────────────          ───────────────────────
  Piloto geográfico              Features adicionales
  Legal mínimo                    Panel admin
  Material para owners            Mapa, favoritos
  Beta stores                     Propuestas y votos
  CI/CD mínimo                    Analytics avanzado
```

---

## Fase A — Fundacional

**Objetivo:** sentar todas las bases para que el equipo pueda desarrollar sin fricciones.

**Bloqueante para Fase B:** todos los ítems P0 de esta fase deben estar completos.

| ID | Tarjeta | Prioridad | Estado |
|----|---------|-----------|--------|
| 0001 | Definir propuesta de valor final | P0 | ✅ |
| 0003 | Cerrar alcance real del MVP | P0 | — |
| 0004 | Cerrar segmentos principales | P0 | — |
| 0005 | Mantener actualizado VISION.md | P0 | ✅ |
| 0006 | Mantener actualizado PRD-MVP.md | P0 | ✅ |
| 0007 | Mantener actualizado ARCHITECTURE.md | P0 | ✅ |
| 0015 | Relevar rubros prioritarios | P0 | — |
| 0016 | Relevar caso farmacias de turno | P0 | — |
| 0017 | Relevar señales operativas por rubro | P0 | — |
| 0019 | Diseñar modelo de usuarios | P0 | ✅ |
| 0020 | Diseñar modelo de comercios | P0 | ✅ |
| 0021 | Diseñar modelo de productos | P0 | ✅ |
| 0022 | Diseñar modelo de horarios | P0 | ✅ |
| 0023 | Diseñar modelo de señales operativas | P0 | ✅ |
| 0024 | Diseñar modelo de turnos/guardias | P0 | ✅ |
| 0027 | Definir mapa completo de pantallas | P0 | ✅ |
| 0028 | Diseñar navegación principal | P0 | ✅ |
| 0042 | Crear proyecto base Firebase | P0 | ✅ |
| 0043 | Configurar ambientes dev/staging/prod | P0 | ✅ |
| 0044 | Configurar Authentication | P0 | ✅ |
| 0045 | Configurar Firestore base | P0 | ✅ |
| 0046 | Definir Firestore Rules iniciales | P0 | ✅ |
| 0048 | Implementar Cloud Functions base | P1 | ✅ |
| 0049 | Implementar campos derivados operativos | P0 | ✅ |
| 0050 | Implementar agregados públicos | P1 | ✅ |
| 0052 | Crear proyecto mobile base | P0 | — |
| 0070 | Crear web pública base | P1 | — |
| 0010 | Definir identidad visual base | P0 | — |
| 0011 | Diseñar logo principal | P0 | — |
| 0012 | Diseñar app icon | P0 | — |
| 0121 | Estrategia de cobertura inicial y bootstrap | P0 | ✅ |

---

## Fase B — Núcleo MVP

**Objetivo:** construir el producto funcional completo para el piloto.

**Bloqueante para Fase C:** los ítems P0 de esta fase deben estar completos y testeados.

| ID | Tarjeta | Prioridad |
|----|---------|-----------|
| 0030 | Diseñar onboarding OWNER | P0 |
| 0031 | Diseñar pantalla Buscar | P0 |
| 0033 | Diseñar ficha pública de comercio | P0 |
| 0035 | Diseñar vista Farmacias de turno | P0 |
| 0036 | Diseñar vista Abierto ahora | P0 |
| 0037 | Diseñar panel Mi comercio | P0 |
| 0038 | Diseñar flujo carga de productos | P0 |
| 0039 | Diseñar flujo carga de horarios y señales | P0 |
| 0040 | Diseñar flujo carga de turnos de farmacia | P0 |
| 0053 | Implementar shell de app Flutter | P0 |
| 0054 | Implementar login / registro | P0 |
| 0056 | Implementar búsqueda de comercios | P0 |
| 0058 | Implementar ficha de comercio | P0 |
| 0060 | Implementar vista Abierto ahora | P0 |
| 0061 | Implementar vista Farmacias de turno | P0 |
| 0064 | Implementar módulo OWNER | P0 |
| 0065 | Implementar alta/edición de productos | P0 |
| 0066 | Implementar carga de horarios | P0 |
| 0067 | Implementar carga de señales operativas | P0 |
| 0068 | Implementar carga de turnos farmacia | P0 |
| 0071 | Implementar landing principal web | P1 |
| 0072 | Implementar ficha pública de comercio web | P0 |
| 0074 | Implementar landing Farmacias de turno web | P0 |
| 0075 | Implementar landing Abierto ahora web | P0 |
| 0082 | Definir eventos analytics | P0 |
| 0083 | Implementar tracking base | P0 |
| 0087 | Medir uso de señales operativas | P0 |
| 0088 | Configurar App Check | P1 |
| 0089 | Configurar Crashlytics | P1 |
| 0090 | Crear checklist QA MVP | P0 |
| 0091 | Testear permisos por rol | P0 |
| 0092 | Testear edge cases operativos | P0 |

---

## Fase C — Lanzamiento controlado

**Objetivo:** piloto geográfico con comercios reales, legal mínimo cubierto, observabilidad activa.

| ID | Tarjeta | Prioridad |
|----|---------|-----------|
| 0094 | Definir piloto geográfico | P0 |
| 0095 | Definir rubros iniciales de salida | P0 |
| 0097 | Armar material para captar primeras farmacias | P0 |
| 0096 | Armar material de onboarding para comercios | P1 |
| 0100 | Redactar política de privacidad | P0 |
| 0101 | Redactar términos y condiciones | P0 |
| 0102 | Definir disclaimer operativo y farmacias | P0 |
| 0104 | Definir política básica de moderación | P0 |
| 0093 | Configurar alertas técnicas mínimas | P1 |
| 0098 | Preparar publicación beta | P1 |
| 0099 | Preparar metadata de stores y canales | P1 |
| 0051 | Configurar CI/CD técnico mínimo | P1 |

---

## Fase D — Expansión MVP+

**Objetivo:** features adicionales basados en aprendizajes del piloto.

| ID | Tarjeta | Prioridad |
|----|---------|-----------|
| 0029 | Diseñar onboarding CUSTOMER | P1 |
| 0032 | Diseñar pantalla Mapa | P1 |
| 0034 | Diseñar ficha de producto | P1 |
| 0041 | Diseñar board de propuestas y votos | P1 |
| 0055 | Implementar home CUSTOMER | P1 |
| 0057 | Implementar mapa | P1 |
| 0059 | Implementar ficha de producto | P2 |
| 0062 | Implementar favoritos | P2 |
| 0063 | Implementar seguir comercio | P2 |
| 0069 | Implementar módulo de propuestas y votos | P1 |
| 0073 | Implementar ficha pública de producto web | P2 |
| 0076 | Implementar links compartibles | P1 |
| 0077 | Diseñar panel admin mínimo | P1 |
| 0078 | Implementar listado de comercios (admin) | P2 |
| 0079 | Implementar listado de propuestas (admin) | P2 |
| 0080 | Implementar moderación de contenido | P1 |
| 0081 | Implementar revisión de señales reportadas | P1 |
| 0084 | Crear dashboard MVP analytics | P1 |
| 0085 | Medir activación OWNER | P1 |
| 0086 | Medir activación CUSTOMER | P1 |
| 0103 | Definir consentimiento de ubicación | P1 |
| 0105 | Diseñar sistema de propuestas usable | P1 |
| 0106 | Implementar links compartibles de propuestas | P2 |
| 0107 | Definir loop de invitación | P2 |

---

## Post-MVP (no en scope actual)

| ID | Tarjeta |
|----|---------|
| 0026 | Modelo de badges y branding snippets |
| 0108 | Diseñar badges comunitarios |
| 0109–0111 | Hipótesis de monetización |
| 0112–0120 | Escalamiento, carga masiva, verificación avanzada, rankings |

---

## Reglas de ejecución del roadmap

1. Máximo 1–3 tareas grandes activas simultáneamente.
2. Máximo 3–5 tareas chicas activas simultáneamente.
3. No avanzar de fase sin cerrar los P0 de la fase actual.
4. Los quick wins (ver CLAUDE.md) pueden ejecutarse en cualquier fase si no bloquean nada.
5. Este documento se actualiza cuando una tarjeta cambia de estado.

---

*Documento mantenido bajo TuM2-0008. Actualizar cuando cambie el estado de tarjetas o el orden de ejecución.*
