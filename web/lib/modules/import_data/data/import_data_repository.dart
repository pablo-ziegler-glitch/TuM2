import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/import_batch_ui.dart';

class ParsedImportData {
  const ParsedImportData({
    required this.fileName,
    required this.fileSizeLabel,
    required this.fileHash,
    required this.headers,
    required this.rows,
    required this.suggestedMappings,
    required this.previewRows,
  });

  final String fileName;
  final String fileSizeLabel;
  final String fileHash;
  final List<String> headers;
  final List<Map<String, String>> rows;
  final List<FieldMapping> suggestedMappings;
  final List<CsvPreviewRow> previewRows;
}

class ZoneOption {
  const ZoneOption({
    required this.zoneId,
    required this.name,
    required this.cityId,
    required this.countryName,
    required this.provinceName,
    required this.localityName,
  });

  final String zoneId;
  final String name;
  final String cityId;
  final String countryName;
  final String provinceName;
  final String localityName;

  String get label {
    final locality = localityName.trim().isEmpty ? name : localityName;
    final province = provinceName.trim();
    return province.isEmpty ? locality : '$locality — $province';
  }
}

class ImportValidationResult {
  const ImportValidationResult({
    required this.validRows,
    required this.warningRows,
    required this.errorRows,
    required this.errors,
  });

  final int validRows;
  final int warningRows;
  final int errorRows;
  final List<ImportRowError> errors;
}

class ImportSubmissionInput {
  const ImportSubmissionInput({
    required this.importType,
    required this.datasetType,
    required this.zoneId,
    required this.zoneLabel,
    required this.templateName,
    required this.parsedData,
    required this.fieldMappings,
    required this.deduplicationEnabled,
    required this.visibilityAfterImport,
  });

  final ImportType importType;
  final DatasetType datasetType;
  final String zoneId;
  final String zoneLabel;
  final String? templateName;
  final ParsedImportData parsedData;
  final List<FieldMapping> fieldMappings;
  final bool deduplicationEnabled;
  final String visibilityAfterImport;
}

class ImportDataRepository {
  static const List<String> _zoneCollectionCandidates = <String>[
    'zones',
  ];
  static const Set<String> _inactiveZoneStatuses = <String>{
    'draft',
    'internal_test',
    'paused',
    'borrador',
    'pausado',
    'pausada',
  };

  ImportDataRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _batches =>
      _firestore.collection('import_batches');

  CollectionReference<Map<String, dynamic>> get _externalPlaces =>
      _firestore.collection('external_places');

  Stream<List<ImportBatchUi>> watchBatches() {
    return _batches.orderBy('createdAt', descending: true).snapshots().map(
        (snapshot) => snapshot.docs
            .map((doc) => ImportBatchUi.fromDoc(doc.id, doc.data()))
            .toList());
  }

