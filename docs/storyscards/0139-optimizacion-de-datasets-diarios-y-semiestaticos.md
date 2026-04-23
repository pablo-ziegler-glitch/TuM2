# TuM2-0139 — Optimización de datasets diarios y semi-estáticos (`pharmacy_duties`, abierto ahora)

## 1. Estado y metadata
- **Estado:** TODO
- **Prioridad:** P0
- **Dependencia madre:** TuM2-0135
- **Dependencias funcionales:** TuM2-0061, TuM2-0060, TuM2-0124

## 2. Objetivo
Aplicar una política de consumo barata y predecible sobre datasets que cambian dentro del día, pero que no justifican listeners permanentes para todos los usuarios.

## 3. Contexto
Hay dos dominios claros:
- **Farmacias de turno**: dataset diario por zona, muy valioso, pero no necesariamente realtime segundo a segundo.
- **Abierto ahora**: dataset operativo útil que cambia más, pero donde un TTL corto sigue siendo mejor que listeners masivos en consumo público.

## 4. Problema
Sin política clara:
- se tiende a reconsultar el mismo día/zona muchas veces,
- lista y detalle duplican lecturas,
- se sobredimensiona la necesidad de realtime,
- y el costo se dispara en pantallas de alto uso.

## 5. Alcance IN
- cache por `zoneId + date` para `pharmacy_duties`,
- cache por `zoneId + category/openNow` para abiertos ahora,
- TTL corto configurable,
- refresh manual visible,
- reuse entre listados y detalle.

## 6. Decisiones canónicas
### `pharmacy_duties`
- consumo por `zoneId + date`,
- **TTL 10 min**,
- refresh manual,
- sin listener continuo.

### `abierto ahora`
- consumo por zona y filtros,
- **TTL 3 min**,
- refresh manual,
- sin listener masivo por defecto.

### Snapshot
Solo se evaluará a futuro para docs muy acotados si hay necesidad real de precisión operativa superior.

## 7. Arquitectura propuesta
```text
Home / Duties screen
    |
    v
Repository
    |
    +--> key duties:<zoneId>:<date>
    +--> key open_now:<zoneId>:<filters>
    |
    +--> Firestore get()
    |
    v
cache + revalidate
```

## 8. Frontend
### `pharmacy_duties`
- una lectura por zona+día dentro de TTL,
- detalle usa dataset ya cargado cuando sea posible,
- Haversine y ranking local,
- no repetir la misma query por navegar detalle/listado.

### `abierto ahora`
- misma idea que search: dataset reutilizable breve,
- filtros locales si el payload lo permite,
- indicador “actualizado hace X”.

### UX
- botón “Actualizar”
- timestamp
- fallback a últimos datos recientes si hay error

## 9. Backend
### `pharmacy_duties`
- índice compuesto ya canónico: `zoneId + date + status`
- query acotada por día y zona
- sin scan abierto del histórico

### `merchant_public`
- debe proveer campos suficientes para “abierto ahora”
- sin obligar al cliente a leer privados
- recomputes operativos deben minimizar writes redundantes

## 10. Seguridad
- datos públicos solamente,
- no exponer lógicas internas sensibles,
- mantener consistencia con señales y proyecciones públicas.

## 11. UX / Producto
### Explicación simple del TTL
- farmacia de turno: si viste hace 5 minutos, no hace falta pagar otra lectura idéntica.
- abierto ahora: aceptamos pocos minutos de antigüedad porque el ahorro es alto, pero damos refresh manual.

## 12. Datos impactados
- `pharmacy_duties`
- `merchant_public`
- posibles manifests diarios
- HOME-02
- HOME-03
- detail screens relacionadas

## 13. APIs y servicios
- Firestore
- repositorios Flutter
- Remote Config para TTL
- Analytics

## 14. Analytics
Eventos:
- `duties_loaded`
- `duties_cache_hit`
- `duties_manual_refresh`
- `open_now_loaded`
- `open_now_cache_hit`
- `open_now_manual_refresh`

## 15. Testing
- keying correcto,
- TTL,
- reuse en detalle,
- refresh manual,
- queries correctas,
- reuse entre pantallas,
- fallback a cache,
- E2E de abrir varias veces misma zona/día.

## 16. DevOps
- TTL configurable,
- alarmas si duties/open-now superan presupuesto de lecturas por 1.000 sesiones,
- trazas por pantalla.

## 17. Riesgos
- datos abiertos ahora demasiado viejos,
- cambios operativos rápidos no capturados al instante,
- equipo sobrerreaccionando y volviendo a listeners masivos.

## 18. Definition of Done
- duties y abierto ahora usan `get()` + cache + refresh controlado,
- no hay listeners amplios,
- detalle reutiliza dataset cuando aplique,
- TTL configurables documentados.

## 19. Rollout
1. `pharmacy_duties`
2. `abierto ahora`
3. ajuste fino por métricas

## 20. Checklist final
- [ ] key por zona/fecha
- [ ] TTL 10 min duties
- [ ] TTL 3 min abierto ahora
- [ ] refresh manual visible
- [ ] sin listeners masivos
- [ ] métricas de costo por feature
