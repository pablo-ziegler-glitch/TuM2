/// Modelo UI para un batch de importación de dataset.
/// Extiende el contrato de Firestore import_batches/{batchId}.
enum ImportBatchStatus { running, completed, failed, rolledBack, hidden }

enum DatasetType {
  farmaciasRepes,
  puntosWifi,
  clubesDeBarrio,
  mercadosMunicipales,
  custom,
}

extension DatasetTypeLabel on DatasetType {
  String get label {
    switch (this) {
      case DatasetType.farmaciasRepes:
        return 'Farmacias REPES';
      case DatasetType.puntosWifi:
        return 'Puntos WiFi Públicos';
      case DatasetType.clubesDeBarrio:
        return 'Clubes de Barrio';
      case DatasetType.mercadosMunicipales:
        return 'Mercados Municipales';
      case DatasetType.custom:
        return 'Personalizado';
    }
  }
}

/// Mapeo de un campo CSV a un campo TuM2.
class FieldMapping {
  const FieldMapping({
    required this.csvColumn,
    required this.tum2Field,
    required this.enabled,
    required this.required,
  });

  final String csvColumn;
  final String tum2Field;
  final bool enabled;
  final bool required;
}

/// Error de fila durante la importación.
class ImportRowError {
  const ImportRowError({
    required this.row,
    required this.establishmentName,
    required this.reason,
  });

  final int row;
  final String establishmentName;
  final String reason;
}

/// Modelo completo de un batch de importación para la UI.
class ImportBatchUi {
  const ImportBatchUi({
    required this.id,
    required this.batchNumber,
    required this.datasetType,
    required this.zone,
    required this.status,
    required this.processedCount,
    required this.createdCount,
    required this.duplicatedCount,
    required this.errorCount,
    required this.pendingReviewCount,
    required this.createdAt,
    required this.createdBy,
    this.finishedAt,
    this.errors = const [],
    this.fieldMappings = const [],
    this.deduplicationEnabled = true,
    this.visibilityAfterImport = 'hidden',
    this.fileUrl,
    this.estimatedCost = 0,
  });

  final String id;
  final int batchNumber;
  final DatasetType datasetType;
  final String zone;
  final ImportBatchStatus status;
  final int processedCount;
  final int createdCount;
  final int duplicatedCount;
  final int errorCount;
  final int pendingReviewCount;
  final DateTime createdAt;
  final String createdBy;
  final DateTime? finishedAt;
  final List<ImportRowError> errors;
  final List<FieldMapping> fieldMappings;
  final bool deduplicationEnabled;
  final String visibilityAfterImport; // 'hidden' | 'visible'
  final String? fileUrl;
  final double estimatedCost;

  String get statusLabel {
    switch (status) {
      case ImportBatchStatus.running:
        return 'En proceso';
      case ImportBatchStatus.completed:
        return 'Completado';
      case ImportBatchStatus.failed:
        return 'Fallido';
      case ImportBatchStatus.rolledBack:
        return 'Revertido';
      case ImportBatchStatus.hidden:
        return 'Escondido';
    }
  }
}

// ── Mock data para desarrollo ────────────────────────────────────────────────