  Stream<ImportBatchUi?> watchBatch(String batchId) {
    return _batches.doc(batchId).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (data == null) return null;
      return ImportBatchUi.fromDoc(snapshot.id, data);
    });
  }

  Future<List<ZoneOption>> fetchAvailableZones() async {
    final docs = await _fetchActiveZoneDocs();
    return docs.map((doc) {
      final data = doc.data();
      final localityName = _readText(data, const [
            'localityName',
            'cityName',
            'name',
            'nombre',
          ]) ??
          doc.id;
      return ZoneOption(
        zoneId: doc.id,
        name: _readText(data, const ['name', 'nombre']) ?? localityName,
        cityId: _readText(data, const ['cityId', 'ciudadId', 'city_id']) ?? '',
        countryName:
            _readText(data, const ['countryName', 'paisNombre']) ?? 'Argentina',
        provinceName:
            _readText(data, const ['provinceName', 'provinciaNombre']) ?? '',
        localityName: localityName,
      );
    }).toList();
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _fetchActiveZoneDocs() async {
    for (final collectionName in _zoneCollectionCandidates) {
      final snapshot = await _firestore.collection(collectionName).get();
      final docs = snapshot.docs.where(_isActiveZoneDoc).toList();
      if (docs.isEmpty) continue;
      docs.sort(_compareZoneDocs);
      return docs;
    }
    return <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  }

  static bool _isActiveZoneDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final status =
        _readText(data, const ['status', 'estado'])?.toLowerCase().trim();
    if (status == null || status.isEmpty) return true;
    return !_inactiveZoneStatuses.contains(status);
  }

  static int _compareZoneDocs(
    QueryDocumentSnapshot<Map<String, dynamic>> a,
    QueryDocumentSnapshot<Map<String, dynamic>> b,
  ) {
    final priorityCompare =
        _zonePriority(a.data()).compareTo(_zonePriority(b.data()));
    if (priorityCompare != 0) return priorityCompare;
    final nameCompare = (_readText(a.data(), const ['name', 'nombre']) ?? a.id)
        .toLowerCase()
        .compareTo(
          (_readText(b.data(), const ['name', 'nombre']) ?? b.id).toLowerCase(),
        );
    if (nameCompare != 0) return nameCompare;
    return a.id.compareTo(b.id);
  }

  static int _zonePriority(Map<String, dynamic> data) {
    final rawPriority =
        data['priorityLevel'] ?? data['priority'] ?? data['prioridad'];
    return rawPriority is num ? rawPriority.toInt() : 1 << 30;
  }

  static String? _readText(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  Future<void> publishBatch(ImportBatchUi batch) async {
    final placeDocs =
        await _externalPlaces.where('importBatchId', isEqualTo: batch.id).get();
    await _applyInChunks(placeDocs.docs, (writeBatch, doc) {
      writeBatch.update(doc.reference, {
        'visibilityStatus': 'visible',
        'publishedAt': FieldValue.serverTimestamp(),
      });
    });

    await _batches.doc(batch.id).set({
      'status': ImportBatchStatus.completed.name,
      'visibilityAfterImport': 'visible',
      'finishedAt': FieldValue.serverTimestamp(),
      'auditTrail': FieldValue.arrayUnion([
        AuditTimelineEvent(
          stage: 'publish',
          label: 'Batch Published',
          timestamp: DateTime.now(),
          actor: _auth.currentUser?.email ?? _auth.currentUser?.uid ?? 'admin',
          result: true,
          detail: '${placeDocs.size} records visible',
        ).toMap(),
      ]),
    }, SetOptions(merge: true));
  }

  Future<void> revertBatch(ImportBatchUi batch) async {
    final placeDocs =
        await _externalPlaces.where('importBatchId', isEqualTo: batch.id).get();

    final merchantUpdates =
        <DocumentReference<Map<String, dynamic>>, Map<String, Object?>>{};
    for (final placeDoc in placeDocs.docs) {
      final placeData = placeDoc.data();
      final linkedMerchantId = placeData['linkedMerchantId']?.toString();
      if (linkedMerchantId == null || linkedMerchantId.isEmpty) {
        continue;
      }

      final merchantRef =
          _firestore.collection('merchants').doc(linkedMerchantId);
      final merchantSnap = await merchantRef.get();
      if (!merchantSnap.exists) continue;
      final merchantData = merchantSnap.data() ?? const <String, dynamic>{};
      final sourceType = merchantData['sourceType']?.toString();
      final externalPlaceId = merchantData['externalPlaceId']?.toString();

      // Solo suprimimos comercios sembrados por external seed vinculados al place del batch.
      if (sourceType == 'external_seed' && externalPlaceId == placeDoc.id) {
        merchantUpdates[merchantRef] = {
          'visibilityStatus': 'suppressed',
          'rollbackBatchId': batch.id,
          'rollbackAt': FieldValue.serverTimestamp(),
        };
      }
    }

    if (merchantUpdates.isNotEmpty) {
      await _applyMapInChunks(merchantUpdates);
    }

    await _applyInChunks(placeDocs.docs, (writeBatch, doc) {
      writeBatch.update(doc.reference, {
        'rolledBack': true,
        'visibilityStatus': 'suppressed',
        'rolledBackAt': FieldValue.serverTimestamp(),
      });
    });

    await _batches.doc(batch.id).set({
      'status': ImportBatchStatus.rolledBack.name,
      'finishedAt': FieldValue.serverTimestamp(),
      'auditTrail': FieldValue.arrayUnion([
        AuditTimelineEvent(
          stage: 'rollback',
          label: 'Batch Reverted',
          timestamp: DateTime.now(),
          actor: _auth.currentUser?.email ?? _auth.currentUser?.uid ?? 'admin',
          result: true,
          detail:
              '${placeDocs.size} external_places suppressed · ${merchantUpdates.length} merchants suppressed',
        ).toMap(),
      ]),
    }, SetOptions(merge: true));
  }

  Future<String> submitImport(ImportSubmissionInput input) async {
    final actor = _auth.currentUser;
    if (actor == null) {
      throw StateError(
          'Debes iniciar sesión como admin para ejecutar importaciones.');
    }

    final validation = validateRows(
      rows: input.parsedData.rows,
      mappings: input.fieldMappings,
    );

    final batchRef = _batches.doc();
    final batchId = batchRef.id;
    final now = DateTime.now();
    final userDoc = await _firestore.collection('users').doc(actor.uid).get();
    final actorRole = userDoc.data()?['role']?.toString();
    final createdBy = actor.email ?? actor.uid;
    final batchNumber = now.millisecondsSinceEpoch;

    final baseTrail = [
      AuditTimelineEvent(
        stage: 'upload',
        label: 'File Uploaded',
        timestamp: now,
        actor: createdBy,
        result: true,
        detail:
            '${input.parsedData.fileName} · ${input.parsedData.fileSizeLabel}',
      ),
      AuditTimelineEvent(
        stage: 'parse',
        label: 'File Parsed',
        timestamp: now,
        actor: 'system',
        result: true,
        detail:
            '${input.parsedData.rows.length} rows · ${input.parsedData.headers.length} columns detected',
      ),
      AuditTimelineEvent(
        stage: 'map',
        label: 'Fields Mapped',
        timestamp: now,
        actor: createdBy,
        result: true,
        detail:
            '${input.fieldMappings.where((m) => m.enabled).length} fields mapped',
      ),
      AuditTimelineEvent(
        stage: 'validate',
        label: 'Validation Complete',
        timestamp: now,
        actor: 'system',
        result: true,
        detail:
            '${validation.validRows} valid · ${validation.warningRows} warnings · ${validation.errorRows} errors',
      ),
    ];

    await batchRef.set({
      'batchId': batchId,
      'batchNumber': batchNumber,
      'importType': input.importType.name,
      'datasetType': input.datasetType.name,
      'zone': input.zoneLabel,
      'zoneId': input.zoneId,
      'zoneLabel': input.zoneLabel,
      'status': ImportBatchStatus.draft.name,
      'processedCount': input.parsedData.rows.length,
      'createdCount': 0,
      'duplicatedCount': 0,
      'errorCount': validation.errorRows,
      'pendingReviewCount': 0,
      'validRows': validation.validRows,
      'warningRows': validation.warningRows,
      'stagingCount': 0,
      'mergeCandidateCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': createdBy,
      'actorRole': actorRole,
      'templateName': input.templateName,
      'deduplicationEnabled': input.deduplicationEnabled,
      'visibilityAfterImport': input.visibilityAfterImport,
      'fileName': input.parsedData.fileName,
      'fileSize': input.parsedData.fileSizeLabel,
      'fileHash': input.parsedData.fileHash,
      'fieldMappings': input.fieldMappings.map((item) => item.toMap()).toList(),
      'errors': validation.errors.map((item) => item.toMap()).toList(),
      'auditTrail': [
        ...baseTrail.map((item) => item.toMap()),
        AuditTimelineEvent(
          stage: 'queue',
          label: 'Import Queued',
          timestamp: now,
          actor: 'system',
          result: true,
          detail: 'Processing will continue in background',
        ).toMap(),
      ],
    });

    unawaited(_processBatchInBackground(
      batchRef: batchRef,
      batchId: batchId,
      input: input,
      validation: validation,
      createdBy: createdBy,
    ));

    return batchId;
  }

  Future<void> _processBatchInBackground({
    required DocumentReference<Map<String, dynamic>> batchRef,
    required String batchId,
    required ImportSubmissionInput input,
    required ImportValidationResult validation,
    required String createdBy,
  }) async {
    try {
      await batchRef.set({
        'status': ImportBatchStatus.running.name,
        'auditTrail': FieldValue.arrayUnion([
          AuditTimelineEvent(
            stage: 'process',
            label: 'Background Processing Started',
            timestamp: DateTime.now(),
            actor: 'system',
            result: true,
            detail: 'Preparing rows and staging records',
          ).toMap(),
        ]),
      }, SetOptions(merge: true));

      final enabledMappings =
          input.fieldMappings.where((m) => m.enabled).toList();
      final placeRefs =
          <DocumentReference<Map<String, dynamic>>, Map<String, dynamic>>{};
      var duplicatedCount = 0;
      var pendingReview = 0;

      for (var i = 0; i < input.parsedData.rows.length; i++) {
        final row = input.parsedData.rows[i];
        final state = _rowState(row, enabledMappings);
        if (state.$1) {
          continue;
        }

        final name = _mappedValue(row, enabledMappings, tum2FieldName);
        final address = _mappedValue(row, enabledMappings, tum2FieldAddress);
        final dedupeKey = _dedupeKey(name, address, input.zoneId);
        if (input.deduplicationEnabled) {
          final exists = await _externalPlaces
              .where('dedupeKey', isEqualTo: dedupeKey)
              .limit(1)
              .get();
          if (exists.docs.isNotEmpty) {
            duplicatedCount++;
            pendingReview++;
            continue;
          }
        }

        final lat = _doubleOrNull(
          _mappedValue(row, enabledMappings, tum2FieldLatitude),
        );
        final lng = _doubleOrNull(
          _mappedValue(row, enabledMappings, tum2FieldLongitude),
        );

        final docRef = _externalPlaces.doc();
        placeRefs[docRef] = {
          'externalId': docRef.id,
          'sourceType': 'admin_import',
          'rawName': name ?? 'Sin nombre',
          'rawCategory':
              _mappedValue(row, enabledMappings, tum2FieldCategory) ?? '',
          'rawAddress': address ?? '',
          'rawLat': lat,
          'rawLng': lng,
          'zoneId': input.zoneId,
          'zoneLabel': input.zoneLabel,
          'importBatchId': batchId,
          'dedupeKey': dedupeKey,
          'rawPayload': row,
          'visibilityStatus': input.visibilityAfterImport,
          'createdAt': FieldValue.serverTimestamp(),
        };
      }

      await _applyMapInChunks(placeRefs);

      final createdCount = placeRefs.length;
      final isHidden = input.visibilityAfterImport == 'hidden';
      final status = createdCount == 0
          ? ImportBatchStatus.failed
          : (validation.errorRows > 0 || duplicatedCount > 0)
              ? ImportBatchStatus.partial
              : (isHidden
                  ? ImportBatchStatus.hidden
                  : ImportBatchStatus.completed);

      await batchRef.set({
        'status': status.name,
        'createdCount': createdCount,
        'duplicatedCount': duplicatedCount,
        'pendingReviewCount': pendingReview,
        'stagingCount': createdCount,
        'mergeCandidateCount': duplicatedCount,
        'finishedAt': FieldValue.serverTimestamp(),
        'auditTrail': FieldValue.arrayUnion([
          AuditTimelineEvent(
            stage: 'stage',
            label: 'Staged to Firestore',
            timestamp: DateTime.now(),
            actor: 'system',
            result: true,
            detail:
                '$createdCount records staged (${input.visibilityAfterImport})',
          ).toMap(),
          AuditTimelineEvent(
            stage: 'confirm',
            label: 'Import Confirmed',
            timestamp: DateTime.now(),
            actor: createdBy,
            result: true,
            detail: 'Batch marked as ${status.name}',
          ).toMap(),
        ]),
      }, SetOptions(merge: true));
    } catch (error) {
      await batchRef.set({
        'status': ImportBatchStatus.failed.name,
        'finishedAt': FieldValue.serverTimestamp(),
        'auditTrail': FieldValue.arrayUnion([
          AuditTimelineEvent(
            stage: 'process',
            label: 'Background Processing Failed',
            timestamp: DateTime.now(),
            actor: 'system',
            result: false,
            detail: error.toString(),
          ).toMap(),
        ]),
      }, SetOptions(merge: true));
    }
  }

  Future<ParsedImportData> parseImportFile({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final lower = fileName.toLowerCase();
    final rows = switch (true) {
      _ when lower.endsWith('.csv') => _parseCsv(bytes),
      _ when lower.endsWith('.json') => _parseJson(bytes),
      _ => throw UnsupportedError(
          'Formato no soportado. Usá CSV o JSON para importar.',
        ),
    };

    if (rows.isEmpty) {
      throw StateError('El archivo no contiene filas de datos.');
    }

    final headers = rows.first.keys.toList();
    final mappings = _suggestMappings(rows, headers);
    final preview = _buildPreviewRows(rows, mappings).take(50).toList();
    final hash = sha256.convert(bytes).toString();

    return ParsedImportData(
      fileName: fileName,
      fileSizeLabel: _humanBytes(bytes.length),
      fileHash: hash,
      headers: headers,
      rows: rows,
      suggestedMappings: mappings,
      previewRows: preview,
    );
  }

  ImportValidationResult validateRows({
    required List<Map<String, String>> rows,
    required List<FieldMapping> mappings,
  }) {
    var validRows = 0;
    var warningRows = 0;
    var errorRows = 0;
    final errors = <ImportRowError>[];

    for (var i = 0; i < rows.length; i++) {
      final state =
          _rowState(rows[i], mappings.where((m) => m.enabled).toList());
      if (state.$1) {
        errorRows++;
        errors.add(
          ImportRowError(
            row: i + 2,
            establishmentName:
                _mappedValue(rows[i], mappings, tum2FieldName) ?? 'Sin nombre',
            reason: state.$3,
            severity: ImportIssueSeverity.error,
          ),
        );
      } else if (state.$2) {
        warningRows++;
      } else {
        validRows++;
      }
    }

    return ImportValidationResult(
      validRows: validRows,
      warningRows: warningRows,
      errorRows: errorRows,
      errors: errors,
    );
  }

  List<Map<String, String>> _parseCsv(Uint8List bytes) {
    final content = utf8.decode(bytes, allowMalformed: true);
    final rows = const CsvToListConverter(
      shouldParseNumbers: false,
      eol: '\n',
    ).convert(content);
    if (rows.isEmpty) return const [];

    final headers = rows.first
        .map((value) => value?.toString().trim() ?? '')
        .where((value) => value.isNotEmpty)
        .toList();
    if (headers.isEmpty) return const [];

    final output = <Map<String, String>>[];
    for (var i = 1; i < rows.length; i++) {
      final rowValues = rows[i];
      final mapped = <String, String>{};
      for (var col = 0; col < headers.length; col++) {
        final value = col < rowValues.length ? rowValues[col] : null;
        mapped[headers[col]] = value?.toString().trim() ?? '';
      }
      if (mapped.values.any((value) => value.isNotEmpty)) {
        output.add(mapped);
      }
    }
    return output;
  }

  List<Map<String, String>> _parseJson(Uint8List bytes) {
    final decoded = jsonDecode(utf8.decode(bytes, allowMalformed: true));
    if (decoded is! List) return const [];

    final rows = <Map<String, String>>[];
    for (final item in decoded) {
      if (item is! Map) continue;
      final row = <String, String>{};
      for (final entry in item.entries) {
        final key = entry.key.toString().trim();
        if (key.isEmpty) continue;
        row[key] = entry.value?.toString().trim() ?? '';
      }
      if (row.isNotEmpty) rows.add(row);
    }
    return rows;
  }

  List<FieldMapping> _suggestMappings(
    List<Map<String, String>> rows,
    List<String> headers,
  ) {
    return headers.map((header) {
      final normalized = header.toLowerCase();
      final suggested = _guessTum2Field(normalized);
      return FieldMapping(
        csvColumn: header,
        tum2Field: suggested ?? tum2FieldDescription,
        enabled: suggested != null,
        required: suggested == tum2FieldName || suggested == tum2FieldAddress,
        aiConfidence: _mappingConfidence(normalized, suggested),
        sampleValue: rows.first[header],
      );
    }).toList();
  }

  String? _guessTum2Field(String header) {
    if (_matchesAny(header,
        ['name', 'nombre', 'business', 'comercio', 'establecimiento'])) {
      return tum2FieldName;
    }
    if (_matchesAny(header, ['address', 'direccion', 'domicilio', 'calle'])) {
      return tum2FieldAddress;
    }
    if (_matchesAny(header, ['phone', 'telefono', 'tel', 'whatsapp'])) {
      return tum2FieldPhone;
    }
    if (_matchesAny(header, ['category', 'rubro', 'tipo', 'typology'])) {
      return tum2FieldCategory;
    }
    if (_matchesAny(header, ['lat', 'latitude', 'latitud'])) {
      return tum2FieldLatitude;
    }
    if (_matchesAny(header, ['lng', 'lon', 'longitude', 'longitud'])) {
      return tum2FieldLongitude;
    }
    if (_matchesAny(
        header, ['city', 'ciudad', 'locality', 'localidad', 'barrio'])) {
      return tum2FieldLocality;
    }
    if (_matchesAny(header, ['hours', 'horario', 'opening'])) {
      return tum2FieldHours;
    }
    if (_matchesAny(header, ['email', 'mail'])) {
      return tum2FieldEmail;
    }
    if (_matchesAny(header, ['web', 'website', 'site', 'url'])) {
      return tum2FieldWebsite;
    }
    return null;
  }

  List<CsvPreviewRow> _buildPreviewRows(
    List<Map<String, String>> rows,
    List<FieldMapping> mappings,
  ) {
    final enabledMappings = mappings.where((m) => m.enabled).toList();
    return rows.map((row) {
      final state = _rowState(row, enabledMappings);
      final isError = state.$1;
      final isWarning = !isError && state.$2;
      return CsvPreviewRow(
        name: _mappedValue(row, enabledMappings, tum2FieldName) ?? 'Sin nombre',
        locality: _mappedValue(row, enabledMappings, tum2FieldLocality) ?? '—',
        typology: _mappedValue(row, enabledMappings, tum2FieldCategory) ?? '—',
        address: _mappedValue(row, enabledMappings, tum2FieldAddress) ?? '—',
        longitude:
            _mappedValue(row, enabledMappings, tum2FieldLongitude) ?? '—',
        latitude: _mappedValue(row, enabledMappings, tum2FieldLatitude) ?? '—',
        state: isError ? '▲' : '●',
        hasError: isError,
        hasWarning: isWarning,
      );
    }).toList();
  }

  (bool hasError, bool hasWarning, String reason) _rowState(
    Map<String, String> row,
    List<FieldMapping> enabledMappings,
  ) {
    final name = _mappedValue(row, enabledMappings, tum2FieldName);
    final address = _mappedValue(row, enabledMappings, tum2FieldAddress);
    if ((name ?? '').trim().isEmpty) {
      return (true, false, 'Falta columna requerida: nombre del negocio');
    }
    if ((address ?? '').trim().isEmpty) {
      return (true, false, 'Falta columna requerida: dirección');
    }

    final latRaw = _mappedValue(row, enabledMappings, tum2FieldLatitude);
    final lngRaw = _mappedValue(row, enabledMappings, tum2FieldLongitude);
    final lat = _doubleOrNull(latRaw);
    final lng = _doubleOrNull(lngRaw);
    if (latRaw != null && latRaw.isNotEmpty && lat == null) {
      return (false, true, 'Latitud inválida');
    }
    if (lngRaw != null && lngRaw.isNotEmpty && lng == null) {
      return (false, true, 'Longitud inválida');
    }
    if (lat != null && (lat < -90 || lat > 90)) {
      return (false, true, 'Latitud fuera de rango');
    }
    if (lng != null && (lng < -180 || lng > 180)) {
      return (false, true, 'Longitud fuera de rango');
    }
    return (false, false, '');
  }

  String? _mappedValue(
    Map<String, String> row,
    List<FieldMapping> mappings,
    String targetField,
  ) {
    final mapping = mappings.firstWhere(
      (candidate) => candidate.enabled && candidate.tum2Field == targetField,
      orElse: () => const FieldMapping(
        csvColumn: '',
        tum2Field: '',
        enabled: false,
        required: false,
      ),
    );
    if (!mapping.enabled || mapping.csvColumn.isEmpty) return null;
    return row[mapping.csvColumn]?.trim();
  }

  Future<void> _applyMapInChunks(
    Map<DocumentReference<Map<String, dynamic>>, Map<String, Object?>> data,
  ) async {
    const maxOps = 450;
    final entries = data.entries.toList();
    for (var i = 0; i < entries.length; i += maxOps) {
      final end = (i + maxOps > entries.length) ? entries.length : i + maxOps;
      final slice = entries.sublist(i, end);
      final writeBatch = _firestore.batch();
      for (final item in slice) {
        writeBatch.set(item.key, item.value);
      }
      await writeBatch.commit();
    }
  }

  Future<void> _applyInChunks(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    void Function(
      WriteBatch writeBatch,
      QueryDocumentSnapshot<Map<String, dynamic>> doc,
    ) apply,
  ) async {
    const maxOps = 450;
    for (var i = 0; i < docs.length; i += maxOps) {
      final end = (i + maxOps > docs.length) ? docs.length : i + maxOps;
      final slice = docs.sublist(i, end);
      final writeBatch = _firestore.batch();
      for (final doc in slice) {
        apply(writeBatch, doc);
      }
      await writeBatch.commit();
    }
  }

  bool _matchesAny(String header, List<String> tokens) {
    return tokens.any((token) => header.contains(token));
  }

  double _mappingConfidence(String normalizedHeader, String? field) {
    if (field == null) return 0.15;
    if (normalizedHeader.contains(field.toLowerCase())) return 0.99;
    if (_matchesAny(normalizedHeader, ['name', 'address', 'lat', 'lon'])) {
      return 0.92;
    }
    return 0.78;
  }

  String _humanBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(2)} MB';
  }

  String _dedupeKey(String? name, String? address, String zoneId) {
    final normalizedName = (name ?? '').toLowerCase().trim();
    final normalizedAddress = (address ?? '').toLowerCase().trim();
    return '$zoneId|$normalizedName|$normalizedAddress';
  }

  double? _doubleOrNull(String? raw) {
    if (raw == null) return null;
    final normalized = raw.replaceAll(',', '.').trim();
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }
}
