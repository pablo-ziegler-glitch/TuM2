# TuM2 — Arquitectura de Queries v1

Define qué consulta cada pantalla, desde qué colección, con qué filtros y con qué fallback.

---

## 1. Home

### Objetivo UX
Mostrar utilidad en menos de 5 segundos.

### Fuente principal
`merchant_public`

### Query base por zona
```
zoneId == currentZoneId
visibilityStatus in [visible, review_pending]
limit: 10–20
```

### Bloques

#### Quick Actions
No requieren query propia; disparan subsecciones o navegación:
- Abierto ahora
- Farmacias de turno
- Kioscos cerca
- Gomerías cerca

#### Resultados inmediatos
Query principal a `merchant_public` ordenada en cliente por:
1. `sortBoost desc`
2. `hasPharmacyDutyToday desc`
3. `isOpenNow desc`
4. distancia calculada en cliente o backend posterior

### Fallback
Si la zona tiene poca densidad:
- Mostrar resultados `review_pending` con badge
- CTA: sugerir/cargar comercio

---

## 2. Buscar

### Fuente principal
`merchant_public`

### Modo A — Categoría rápida
```
zoneId == currentZoneId
visibilityStatus in [visible, review_pending]
categoryId == selectedCategory
```

### Modo B — Texto libre
Firestore no resuelve full-text serio. Para MVP:
- Precargar candidatos por zona
- Filtrar en cliente usando el campo `searchKeywords`

### Orden recomendado
1. `verified` / `validated` / `claimed`
2. Abierto ahora
3. Cercanía
4. `referential`
5. `community_submitted`

### Fallback de no resultados
No mostrar "sin resultados" seco. Mostrar:
- Resultados cercanos de otra categoría útil
- Comercios `review_pending` con badge
- CTA de sugerencia

---

## 3. Ficha de comercio

### Fuentes
- `merchant_public/{merchantId}`
- `merchant_products` filtrado por `merchantId` y `visibilityStatus == visible`
- `merchant_schedules/{merchantId}` (opcional, para detalle extra)

### Orden de carga
1. `merchant_public/{merchantId}`
2. `merchant_products`
3. `merchant_schedules` si se necesita detalle adicional

### Reglas UX
- Si `verificationStatus == community_submitted` → mostrar badge `pending_validation`
- Si el horario no es confiable → mostrar aviso "información referencial"

---

## 4. Abierto ahora

### Fuente principal
`merchant_public`

### Query
```
zoneId == currentZoneId
visibilityStatus in [visible, review_pending]
isOpenNow == true
```

### Orden
1. Cercanía
2. `sortBoost`
3. Categoría relevante

### Fallback
Si no hay comercios abiertos ahora:
- Mostrar próximos a abrir
- Usar `todayScheduleLabel` para orientar al usuario

---

## 5. Farmacias de turno

### Fuentes
- `pharmacy_duties`
- `merchant_public`

### Paso 1 — Query a `pharmacy_duties`
```
zoneId == currentZoneId
date == selectedDate
status == published
```

### Paso 2 — Resolver detalles del comercio
Para cada `merchantId` obtenido en el paso 1, resolver desde `merchant_public`.

### Optimización recomendada (futuro)
Duplicar un snapshot mínimo del comercio dentro de `pharmacy_duties`:
- `merchantName`
- `address`
- `lat` / `lng`
- `verificationStatus`

---

## 6. Mi comercio (owner)

### Fuentes
- `merchants` filtrado por `ownerUserId == currentUserId`
- `merchant_schedules/{merchantId}`
- `merchant_operational_signals/{merchantId}`
- `merchant_products` filtrado por `merchantId`
- `pharmacy_duties` filtrado por `merchantId` (solo si el comercio es farmacia)

### Dashboard owner — datos a mostrar
- Estado del comercio
- Visibilidad actual
- Estado de verificación
- Cantidad de productos cargados
- Horario: cargado / no cargado
- Señales operativas activas

---

## 7. Moderación mínima (admin)

### Fuentes
| Colección | Filtro |
|-----------|--------|
| `merchants` | `visibilityStatus == review_pending` |
| `reports` | `status == open` |
| `merchant_claims` | `status == pending` |
| `external_places` | por `importStatus` |

---

## 8. Reglas de composición de resultados

### Niveles de confianza visual

| `verificationStatus` | Tratamiento UI |
|----------------------|----------------|
| `verified` / `validated` / `claimed` | Normal, sin badge |
| `referential` | Badge: referencial |
| `community_submitted` | Badge: pendiente de validación |

### Publicación híbrida

| `visibilityStatus` | Comportamiento |
|--------------------|----------------|
| `visible` | Ranking normal según nivel de confianza |
| `review_pending` | Mostrar solo si aporta densidad útil o en zonas con pocos resultados |
| `suppressed` | Nunca visible públicamente |

---

## 9. Triggers necesarios

### Trigger A — Sincronización de `merchant_public`
**Cuando cambian:**
- `merchants/{merchantId}`
- `merchant_schedules/{merchantId}`
- `merchant_operational_signals/{merchantId}`
- `pharmacy_duties/*`

**Acción:** Actualizar `merchant_public/{merchantId}` con los campos derivados correspondientes.

### Trigger B — Umbral de reportes
Si `reportCount` supera el threshold configurado:
- Pasar `visibilityStatus` a `suppressed` o `review_pending`

### Trigger C — Claim aprobado
Si `merchant_claims.status == approved`:
- Actualizar `ownerUserId` en `merchants`
- Setear `verificationStatus = claimed`
- Setear `sourceType = owner_created`
- Subir `sortBoost`

---

## 10. Orden recomendado de implementación

| Prioridad | Pantalla |
|-----------|----------|
| 1 | Home |
| 2 | Buscar |
| 3 | Ficha de comercio |
| 4 | Abierto ahora |
| 5 | Farmacias de turno |
| 6 | Mi comercio (owner) |
| 7 | Admin mínimo |
