/// Modelo UI para un batch de importación de dataset.
/// Extiende el contrato de Firestore import_batches/{batchId}.

// ── Enumeraciones ─────────────────────────────────────────────────────────────

enum ImportBatchStatus { draft, running, validated, completed, failed, partial, archived, rolledBack, hidden }

/// Tipo de importación — determina columnas, validaciones y destino.
enum ImportType {
  officialDataset,   // Dataset oficial (ej: REPES, puntos WiFi municipales)
  masterCatalog,     // Catálogo maestro de productos (barcode + nombre + marca)
  genericInternal,   // Fuente genérica/interna personalizada
}

extension ImportTypeLabel on ImportType {
  String get label {
    switch (this) {
      case ImportType.officialDataset:
        return 'Official Dataset';
      case ImportType.masterCatalog:
        return 'Master Catalog';
      case ImportType.genericInternal:
        return 'Generic / Internal';
    }
  }

  String get description {
    switch (this) {
      case ImportType.officialDataset:
        return 'Government or institutional datasets — pharmacies, WiFi hotspots, municipal markets';
      case ImportType.masterCatalog:
        return 'Product catalog data — barcodes, names, brands, categories';
      case ImportType.genericInternal:
        return 'Custom internal sources — manual exports, partner data, one-off imports';
    }
  }
}

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

// ── Modelos de soporte ────────────────────────────────────────────────────────

/// Mapeo de un campo CSV a un campo TuM2.
class FieldMapping {
  const FieldMapping({
    required this.csvColumn,
    required this.tum2Field,
    required this.enabled,
    required this.required,
    this.aiConfidence,
    this.sampleValue,
  });

  final String csvColumn;
  final String tum2Field;
  final bool enabled;
  final bool required;
  /// Confianza IA en el mapeo automático (0.0 – 1.0).
  final double? aiConfidence;
  /// Valor de ejemplo del CSV para la columna.
  final String? sampleValue;
}

/// Error de fila durante la importación.
class ImportRowError {
  const ImportRowError({
    required this.row,
    required this.establishmentName,
    required this.reason,
    this.severity = ImportIssueSeverity.error,
  });

  final int row;
  final String establishmentName;
  final String reason;
  final ImportIssueSeverity severity;
}

enum ImportIssueSeverity { critical, error, warning, info }

extension ImportIssueSeverityLabel on ImportIssueSeverity {
  String get label {
    switch (this) {
      case ImportIssueSeverity.critical:
        return 'CRITICAL';
      case ImportIssueSeverity.error:
        return 'ERROR';
      case ImportIssueSeverity.warning:
        return 'WARNING';
      case ImportIssueSeverity.info:
        return 'INFO';
    }
  }
}

/// Evento en la línea de tiempo de auditoría de un batch.
class AuditTimelineEvent {
  const AuditTimelineEvent({
    required this.stage,
    required this.label,
    required this.timestamp,
    required this.actor,
    required this.result,
    this.detail,
  });

  final String stage;
  final String label;
  final DateTime timestamp;
  final String actor;
  final bool result;
  final String? detail;
}

