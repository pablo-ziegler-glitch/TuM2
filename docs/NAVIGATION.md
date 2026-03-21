# TuM2 — Arquitectura de navegación principal v1

Define la estructura de navegación de la app mobile: stacks, tab bars, modales y reglas de acceso.

---

## 1. Estructura general

La app usa un modelo de navegación en capas:

```
Root Navigator
├── AuthStack          (sin sesión activa)
└── AppNavigator       (con sesión activa)
    ├── CustomerTabs   (tab bar principal, rol customer / owner / admin)
    ├── OwnerStack     (modal stack para módulo owner)
    ├── AdminStack     (modal stack para módulo admin)
    └── SharedScreens  (fichas de detalle, accesibles desde cualquier contexto)
```

---

## 2. AuthStack

Navegación lineal, sin tab bar.

```
AuthStack (Stack Navigator)
├── Splash             → AUTH-01
├── Onboarding         → AUTH-02
├── Login              → AUTH-03
└── EmailVerification  → AUTH-04
```

**Regla:** si la sesión Firebase es válida al iniciar, el Root Navigator salta directamente a AppNavigator sin pasar por AuthStack.

---

## 3. AppNavigator — Tab bar principal (CustomerTabs)

Tab bar visible solo para usuarios con sesión. Tabs presentes en MVP:

| Tab | Ícono | Pantalla raíz | ID |
|-----|-------|---------------|----|
| Inicio | casa | Home | HOME-01 |
| Buscar | lupa | Buscar | SEARCH-01 |
| Perfil | persona | Mi perfil | PROFILE-01 |

Tab **Guardado** (Favoritos): se agrega en MVP+, no aparece hasta entonces.

### Regla de tab bar
- El tab bar se **oculta** cuando se navega hacia pantallas de detalle (DETAIL-01, DETAIL-02) o hacia OwnerStack/AdminStack.
- Los tabs son siempre accesibles desde las pantallas raíz de cada tab.

---

## 4. Stacks por tab

### 4.1 Tab Inicio — HomeStack

```
HomeStack (Stack Navigator)
├── Home                  → HOME-01
├── AbiertoAhora          → HOME-02
└── FarmaciasDeTurno      → HOME-03
```

### 4.2 Tab Buscar — SearchStack

```
SearchStack (Stack Navigator)
├── Buscar                → SEARCH-01
├── Resultados            → SEARCH-02
└── Mapa                  → SEARCH-03
```

**Nota:** SEARCH-03 (Mapa) también puede abrirse desde HOME-01 como atajo directo (push sobre HomeStack).

### 4.3 Tab Perfil — ProfileStack

```
ProfileStack (Stack Navigator)
├── MiPerfil              → PROFILE-01
├── Configuracion         → PROFILE-02
└── PropuestasYVotos      → PROFILE-03  [MVP+]
```

El acceso a **OwnerStack** se dispara desde PROFILE-01 si el usuario tiene rol `owner`. Se presenta como modal stack sobre toda la app.

---

## 5. OwnerStack (Modal Stack)

Se presenta como pantalla completa modal sobre AppNavigator. El owner puede volver al CustomerTabs en cualquier momento (botón "Salir del panel" o gesto de cierre).

```
OwnerStack (Modal / Full-screen Stack)
├── PanelComercio         → OWNER-01
├── EditarPerfil          → OWNER-02
├── Productos             → OWNER-03
│   ├── AltaProducto      → OWNER-04
│   └── EditarProducto    → OWNER-05
├── HorariosYSenales      → OWNER-06
│   ├── EditarHorarios    → OWNER-07
│   └── SenalOperativa    → OWNER-08  (modal sheet)
└── TurnosFarmacia        → OWNER-09
    ├── CalendarioTurnos  → OWNER-10
    └── CargarTurno       → OWNER-11
```

**OWNER-08 — SenalOperativa** se presenta como **bottom sheet modal** sobre OWNER-06, no como pantalla full.

---

## 6. AdminStack (Modal Stack)

Solo accesible si el JWT del usuario tiene `role: admin`. Se bloquea a nivel de navegación si el rol no aplica.

```
AdminStack (Modal / Full-screen Stack)
├── PanelAdmin            → ADMIN-01
├── ListadoComerciosMod   → ADMIN-02
├── DetalleComercioMod    → ADMIN-03
└── SenalesReportadas     → ADMIN-04
```

---

## 7. SharedScreens (pantallas de detalle compartidas)

Accesibles desde múltiples stacks. Se pushean sobre el stack activo en el momento.

