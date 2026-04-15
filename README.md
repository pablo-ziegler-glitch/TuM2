# TuM2

> "Lo que necesitás, en tu zona."

Directorio de comercios de barrio en tiempo real. Vecinos encuentran qué está abierto, qué farmacia está de turno y qué comercios hay en su zona. Dueños controlan cómo aparecen.

---

## Estructura del proyecto

```
TuM2/
├── docs/                    — Documentación técnica y de producto
│   ├── ARCHITECTURE.md      — Arquitectura del sistema, decisiones técnicas
│   ├── VISION.md            — Visión del producto y propuesta de valor
│   ├── PRD-MVP.md           — Product Requirements Document del MVP
│   ├── SCREENS-MAP.md       — Mapa completo de pantallas y flujos UX
│   ├── NAVIGATION.md        — Arquitectura de navegación React Navigation
│   └── QUERY-ARCHITECTURE.md — Patrones de queries Firestore por pantalla
├── schema/                  — Tipos TypeScript compartidos (modelo de datos)
│   └── types/               — Tipos canónicos de colecciones y contratos operativos
├── functions/               — Firebase Cloud Functions (Node 20 + TypeScript)
│   └── src/
│       ├── triggers/        — Triggers de Firestore (sync, derivados)
│       ├── jobs/            — Jobs programados y callables admin
│       ├── coverage/        — Métricas de cobertura por zona
│       ├── admin/           — Callables de administración
│       └── lib/             — Utilidades internas (projection, scheduling, etc.)
├── mobile/                  — App mobile Flutter (pendiente flutter create)
├── firestore.rules          — Reglas de seguridad Firestore
├── firestore.indexes.json   — Índices compuestos Firestore
├── firebase.json            — Configuración Firebase y emuladores
└── .firebaserc              — Proyectos Firebase por ambiente (dev/staging/prod)
```

---

## Ambientes

| Ambiente | Firebase Project | Uso |
|----------|-----------------|-----|
| dev | tum2-dev-6283d | Desarrollo local con emuladores |
| staging | tum2-staging-45c83 | QA y validación |
| prod | tum2-prod-bc9b4 | Producción |

```bash
# Cambiar de ambiente
firebase use dev
firebase use staging
firebase use prod
```

---

## Desarrollo local

### Requisitos
- Node.js 20+
- Firebase CLI (`npm install -g firebase-tools`)
- Java (para emuladores de Firestore)

### Iniciar emuladores
```bash
firebase use dev
firebase emulators:start
# UI disponible en http://localhost:4000
```

### Cloud Functions
```bash
cd functions
npm install
npm run build       # Compilar TypeScript
npm run serve       # Build + emuladores
npm run deploy      # Deploy a Firebase (requiere firebase use <alias>)
```

### App Mobile
```bash
cd mobile
flutter create . --org com.floki.tum2 --project-name tum2 --platforms android,ios
flutter pub get
flutter run
```

### Portal Admin Web (TuM2-0122)
```bash
cd web
flutter pub get
flutter run -d chrome \
  --dart-define=FIREBASE_API_KEY=... \
  --dart-define=FIREBASE_APP_ID=... \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
  --dart-define=FIREBASE_PROJECT_ID=...
```

Opcional para emuladores locales:
```bash
--dart-define=USE_FIREBASE_EMULATORS=true
```

---

## Documentación

| Documento | Descripción |
|-----------|-------------|
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | Stack, modelo de datos, Cloud Functions, seguridad |
| [VISION.md](docs/VISION.md) | Visión del producto, propuesta de valor, principios |
| [PRD-MVP.md](docs/PRD-MVP.md) | Alcance del MVP, features, criterios de aceptación |
| [SCREENS-MAP.md](docs/SCREENS-MAP.md) | Pantallas completas, flujos UX, deep links |
| [NAVIGATION.md](docs/NAVIGATION.md) | Arquitectura de navegación Flutter (go_router) |
| [QUERY-ARCHITECTURE.md](docs/QUERY-ARCHITECTURE.md) | Patrones de queries Firestore por pantalla |
| [TuM2-0014-MICROCOPY.md](docs/TuM2-0014-MICROCOPY.md) | Guía de tono y microcopy para el MVP Fase 3 |
| [PROD-LAUNCH-CRITICAL.md](docs/ops/PROD-LAUNCH-CRITICAL.md) | Runbook crítico para lanzamiento a producción |
| [ci-cd.md](docs/devops/ci-cd.md) | Operación de workflows GitHub Actions, deploy por ambiente, seguridad OIDC y aprobaciones manuales |
| [TuM2-0123-limites-capacidad-catalogo.md](docs/storyscards/TuM2-0123-limites-capacidad-catalogo.md) | Historia TuM2-0123: enforcement de capacidad de catálogo (CF + OWNER + Admin Web) |
| [tu_m_2_0124_mitigacion_operativa_de_guardias_de_farmacia.md](docs/storyscards/tu_m_2_0124_mitigacion_operativa_de_guardias_de_farmacia.md) | Historia TuM2-0124: mitigación de guardias y reasignación operativa |
| [schema/README.md](schema/README.md) | Modelo de datos, colecciones, índices |
| [CLAUDE.md](CLAUDE.md) | Backlog maestro y estado del proyecto |

---

## Stack

- **Mobile:** Flutter
- **Navegación:** go_router
- **Backend:** Firebase (Firestore, Auth, Functions, Storage)
- **Web:** Flutter Web
- **Tipos compartidos:** TypeScript en `/schema/types/` (backend/functions)