// ── Modelo principal ──────────────────────────────────────────────────────────

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
    this.importType = ImportType.officialDataset,
    this.finishedAt,
    this.errors = const [],
    this.fieldMappings = const [],
    this.deduplicationEnabled = true,
    this.visibilityAfterImport = 'hidden',
    this.fileUrl,
    this.fileName,
    this.fileSize,
    this.fileHash,
    this.estimatedCost = 0,
    this.validRows = 0,
    this.warningRows = 0,
    this.stagingCount = 0,
    this.mergeCandidateCount = 0,
    this.actorRole,
    this.templateName,
    this.auditTrail = const [],
  });

  final String id;
  final int batchNumber;
  final DatasetType datasetType;
  final String zone;
  final ImportBatchStatus status;
  final ImportType importType;
  final int processedCount;
  final int createdCount;
  final int duplicatedCount;
  final int errorCount;
  final int pendingReviewCount;
  final int validRows;
  final int warningRows;
  final int stagingCount;
  final int mergeCandidateCount;
  final DateTime createdAt;
  final String createdBy;
  final String? actorRole;
  final DateTime? finishedAt;
  final List<ImportRowError> errors;
  final List<FieldMapping> fieldMappings;
  final bool deduplicationEnabled;
  final String visibilityAfterImport; // 'hidden' | 'visible'
  final String? fileUrl;
  final String? fileName;
  final String? fileSize;  // ej: "2.4 MB"
  final String? fileHash;  // SHA-256 para evitar reprocesamiento
  final double estimatedCost;
  final String? templateName;
  final List<AuditTimelineEvent> auditTrail;

  String get statusLabel {
    switch (status) {
      case ImportBatchStatus.draft:
        return 'Borrador';
      case ImportBatchStatus.running:
        return 'En proceso';
      case ImportBatchStatus.validated:
        return 'Validado';
      case ImportBatchStatus.completed:
        return 'Completado';
      case ImportBatchStatus.failed:
        return 'Fallido';
      case ImportBatchStatus.partial:
        return 'Parcial';
      case ImportBatchStatus.archived:
        return 'Archivado';
      case ImportBatchStatus.rolledBack:
        return 'Revertido';
      case ImportBatchStatus.hidden:
        return 'Escondido';
    }
  }

  double get successRate {
    if (processedCount == 0) return 0;
    return createdCount / processedCount;
  }
}

// ── Mock data para desarrollo ─────────────────────────────────────────────────