```
SharedScreens
├── FichaComercio         → DETAIL-01
│   └── FichaProducto     → DETAIL-02  (bottom sheet modal)
└── OnboardingOwner       → DETAIL-03
    ├── TipoNombreComercio    → ONBOARDING-OWNER-01
    ├── DireccionZona         → ONBOARDING-OWNER-02
    ├── HorariosIniciales     → ONBOARDING-OWNER-03
    └── ConfirmacionActivacion → ONBOARDING-OWNER-04
```

**FichaProducto (DETAIL-02):** se presenta siempre como **bottom sheet** sobre FichaComercio, no como pantalla nueva en el stack.

---

## 8. Modales y bottom sheets

| Pantalla | Tipo de presentación | Contexto |
|----------|---------------------|----------|
| AUTH-04  | Pantalla full (stack push) | Verificación email |
| OWNER-08 | Bottom sheet modal | Señal operativa rápida |
| DETAIL-02 | Bottom sheet modal | Detalle de producto |
| Cambio de zona | Action sheet / modal pequeño | Desde barra zona en HOME-01 |
| Confirmar cierre de señal | Alert nativo | Desde OWNER-01 / OWNER-08 |

---

## 9. Manejo de roles en navegación

### Detección de rol al iniciar sesión
1. Firebase Auth provee el `idToken`.
2. El claim `role` (custom claim) determina el flujo post-login:
   - `customer` → AppNavigator, CustomerTabs, tab Inicio.
   - `owner` → AppNavigator, CustomerTabs, tab Inicio. PROFILE-01 muestra botón "Ir a mi comercio".
   - Si `owner` y NO tiene comercio registrado → redirige a DETAIL-03 (onboarding de comercio).
   - `admin` → AppNavigator, CustomerTabs. PROFILE-01 muestra acceso a AdminStack.

### Guards de navegación
- Rutas del OwnerStack: verifican `role == owner || role == admin` en el navigator.
- Rutas del AdminStack: verifican `role == admin`.
- Si un deep link apunta a una ruta protegida sin rol, redirige a AUTH-03.

---

## 10. Gestión del estado de navegación

### Persistencia de estado
- El estado de navegación **no se persiste** entre sesiones (siempre arranca en HOME-01 o AUTH-01 según sesión).
- Excepción: deep links pueden restaurar un stack específico.

### Manejo de deep links
- Al recibir un deep link con sesión activa: navegar directamente a la pantalla destino (ver tabla en SCREENS-MAP.md § 4).
- Al recibir un deep link sin sesión: guardar la ruta pendiente, completar auth, luego navegar.

### Back navigation
- Android: botón físico / gesto sigue el stack nativo.
- iOS: gesto de swipe-back en stacks, dismiss en modales.
- OwnerStack y AdminStack: botón "Cerrar" en header vuelve a CustomerTabs (dismiss modal).

---

## 11. Tecnología sugerida (Flutter)

| Componente | Librería recomendada |
|------------|---------------------|
| Navegación principal | `go_router` |
| Tab bar | `NavigationBar` (Material 3, built-in) |
| Stack navigator | `go_router` routes / `Navigator.push` |
| Modal / bottom sheet | `showModalBottomSheet` (built-in) |
| Deep links | `go_router` path-based deep links |
| Auth state | `firebase_auth` + Riverpod `StreamProvider` |

---

## 12. Diagrama de flujo de alto nivel

```
┌─────────────────────────────────────────────────────────┐
│                     App Launch                          │
└────────────────────┬────────────────────────────────────┘
                     │
           ┌─────────▼─────────┐
           │   AUTH-01 Splash  │
           └─────────┬─────────┘
                     │
         ┌───────────┴───────────┐
         │                       │
    [Sin sesión]           [Sesión válida]
         │                       │
         ▼                       ▼
   AUTH-02 → AUTH-03       HOME-01 (tab Inicio)
         │
         ▼
   HOME-01 (tab Inicio)
         │
   ┌─────┴──────┬──────────────────┐
   │            │                  │
tab Inicio  tab Buscar         tab Perfil
   │            │                  │
HOME-01     SEARCH-01         PROFILE-01
   │                               │
   │                    ┌──────────┴──────────┐
   │                    │                     │
   │              [rol: owner]          [rol: admin]
   │                    │                     │
   │               OwnerStack           AdminStack
   │
SharedScreens (DETAIL-01, DETAIL-02, DETAIL-03)
accesibles desde cualquier punto del árbol
```

---

*Documento generado para TuM2-0028. Ver SCREENS-MAP.md para el inventario completo de pantallas.*
