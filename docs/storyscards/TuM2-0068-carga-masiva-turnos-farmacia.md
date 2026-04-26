# TuM2-0068 — Carga de turnos de farmacia (OWNER-09/10/11)

Estado: DONE
Última actualización: 2026-04-13  
PR: #84

## Alcance implementado

Se implementó la carga de turnos para OWNER en farmacia con foco en costo y seguridad:

- calendario mensual con selección de fecha y multiselección,
- alta, edición y eliminación de turnos,
- publicación batch mensual desde cliente,
- persistencia en `pharmacy_duties`,
- actualización de proyección pública vía backend.

## Arquitectura aplicada

Flujo:

`Flutter OWNER -> Callable upsertPharmacyDutiesBatch -> pharmacy_duties -> trigger/proyección -> merchant_public`

Decisiones clave:

- patrón dual-collection respetado (`merchants` privado, `merchant_public` solo backend),
- sin escritura cliente en `merchant_public`,
- validación crítica server-side,
- sin listeners realtime innecesarios para el calendario mensual.

## Optimización de costos (aplicada)

- lectura mensual acotada (query por mes/rango) en vez de query por día,
- upsert batch en una transacción por operación de publicación,
- detección de filas sin cambios para evitar writes redundantes (`unchangedRows`),
- validaciones de conflicto en backend usando query acotada por `merchantId` + fechas involucradas.

## Seguridad y validaciones

En backend:

- Auth obligatoria + claims de rol,
- validación de ownership (`merchantId` del usuario),
- validación rubro farmacia,
- validación formato de fecha/hora y máximos de lote (hasta 31 filas),
- validación de fechas duplicadas y solapamientos.

En frontend:

- `zoneId` no editable por usuario,
- mensajes de conflicto y recuperación de error,
- confirmación explícita para eliminación.

## Pantallas y rutas

- `OWNER-09`: `/owner/pharmacy-duties`
- `OWNER-11 (alta)`: `/owner/pharmacy-duties/new`
- `OWNER-11 (edición)`: `/owner/pharmacy-duties/:dutyId/edit`

## Fuera de alcance (sigue diferido)

La **carga masiva por archivo** (`.xlsx`, parser/Storage/reportes por fila) no forma parte de TuM2-0068 MVP y se mantiene para tarjeta separada (ej: TuM2-0113).
