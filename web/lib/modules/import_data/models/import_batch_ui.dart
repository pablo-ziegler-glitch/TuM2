import 'package:cloud_firestore/cloud_firestore.dart';

enum ImportBatchStatus {
  draft,
  running,
  validated,
  completed,
  failed,
  partial,
  archived,
  rolledBack,
  hidden,
}

enum ImportType { officialDataset, masterCatalog, genericInternal }

extension ImportTypeLabel on ImportType {
  String get label {
    switch (this) {
      case ImportType.officialDataset:
        return 'Dataset oficial';
      case ImportType.masterCatalog:
        return 'Catalogo maestro';
      case ImportType.genericInternal:
        return 'Generico / Interno';
    }
  }

  String get description {
    switch (this) {
      case ImportType.officialDataset:
        return 'Datasets gubernamentales o institucionales - farmacias, puntos WiFi y mercados municipales';
      case ImportType.masterCatalog:
        return 'Datos de catalogo de productos - codigos de barras, nombres, marcas y categorias';
      case ImportType.genericInternal:
        return 'Fuentes internas personalizadas - exportaciones manuales, datos de partners e importaciones puntuales';
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

enum ImportIssueSeverity { critical, error, warning, info }

extension ImportIssueSeverityLabel on ImportIssueSeverity {
  String get label {
    switch (this) {
      case ImportIssueSeverity.critical:
        return 'CRITICO';
      case ImportIssueSeverity.error:
        return 'ERROR';
      case ImportIssueSeverity.warning:
        return 'ADVERTENCIA';
      case ImportIssueSeverity.info:
        return 'INFO';
    }
  }
}

const tum2FieldName = 'Nombre del Negocio';
const tum2FieldPhone = 'Teléfono Principal';
const tum2FieldAddress = 'Dirección Completa';
const tum2FieldHours = 'Horario de Atención';
const tum2FieldCategory = 'Categoría Principal';
const tum2FieldDescription = 'Descripción';
const tum2FieldWebsite = 'Sitio Web';
const tum2FieldEmail = 'Email de Contacto';
const tum2FieldLatitude = 'Latitud';
const tum2FieldLongitude = 'Longitud';
const tum2FieldLocality = 'Localidad';

const tum2AssignableFields = <String>[
  tum2FieldName,
  tum2FieldPhone,
  tum2FieldAddress,
  tum2FieldHours,
  tum2FieldCategory,
  tum2FieldDescription,
  tum2FieldWebsite,
  tum2FieldEmail,
  tum2FieldLatitude,
  tum2FieldLongitude,
  tum2FieldLocality,
];

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
  final double? aiConfidence;
  final String? sampleValue;

  FieldMapping copyWith({String? tum2Field, bool? enabled}) {
    return FieldMapping(
      csvColumn: csvColumn,
      tum2Field: tum2Field ?? this.tum2Field,
      enabled: enabled ?? this.enabled,
      required: required,
      aiConfidence: aiConfidence,
      sampleValue: sampleValue,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'csvColumn': csvColumn,
      'tum2Field': tum2Field,
      'enabled': enabled,
      'required': required,
      'aiConfidence': aiConfidence,
      'sampleValue': sampleValue,
    };
  }

  factory FieldMapping.fromMap(Map<String, dynamic> map) {
    return FieldMapping(
      csvColumn: map['csvColumn']?.toString() ?? '',
      tum2Field: map['tum2Field']?.toString() ?? '',
      enabled: map['enabled'] == true,
      required: map['required'] == true,
      aiConfidence: _toDoubleOrNull(map['aiConfidence']),
      sampleValue: map['sampleValue']?.toString(),
    );
  }
}

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

  Map<String, Object?> toMap() {
    return {
      'row': row,
      'establishmentName': establishmentName,
      'reason': reason,
      'severity': severity.name,
    };
  }

  factory ImportRowError.fromMap(Map<String, dynamic> map) {
    final severityRaw =
        map['severity']?.toString() ?? ImportIssueSeverity.error.name;
    return ImportRowError(
      row: _toInt(map['row']),
      establishmentName: map['establishmentName']?.toString() ?? '',
      reason: map['reason']?.toString() ?? 'Validation error',
      severity: ImportIssueSeverity.values.firstWhere(
        (value) => value.name == severityRaw,
        orElse: () => ImportIssueSeverity.error,
      ),
    );
  }
}

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

  Map<String, Object?> toMap() {
    return {
      'stage': stage,
      'label': label,
      'timestamp': Timestamp.fromDate(timestamp),
      'actor': actor,
      'result': result,
      'detail': detail,
    };
  }

  factory AuditTimelineEvent.fromMap(Map<String, dynamic> map) {
    return AuditTimelineEvent(
      stage: map['stage']?.toString() ?? '',
      label: map['label']?.toString() ?? '',
      timestamp: _toDateTime(map['timestamp']) ?? DateTime.now(),
      actor: map['actor']?.toString() ?? 'system',
      result: map['result'] != false,
      detail: map['detail']?.toString(),
    );
  }
}