final mockBatches = <ImportBatchUi>[
  ImportBatchUi(
    id: 'batch_482',
    batchNumber: 482,
    datasetType: DatasetType.farmaciasRepes,
    zone: 'Córdoba — Marcos Juárez',
    status: ImportBatchStatus.completed,
    processedCount: 1259,
    createdCount: 1108,
    duplicatedCount: 82,
    errorCount: 12,
    pendingReviewCount: 57,
    createdAt: DateTime(2026, 3, 23, 14, 32),
    createdBy: 'Marcos P.',
    errors: [
      const ImportRowError(row: 18, establishmentName: 'Farmacia del Sol', reason: 'Latitud fuera de rango'),
      const ImportRowError(row: 62, establishmentName: 'Botica del Boulevard', reason: 'GPS inválido'),
    ],
    fieldMappings: [
      const FieldMapping(csvColumn: 'business_name', tum2Field: 'Nombre del Negocio', enabled: true, required: true),
      const FieldMapping(csvColumn: 'phone_number', tum2Field: 'Teléfono Principal', enabled: true, required: false),
      const FieldMapping(csvColumn: 'full_address', tum2Field: 'Dirección Completa', enabled: true, required: true),
      const FieldMapping(csvColumn: 'opening_hours', tum2Field: 'Horario de Atención', enabled: false, required: false),
    ],
  ),
  ImportBatchUi(
    id: 'batch_481',
    batchNumber: 481,
    datasetType: DatasetType.puntosWifi,
    zone: 'CABA — Comunas 1, 2, 3',
    status: ImportBatchStatus.running,
    processedCount: 490,
    createdCount: 400,
    duplicatedCount: 12,
    errorCount: 2,
    pendingReviewCount: 76,
    createdAt: DateTime(2026, 3, 22, 9, 15),
    createdBy: 'Admin',
  ),
  ImportBatchUi(
    id: 'batch_480',
    batchNumber: 480,
    datasetType: DatasetType.clubesDeBarrio,
    zone: 'Buenos Aires — Lomas',
    status: ImportBatchStatus.failed,
    processedCount: 52,
    createdCount: 0,
    duplicatedCount: 0,
    errorCount: 12,
    pendingReviewCount: 0,
    createdAt: DateTime(2026, 3, 21, 18, 0),
    createdBy: 'Admin',
  ),
  ImportBatchUi(
    id: 'batch_479',
    batchNumber: 479,
    datasetType: DatasetType.mercadosMunicipales,
    zone: 'Salta — Capital',
    status: ImportBatchStatus.hidden,
    processedCount: 59,
    createdCount: 47,
    duplicatedCount: 8,
    errorCount: 4,
    pendingReviewCount: 0,
    createdAt: DateTime(2026, 3, 20, 7, 20),
    createdBy: 'Admin',
  ),
];

/// Fila de preview CSV para el paso de previsualización.
class CsvPreviewRow {
  const CsvPreviewRow({
    required this.name,
    required this.locality,
    required this.typology,
    required this.address,
    required this.longitude,
    required this.latitude,
    required this.state,
    required this.hasError,
    required this.hasWarning,
  });

  final String name;
  final String locality;
  final String typology;
  final String address;
  final String longitude;
  final String latitude;
  final String state;
  final bool hasError;
  final bool hasWarning;
}

/// Mock de preview del CSV.
final mockCsvPreview = <CsvPreviewRow>[
  const CsvPreviewRow(name: 'Café Los Gallegos', locality: 'CABA', typology: 'GAST', address: 'Av. Rivadavia 3480', longitude: '-58.4123', latitude: '-34.6111', state: '●', hasError: false, hasWarning: false),
  const CsvPreviewRow(name: 'Panadería Del', locality: 'Córdoba', typology: 'COM', address: 'Belgrano 320', longitude: '4/0', latitude: '4/0', state: '▲', hasError: true, hasWarning: false),
  const CsvPreviewRow(name: 'Farmacia Central', locality: 'Rosario', typology: 'FAI', address: 'Uruguay 906', longitude: '-60.6394', latitude: '-32.9468', state: '●', hasError: false, hasWarning: false),
  const CsvPreviewRow(name: 'Librería & Ateneos', locality: 'CABA', typology: 'COM', address: 'Av. Santa fe 1860', longitude: '-58.3965', latitude: '-34.5969', state: '●', hasError: false, hasWarning: false),
  const CsvPreviewRow(name: 'Mercado San Juan', locality: 'Mendoza', typology: 'COM', address: 'San Martín 900', longitude: 'invalid_format', latitude: '-32.8895', state: '▲', hasError: false, hasWarning: true),
  const CsvPreviewRow(name: '1er Notable de Billares', locality: 'CABA', typology: 'GASI', address: 'Av. de Mayo 7271', longitude: '-58.3868', latitude: '-34.6094', state: '●', hasError: false, hasWarning: false),
  const CsvPreviewRow(name: 'Hotel Alvear', locality: 'CABA', typology: 'HOT', address: 'Av. Alvear 1891', longitude: '-58.3892', latitude: '-34.5692', state: '●', hasError: false, hasWarning: false),
  const CsvPreviewRow(name: 'Teatro Colón', locality: 'CABA', typology: 'CULT', address: 'Cerrito 822', longitude: '-58.3831', latitude: '-34.6011', state: '●', hasError: false, hasWarning: false),
  const CsvPreviewRow(name: 'Resta Puerto', locality: 'Mar del Plata', typology: 'GAST', address: 'Juan B. Justo 200', longitude: '-57.5342', latitude: '-38.0345', state: '●', hasError: false, hasWarning: false),
  const CsvPreviewRow(name: 'Kiosco Central', locality: 'Tucumán', typology: 'COM', address: 'B de Julio 122', longitude: '-65.2038', latitude: '-26.8327', state: '●', hasError: false, hasWarning: false),
];
