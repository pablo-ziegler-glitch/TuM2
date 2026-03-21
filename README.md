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
│   └── types/               — 14 archivos de tipos para todas las colecciones
├── functions/               — Firebase Cloud Functions (Node 20 + TypeScript)
│   └── src/
│       ├── triggers/        — Triggers de Firestore (sync, derivados)
│       ├── jobs/            — Jobs programados y callables admin
│       ├── coverage/        — Métricas de cobertura por zona
│       ├── admin/           — Callables de administración
│       └── lib/             — Utilidades internas (projection, scheduling, etc.)
├── mobile/                  — App mobile React Native / Expo (en desarrollo)
│   └── src/
│       ├── navigation/      — Estructura de navegación (Root, Auth, App, Tabs)
│       ├── screens/         — Pantallas organizadas por segmento
│       ├── components/      — Componentes reutilizables
│       ├── hooks/           — Custom hooks (useAuth, etc.)
│       ├── services/        — Integración Firebase
│       └── types/           — Types específicos de la app
├── firestore.rules          — Reglas de seguridad Firestore
├── firestore.indexes.json   — Índices compuestos Firestore
├── firebase.json            — Configuración Firebase y emuladores
└── .firebaserc              — Proyectos Firebase por ambiente (dev/staging/prod)
```

---

## Ambientes

| Ambiente | Firebase Project | Uso |
|----------|-----------------|-----|
| dev | tum2-dev | Desarrollo local con emuladores |
| staging | tum2-staging | QA y validación |
| prod | tum2-prod | Producción |

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
npm install
npx expo start      # Iniciar Expo dev server
```

---

## Documentación

| Documento | Descripción |
|-----------|-------------|
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | Stack, modelo de datos, Cloud Functions, seguridad |
| [VISION.md](docs/VISION.md) | Visión del producto, propuesta de valor, principios |
| [PRD-MVP.md](docs/PRD-MVP.md) | Alcance del MVP, features, criterios de aceptación |
| [SCREENS-MAP.md](docs/SCREENS-MAP.md) | Pantallas completas, flujos UX, deep links |
| [NAVIGATION.md](docs/NAVIGATION.md) | Arquitectura de navegación React Navigation |
| [QUERY-ARCHITECTURE.md](docs/QUERY-ARCHITECTURE.md) | Patrones de queries Firestore por pantalla |
| [schema/README.md](schema/README.md) | Modelo de datos, colecciones, índices |
| [CLAUDE.md](CLAUDE.md) | Backlog maestro y estado del proyecto |

---

## Stack

- **Mobile:** React Native (Expo) + TypeScript
- **Navegación:** React Navigation v6
- **Backend:** Firebase (Firestore, Auth, Functions, Storage)
- **Web:** Next.js (planificado)
- **Tipos:** TypeScript compartido en `/schema/types/`
