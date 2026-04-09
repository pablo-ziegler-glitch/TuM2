# TuM2-0068 — Carga masiva de turnos de farmacia (OWNER-12)

Estado: IN PROGRESS  
Fecha: 2026-04-08

## Objetivo

Agregar una capacidad de carga masiva de turnos para farmacias, permitiendo que una farmacia cargue:

- turnos de su propio comercio,
- turnos de comercios cercanos que pertenezcan a su red habilitada.

El flujo debe reemplazar la carga 1 a 1 cuando el volumen operativo lo requiera.

## Alcance funcional

Se incorpora una nueva pantalla OWNER:

- `OWNER-12 — Carga masiva de turnos`
- Ruta: `/owner/pharmacy-duties/bulk-upload`
- Accesible desde:
  - panel OWNER (acción rápida),
  - vista OWNER para sesión ADMIN,
  - pantalla de calendario de turnos (`OWNER-10`) mediante CTA de carga masiva.

## Plantilla de archivo

Formato objetivo: `.xlsx` (planilla oficial).

Columnas obligatorias:

1. `fecha` (YYYY-MM-DD)
2. `hora_desde` (HH:mm)
3. `hora_hasta` (HH:mm)
4. `farmacia_origen_id` (merchantId que realiza la carga)
5. `farmacia_turno_id` (merchantId de la farmacia que quedará de turno)
6. `tipo_turno` (ej: `regular`, `feriado`, `reemplazo`)
7. `observaciones` (opcional, texto breve)

## Reglas de negocio

1. `farmacia_origen_id` debe coincidir con la farmacia del usuario autenticado o una farmacia gestionada por sesión admin.
2. `farmacia_turno_id` debe ser:
   - la propia farmacia origen, o
   - una farmacia vinculada en la red autorizada.
3. No permitir superposición horaria para la misma `farmacia_turno_id` y fecha.
4. No permitir `hora_hasta <= hora_desde`.
5. Evitar duplicados exactos de turno en una misma importación.
6. Validar existencia y estado activo de farmacia destino.

## Resultado de importación

La importación debe ser parcialmente tolerante a errores:

- filas válidas: se importan,
- filas inválidas: se rechazan con motivo puntual.

Salida esperada:

- `totalRows`
- `acceptedRows`
- `rejectedRows`
- `errors[]` por fila: `rowNumber`, `code`, `message`, `field`.

## Contrato API propuesto

Callable Functions:

1. `pharmacyDutiesDownloadTemplate`
   - entrada: `{ version?: string }`
   - salida: `{ url: string, expiresAt: number, checksum: string }`

2. `pharmacyDutiesBulkUpload`
   - entrada:
     - `fileUrl` (archivo subido temporalmente),
     - `originMerchantId`,
     - `timezone`,
     - `dryRun` (bool)
   - salida:
     - `batchId`,
     - `totalRows`,
     - `acceptedRows`,
     - `rejectedRows`,
     - `errors[]`.

## Modelo de datos propuesto

Colección sugerida:

`pharmacy_duty_import_batches/{batchId}`

Campos:

- `originMerchantId`
- `uploadedByUid`
- `status` (`processing`, `completed`, `failed`, `completed_with_errors`)
- `totalRows`
- `acceptedRows`
- `rejectedRows`
- `errors` (array acotado) o subcolección `errors`
- `sourceFilePath`
- `createdAt`
- `updatedAt`

Auditoría:

- registro en `audit_logs` por cada batch aceptado.

## Seguridad

Validación server-side obligatoria:

- claim `role` en (`owner`, `admin`, `super_admin`),
- ownership sobre `originMerchantId` cuando `role=owner`,
- pertenencia a red entre origen y destino en cada fila.

No confiar en validación de cliente para autorización.

## UX definida para OWNER-12

1. Descargar plantilla.
2. Ver columnas requeridas.
3. Subir archivo.
4. Ver resumen.
5. Descargar reporte de errores.

Microcopy clave:

- “Importá múltiples turnos en un solo archivo”.
- “Cada fila se valida en forma independiente”.
- “Podés cargar turnos propios y de farmacias de tu red”.

## Analytics sugerida

- `owner_duties_bulk_screen_view`
- `owner_duties_bulk_template_download`
- `owner_duties_bulk_upload_start`
- `owner_duties_bulk_upload_result`
- `owner_duties_bulk_upload_error`

## DoD (Definition of Done)

- pantalla OWNER-12 accesible por ruta y por tarjetas del panel,
- documentación de plantilla y reglas versionada,
- backend de importación con resultado por fila,
- validaciones de red y ownership aplicadas,
- test unitarios de parsing/validación y test de integración de callable,
- evento de analytics en puntos críticos del flujo.