class ImportBatchUi {
  const ImportBatchUi({
    required this.id,
    required this.batchNumber,
    required this.datasetType,
    required this.zone,
    this.zoneId,
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
  final String? zoneId;
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
  final String visibilityAfterImport;
  final String? fileUrl;
  final String? fileName;
  final String? fileSize;
  final String? fileHash;
  final double estimatedCost;
  final String? templateName;
  final List<AuditTimelineEvent> auditTrail;

  String get statusLabel {
    switch (status) {
      case ImportBatchStatus.draft:
        return 'En cola';
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

  static ImportBatchUi fromDoc(String id, Map<String, dynamic> map) {
    final importType = parseImportType(map['importType']?.toString());
    final datasetType = parseDatasetType(map['datasetType']?.toString());
    final status = parseStatus(map['status']?.toString());
    final createdAt = _toDateTime(map['createdAt']) ?? DateTime.now();

    final errorsRaw = (map['errors'] as List<dynamic>? ?? const []);
    final mappingsRaw = (map['fieldMappings'] as List<dynamic>? ?? const []);
    final trailRaw = (map['auditTrail'] as List<dynamic>? ?? const []);

    return ImportBatchUi(
      id: id,
      batchNumber: _toInt(map['batchNumber']),
      datasetType: datasetType,
      zone: map['zone']?.toString() ?? '',
      zoneId: map['zoneId']?.toString(),
      status: status,
      importType: importType,
      processedCount: _toInt(map['processedCount']),
      createdCount: _toInt(map['createdCount']),
      duplicatedCount: _toInt(map['duplicatedCount']),
      errorCount: _toInt(map['errorCount']),
      pendingReviewCount: _toInt(map['pendingReviewCount']),
      validRows: _toInt(map['validRows']),
      warningRows: _toInt(map['warningRows']),
      stagingCount: _toInt(map['stagingCount']),
      mergeCandidateCount: _toInt(map['mergeCandidateCount']),
      createdAt: createdAt,
      createdBy: map['createdBy']?.toString() ?? 'unknown',
      actorRole: map['actorRole']?.toString(),
      finishedAt: _toDateTime(map['finishedAt']),
      errors: errorsRaw
          .whereType<Map<String, dynamic>>()
          .map(ImportRowError.fromMap)
          .toList(),
      fieldMappings: mappingsRaw
          .whereType<Map<String, dynamic>>()
          .map(FieldMapping.fromMap)
          .toList(),
      deduplicationEnabled: map['deduplicationEnabled'] != false,
      visibilityAfterImport:
          map['visibilityAfterImport']?.toString() ?? 'hidden',
      fileUrl: map['fileUrl']?.toString(),
      fileName: map['fileName']?.toString(),
      fileSize: map['fileSize']?.toString(),
      fileHash: map['fileHash']?.toString(),
      estimatedCost: _toDoubleOrNull(map['estimatedCost']) ?? 0,
      templateName: map['templateName']?.toString(),
      auditTrail: trailRaw
          .whereType<Map<String, dynamic>>()
          .map(AuditTimelineEvent.fromMap)
          .toList(),
    );
  }
}

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

  factory ImportOverviewKpis.fromBatches(List<ImportBatchUi> batches) {
    final totalImports = batches.length;
    final completed =
        batches.where((b) => b.status == ImportBatchStatus.completed).length;
    final failedBatches =
        batches.where((b) => b.status == ImportBatchStatus.failed).length;
    final rowsProcessed = batches.fold<int>(
      0,
      (sum, b) => sum + b.processedCount,
    );
    final pendingConflicts = batches.fold<int>(
      0,
      (sum, b) => sum + b.pendingReviewCount,
    );
    final activeTemplates = batches
        .map((batch) => batch.templateName)
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty)
        .toSet()
        .length;

    return ImportOverviewKpis(
      totalImports: totalImports,
      successRate: totalImports == 0 ? 0 : (completed / totalImports),
      failedBatches: failedBatches,
      rowsProcessed: rowsProcessed,
      pendingConflicts: pendingConflicts,
      activeTemplates: activeTemplates,
    );
  }
}

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

ImportType parseImportType(String? raw) {
  switch (raw) {
    case 'masterCatalog':
      return ImportType.masterCatalog;
    case 'genericInternal':
      return ImportType.genericInternal;
    case 'officialDataset':
    default:
      return ImportType.officialDataset;
  }
}

DatasetType parseDatasetType(String? raw) {
  switch (raw) {
    case 'puntosWifi':
      return DatasetType.puntosWifi;
    case 'clubesDeBarrio':
      return DatasetType.clubesDeBarrio;
    case 'mercadosMunicipales':
      return DatasetType.mercadosMunicipales;
    case 'custom':
      return DatasetType.custom;
    case 'farmaciasRepes':
    default:
      return DatasetType.farmaciasRepes;
  }
}

ImportBatchStatus parseStatus(String? raw) {
  switch (raw) {
    case 'draft':
      return ImportBatchStatus.draft;
    case 'running':
      return ImportBatchStatus.running;
    case 'validated':
      return ImportBatchStatus.validated;
    case 'completed':
      return ImportBatchStatus.completed;
    case 'failed':
      return ImportBatchStatus.failed;
    case 'partial':
      return ImportBatchStatus.partial;
    case 'archived':
      return ImportBatchStatus.archived;
    case 'rolledBack':
      return ImportBatchStatus.rolledBack;
    case 'hidden':
      return ImportBatchStatus.hidden;
    default:
      return ImportBatchStatus.running;
  }
}

int _toInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double? _toDoubleOrNull(Object? value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

DateTime? _toDateTime(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
