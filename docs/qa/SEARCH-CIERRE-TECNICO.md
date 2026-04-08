# TuM2 SEARCH - Cierre Tecnico (TuM2-0056)

Fecha: 2026-04-03

Nota de alcance QA: las capturas pendientes de SEARCH son evidencia visual de ejecucion real (emulador/dispositivo con datos funcionales). No son mockups de diseno.

## Checklist P0

- [x] Cloud Functions: `buildSearchKeywords` implementado y cubierto con tests.
- [x] Cloud Functions: `computeMerchantPublicProjection()` valida `searchKeywords`.
- [x] Backfill `merchant_public`: callable admin-only con resumen operativo.
- [x] Seguridad: rechazo no-admin (`permission-denied`) cubierto por test.
- [x] Seguridad: `merchant_public` sigue read-only en reglas (`allow write: if false`).
- [x] SEARCH-03: modo mapa usa el mismo dataset que lista (`state.results`).
- [x] SEARCH-03: sistema de markers por prioridad operativa (`guardia`, `open24h`, `open`, `closed`, `default`) con variantes seleccionadas.
- [x] SEARCH-03: tap pin -> card reducida; tap card -> navega a DETAIL.
- [x] SEARCH-03: clustering por grilla activo con más de 20 comercios visibles.
- [x] SEARCH-03: tap en cluster realiza zoom in automático y recentra.
- [x] SEARCH-03: cache de bitmap descriptor por `visualType + pixelRatio`.
- [x] SEARCH-02: filtro `openNow` excluye `isOpenNow == null` (test unitario).
- [ ] SEARCH-01/02 E2E visual con capturas reales de emulador.

## Evidencia automatizada

### Functions

Comando:

```bash
cd functions
npm.cmd run test
```

Resultado:

- 11 tests ejecutados.
- 11 tests pasados.
- 0 fallos.

Cobertura funcional:

- tildes
- Dr./Dra./Prof.
- categoria compuesta
- direccion sin numero
- emojis/caracteres especiales
- nombre vacio
- proyeccion publica con `searchKeywords`
- seguridad admin/no-admin para backfill

### Flutter (SEARCH)

Comando:

```bash
cd mobile
flutter test test/modules/search/search_notifier_test.dart test/modules/search/search_history_provider_test.dart
```

Resultado:

- 5 tests ejecutados.
- 5 tests pasados.

Cobertura funcional:

- normalizacion sin tildes
- query corta `<3`
- filtros en cascada
- exclusion de `isOpenNow == null` con filtro openNow
- historial (maximo 10, dedupe, persistencia)

## Validacion manual reproducible (E2E SEARCH)

### Precondiciones

1. Levantar emuladores Firebase o usar staging habilitado.
2. App logueada con usuario CUSTOMER.
3. Dataset con `merchant_public` en al menos una `zoneId`.

### Pasos SEARCH-01 (sugerencias + historial)

1. Abrir tab Buscar.
2. Escribir consulta de 3+ caracteres.
3. Validar aparicion de sugerencias en menos de 300 ms (debounce 250 ms).
4. Ejecutar busqueda y volver.
5. Validar que aparece en "busquedas recientes".

Captura sugerida:

- `search-home-suggestions.png`
- `search-home-history.png`

### Pasos SEARCH-02 (estados + filtros + zona)

1. Entrar a resultados con query valida.
2. Validar estados: loading -> resultados.
3. Activar filtro `Abierto ahora` y confirmar que no aparecen items con estado horario nulo.
4. Cambiar zona desde `ZoneSelectorSheet`.
5. Validar recarga de corpus y resultados.
6. Forzar error de red para validar estado error.
7. Buscar termino sin matches para validar empty state.

Captura sugerida:

- `search-results-loading.png`
- `search-results-open-now.png`
- `search-results-empty.png`
- `search-results-error.png`

### Pasos SEARCH-03 (mapa real + clustering)

1. En resultados tocar `Ver mapa`.
2. Validar pins por estado:
   - guardia (rojo dominante)
   - abierto (verde)
   - 24h (azul)
   - cerrado (gris neutro)
   - default (oscuro)
3. Tocar pin y validar card reducida del comercio seleccionado.
4. Validar que el pin seleccionado usa variante visual destacada.
5. Con zoom out y >20 visibles, validar aparición de clusters y contador.
6. Tocar cluster y validar zoom in automático.
7. Tocar card y validar navegacion a `/commerce/:id`.
8. Volver a lista y validar mismo set de resultados.

Captura sugerida:

- `search-map-pins.png`
- `search-map-selected-card.png`
- `search-map-clusters.png`

## Backfill operativo

Callable:

- `backfillSearchKeywords` (Cloud Functions v2 onCall)

Seguridad:

- requiere auth
- requiere custom claim `admin == true`
- no-admin -> `permission-denied`

Salida esperada:

```json
{
  "scanned": 0,
  "updated": 0,
  "skipped": 0,
  "failed": 0,
  "missingBefore": 0
}
```

Campos:

- `scanned`: docs `merchant_public` evaluados
- `updated`: docs parcheados
- `skipped`: docs sin cambios
- `failed`: docs con error de procesamiento
- `missingBefore`: docs que no tenian `searchKeywords`

## Analytics SEARCH (DebugView)

Eventos implementados:

- `search_query_submitted`
- `search_filter_applied`
- `search_map_toggled`
- `search_result_opened`
- `search_zone_changed`
- `search_empty_state_seen`

Verificacion:

1. Ejecutar app en debug.
2. Activar DebugView de Firebase Analytics.
3. Repetir flujo SEARCH-01/02/03.
4. Verificar eventos y parametros no sensibles (`query_length`, `zone_id`, `results_count`, etc).

## Pendientes por entorno

- Capturas reales E2E no generadas en este entorno CLI.
- `flutter test` completo del repo no verde por fallas preexistentes fuera de SEARCH.