final mockBatches = <ImportBatchUi>[
  ImportBatchUi(
    id: 'batch_482',
    batchNumber: 482,
    datasetType: DatasetType.farmaciasRepes,
    importType: ImportType.officialDataset,
    zone: 'Córdoba — Marcos Juárez',
    status: ImportBatchStatus.completed,
    processedCount: 1259,
    createdCount: 1108,
    duplicatedCount: 82,
    errorCount: 12,
    pendingReviewCount: 57,
    validRows: 1202,
    warningRows: 45,
    stagingCount: 1108,
    mergeCandidateCount: 24,
    createdAt: DateTime(2026, 3, 23, 14, 32),
    createdBy: 'Marcos P.',
    actorRole: 'Data Ops Admin',
    finishedAt: DateTime(2026, 3, 23, 14, 47),
    fileName: 'farmacias_repes_cordoba_2026_03.csv',
    fileSize: '2.4 MB',
    fileHash: 'a3f5c9d1e7b2f648a3f5c9d1e7b2f648',
    templateName: 'REPES Official v2.1',
    errors: [
      const ImportRowError(row: 18, establishmentName: 'Farmacia del Sol', reason: 'Latitud fuera de rango', severity: ImportIssueSeverity.error),
      const ImportRowError(row: 62, establishmentName: 'Botica del Boulevard', reason: 'GPS inválido', severity: ImportIssueSeverity.error),
      const ImportRowError(row: 91, establishmentName: 'Farmacia Central Norte', reason: 'Dirección duplicada en zona', severity: ImportIssueSeverity.warning),
      const ImportRowError(row: 124, establishmentName: 'Droguería San Marcos', reason: 'Nombre demasiado largo (>120 chars)', severity: ImportIssueSeverity.warning),
    ],
    fieldMappings: [
      const FieldMapping(csvColumn: 'business_name', tum2Field: 'Nombre del Negocio', enabled: true, required: true, aiConfidence: 0.98, sampleValue: 'Farmacia del Sol'),
      const FieldMapping(csvColumn: 'phone_number', tum2Field: 'Teléfono Principal', enabled: true, required: false, aiConfidence: 0.95, sampleValue: '+54 351 421-0000'),
      const FieldMapping(csvColumn: 'full_address', tum2Field: 'Dirección Completa', enabled: true, required: true, aiConfidence: 0.97, sampleValue: 'Av. Colón 1200, Córdoba'),
      const FieldMapping(csvColumn: 'opening_hours', tum2Field: 'Horario de Atención', enabled: false, required: false, aiConfidence: 0.72, sampleValue: 'L-V 8-20'),
    ],
    auditTrail: [
      AuditTimelineEvent(stage: 'upload', label: 'File Uploaded', timestamp: DateTime(2026, 3, 23, 14, 32), actor: 'Marcos P.', result: true, detail: 'farmacias_repes_cordoba_2026_03.csv · 2.4 MB'),
      AuditTimelineEvent(stage: 'parse', label: 'CSV Parsed', timestamp: DateTime(2026, 3, 23, 14, 33), actor: 'system', result: true, detail: '1,259 rows · UTF-8 · 12 columns detected'),
      AuditTimelineEvent(stage: 'map', label: 'Fields Mapped', timestamp: DateTime(2026, 3, 23, 14, 34), actor: 'Marcos P.', result: true, detail: '4 fields mapped · 1 disabled'),
      AuditTimelineEvent(stage: 'validate', label: 'Validation Complete', timestamp: DateTime(2026, 3, 23, 14, 36), actor: 'system', result: true, detail: '1,202 valid · 45 warnings · 12 errors'),
      AuditTimelineEvent(stage: 'stage', label: 'Staged to Firestore', timestamp: DateTime(2026, 3, 23, 14, 40), actor: 'system', result: true, detail: '1,108 records staged (hidden)'),
      AuditTimelineEvent(stage: 'confirm', label: 'Import Confirmed', timestamp: DateTime(2026, 3, 23, 14, 47), actor: 'Marcos P.', result: true, detail: 'Batch marked as completed'),
    ],
  ),
  ImportBatchUi(
    id: 'batch_481',
    batchNumber: 481,
    datasetType: DatasetType.puntosWifi,
    importType: ImportType.officialDataset,
    zone: 'CABA — Comunas 1, 2, 3',
    status: ImportBatchStatus.running,
    processedCount: 490,
    createdCount: 400,
    duplicatedCount: 12,
    errorCount: 2,
    pendingReviewCount: 76,
    validRows: 450,
    warningRows: 38,
    stagingCount: 400,
    mergeCandidateCount: 12,
    createdAt: DateTime(2026, 3, 22, 9, 15),
    createdBy: 'Admin',
    actorRole: 'System Admin',
    fileName: 'badata_wifi_comunas_1_2_3.csv',
    fileSize: '890 KB',
    fileHash: 'b7e4a2c8f1d3e9b7e4a2c8f1d3e9b7e4',
  ),
  ImportBatchUi(
    id: 'batch_480',
    batchNumber: 480,
    datasetType: DatasetType.clubesDeBarrio,
    importType: ImportType.officialDataset,
    zone: 'Buenos Aires — Lomas',
    status: ImportBatchStatus.failed,
    processedCount: 52,
    createdCount: 0,
    duplicatedCount: 0,
    errorCount: 12,
    pendingReviewCount: 0,
    validRows: 40,
    warningRows: 0,
    createdAt: DateTime(2026, 3, 21, 18, 0),
    createdBy: 'Admin',
    fileName: 'clubes_lomas_2026.xlsx',
    fileSize: '124 KB',
  ),
  ImportBatchUi(
    id: 'batch_479',
    batchNumber: 479,
    datasetType: DatasetType.mercadosMunicipales,
    importType: ImportType.genericInternal,
    zone: 'Salta — Capital',
    status: ImportBatchStatus.hidden,
    processedCount: 59,
    createdCount: 47,
    duplicatedCount: 8,
    errorCount: 4,
    pendingReviewCount: 0,
    validRows: 55,
    warningRows: 4,
    stagingCount: 47,
    mergeCandidateCount: 2,
    createdAt: DateTime(2026, 3, 20, 7, 20),
    createdBy: 'Admin',
    fileName: 'mercados_salta_capital_export.csv',
    fileSize: '320 KB',
  ),
];

// ── Mock global KPIs ──────────────────────────────────────────────────────────

class ImportOverviewKpis {
  const ImportOverviewKpis({
    required this.totalImports,
    required this.successRate,
    required this.failedBatches,
    required this.rowsProcessed,
    required this.pendingConflicts,
    required this.activeTemplates,
  });

  final int totalImports;
  final double successRate;
  final int failedBatches;
  final int rowsProcessed;
  final int pendingConflicts;
  final int activeTemplates;
}

const mockOverviewKpis = ImportOverviewKpis(
  totalImports: 482,
  successRate: 0.947,
  failedBatches: 3,
  rowsProcessed: 48291,
  pendingConflicts: 139,
  activeTemplates: 7,
);

// ── Mock CSV preview ──────────────────────────────────────────────────────────

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
