import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';

import '../models/import_batch_ui.dart';

class ImportTemplateDefinition {
  const ImportTemplateDefinition({
    required this.filePrefix,
    required this.headers,
    required this.sampleRows,
  });

  final String filePrefix;
  final List<String> headers;
  final List<Map<String, String>> sampleRows;
}

class ImportTemplateService {
  static ImportTemplateDefinition build({
    required ImportType importType,
    DatasetType? datasetType,
  }) {
    switch (importType) {
      case ImportType.officialDataset:
        return _officialDatasetTemplate(datasetType);
      case ImportType.masterCatalog:
        return _masterCatalogTemplate();
      case ImportType.genericInternal:
        return _genericTemplate();
    }
  }

  static Uint8List buildCsvBytes(ImportTemplateDefinition definition) {
    final matrix = <List<dynamic>>[
      definition.headers,
      ...definition.sampleRows.map(
        (row) => definition.headers.map((header) => row[header] ?? '').toList(),
      ),
    ];
    final csvContent = const ListToCsvConverter().convert(matrix);
    final bom = Uint8List.fromList(const [0xEF, 0xBB, 0xBF]);
    final content = Uint8List.fromList(csvContent.codeUnits);
    return Uint8List.fromList([...bom, ...content]);
  }

  static Uint8List buildExcelBytes(ImportTemplateDefinition definition) {
    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet();
    if (defaultSheet != null && defaultSheet != 'Template') {
      excel.delete(defaultSheet);
    }
    final sheet = excel['Template'];

    for (var col = 0; col < definition.headers.length; col++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0))
          .value = TextCellValue(
        definition.headers[col],
      );
    }

    for (
      var rowIndex = 0;
      rowIndex < definition.sampleRows.length;
      rowIndex++
    ) {
      final rowData = definition.sampleRows[rowIndex];
      for (var col = 0; col < definition.headers.length; col++) {
        final header = definition.headers[col];
        final value = rowData[header] ?? '';
        sheet
            .cell(
              CellIndex.indexByColumnRow(
                columnIndex: col,
                rowIndex: rowIndex + 1,
              ),
            )
            .value = TextCellValue(
          value,
        );
      }
    }

    return Uint8List.fromList(excel.encode() ?? <int>[]);
  }

  static ImportTemplateDefinition _officialDatasetTemplate(
    DatasetType? datasetType,
  ) {
    final suffix = switch (datasetType) {
      DatasetType.farmaciasRepes => 'farmacias_repes',
      DatasetType.puntosWifi => 'puntos_wifi',
      DatasetType.clubesDeBarrio => 'clubes_barrio',
      DatasetType.mercadosMunicipales => 'mercados_municipales',
      DatasetType.custom => 'custom',
      null => 'official_dataset',
    };

    const headers = [
      'business_name',
      'full_address',
      'locality',
      'category',
      'phone_number',
      'latitude',
      'longitude',
      'opening_hours',
      'website',
      'email',
      'source_ref',
    ];

    final sampleRows = <Map<String, String>>[
      {
        'business_name': 'Farmacia del Sol',
        'full_address': 'Av. Colón 1200, Córdoba',
        'locality': 'Córdoba',
        'category': 'Farmacia',
        'phone_number': '+54 351 421-0000',
        'latitude': '-31.4135',
        'longitude': '-64.1811',
        'opening_hours': 'L-V 08:00-20:00',
        'website': 'https://farmaciadelsol.example',
        'email': 'info@farmaciadelsol.example',
        'source_ref': 'REPES-AR-0001',
      },
      {
        'business_name': 'Botica San Martín',
        'full_address': 'San Martín 245, Rosario',
        'locality': 'Rosario',
        'category': 'Farmacia',
        'phone_number': '+54 341 444-1234',
        'latitude': '-32.9442',
        'longitude': '-60.6505',
        'opening_hours': 'L-S 09:00-21:00',
        'website': 'https://boticasanmartin.example',
        'email': 'contacto@boticasanmartin.example',
        'source_ref': 'REPES-AR-0002',
      },
      {
        'business_name': 'Farmacia Central Norte',
        'full_address': '9 de Julio 875, Tucumán',
        'locality': 'Tucumán',
        'category': 'Farmacia',
        'phone_number': '+54 381 555-9876',
        'latitude': '-26.8241',
        'longitude': '-65.2226',
        'opening_hours': '24HS',
        'website': '',
        'email': '',
        'source_ref': 'REPES-AR-0003',
      },
    ];

    return ImportTemplateDefinition(
      filePrefix: 'tum2_template_$suffix',
      headers: headers,
      sampleRows: sampleRows,
    );
  }

  static ImportTemplateDefinition _masterCatalogTemplate() {
    const headers = [
      'product_name',
      'brand',
      'gtin',
      'category',
      'description',
      'price',
      'currency',
      'merchant_name',
      'merchant_address',
      'merchant_phone',
    ];
    const sampleRows = [
      {
        'product_name': 'Ibuprofeno 400mg x10',
        'brand': 'Genfar',
        'gtin': '7791234567890',
        'category': 'Medicamentos',
        'description': 'Analgésico antiinflamatorio',
        'price': '4500',
        'currency': 'ARS',
        'merchant_name': 'Farmacia del Sol',
        'merchant_address': 'Av. Colón 1200, Córdoba',
        'merchant_phone': '+54 351 421-0000',
      },
      {
        'product_name': 'Paracetamol 500mg x20',
        'brand': 'Bayer',
        'gtin': '7790987654321',
        'category': 'Medicamentos',
        'description': 'Analgésico y antipirético',
        'price': '3800',
        'currency': 'ARS',
        'merchant_name': 'Botica San Martín',
        'merchant_address': 'San Martín 245, Rosario',
        'merchant_phone': '+54 341 444-1234',
      },
    ];

    return const ImportTemplateDefinition(
      filePrefix: 'tum2_template_master_catalog',
      headers: headers,
      sampleRows: sampleRows,
    );
  }

  static ImportTemplateDefinition _genericTemplate() {
    const headers = [
      'name',
      'address',
      'locality',
      'category',
      'phone',
      'latitude',
      'longitude',
      'hours',
      'website',
      'email',
      'notes',
    ];
    const sampleRows = [
      {
        'name': 'Kiosco Central',
        'address': '9 de Julio 122, Tucumán',
        'locality': 'Tucumán',
        'category': 'Kiosco',
        'phone': '+54 381 401-9988',
        'latitude': '-26.8327',
        'longitude': '-65.2038',
        'hours': 'L-D 08:00-23:00',
        'website': '',
        'email': '',
        'notes': 'Atiende pagos con QR',
      },
      {
        'name': 'Panadería Del Barrio',
        'address': 'Belgrano 320, Córdoba',
        'locality': 'Córdoba',
        'category': 'Panadería',
        'phone': '+54 351 490-0011',
        'latitude': '-31.4169',
        'longitude': '-64.1833',
        'hours': 'L-S 07:00-20:00',
        'website': '',
        'email': 'hola@panaderiadelbarrio.example',
        'notes': 'Horno a leña',
      },
    ];

    return const ImportTemplateDefinition(
      filePrefix: 'tum2_template_generic_internal',
      headers: headers,
      sampleRows: sampleRows,
    );
  }
}
