import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';

enum OutdatedInfoReportSubmitStatus {
  created,
  deduped,
}

class OutdatedInfoReportServiceException implements Exception {
  const OutdatedInfoReportServiceException({
    required this.code,
    required this.message,
  });

  final String code;
  final String message;
}

abstract interface class OutdatedInfoReportService {
  Future<OutdatedInfoReportSubmitStatus> submit({
    required String merchantId,
    required String zoneId,
    required String reasonCode,
    required String source,
    required String dateKey,
  });
}

class CallableOutdatedInfoReportService implements OutdatedInfoReportService {
  CallableOutdatedInfoReportService({
    FirebaseFunctions? functions,
  }) : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;
  static const Duration _timeout = Duration(seconds: 10);

  @override
  Future<OutdatedInfoReportSubmitStatus> submit({
    required String merchantId,
    required String zoneId,
    required String reasonCode,
    required String source,
    required String dateKey,
  }) async {
    try {
      final callable = _functions.httpsCallable('submitOutdatedInfoReport');
      final response = await callable.call({
        'merchantId': merchantId.trim(),
        'zoneId': zoneId.trim(),
        'reasonCode': reasonCode.trim(),
        'source': source.trim(),
        'dateKey': dateKey.trim(),
      }).timeout(_timeout);
      final data = (response.data as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};
      if (data['created'] == true) {
        return OutdatedInfoReportSubmitStatus.created;
      }
      if (data['deduped'] == true) {
        return OutdatedInfoReportSubmitStatus.deduped;
      }
      throw const OutdatedInfoReportServiceException(
        code: 'outdated-report-invalid-response',
        message: 'No pudimos registrar el reporte.',
      );
    } on FirebaseFunctionsException catch (error) {
      throw _mapFunctionsError(error);
    } on TimeoutException {
      throw const OutdatedInfoReportServiceException(
        code: 'outdated-report-timeout',
        message: 'La operación tardó más de lo esperado. Probá nuevamente.',
      );
    }
  }

  OutdatedInfoReportServiceException _mapFunctionsError(
    FirebaseFunctionsException error,
  ) {
    switch (error.code) {
      case 'resource-exhausted':
        return const OutdatedInfoReportServiceException(
          code: 'outdated-report-rate-limited',
          message: 'Ya recibimos varios reportes recientes. Probá en un rato.',
        );
      case 'invalid-argument':
        return const OutdatedInfoReportServiceException(
          code: 'outdated-report-invalid',
          message: 'No pudimos validar el reporte.',
        );
      case 'failed-precondition':
        return const OutdatedInfoReportServiceException(
          code: 'outdated-report-precondition',
          message: 'El comercio no está habilitado para este reporte.',
        );
      default:
        return OutdatedInfoReportServiceException(
          code: 'outdated-report-failed',
          message: error.message ?? 'No pudimos registrar el reporte.',
        );
    }
  }
}

class NoopOutdatedInfoReportService implements OutdatedInfoReportService {
  const NoopOutdatedInfoReportService();

  @override
  Future<OutdatedInfoReportSubmitStatus> submit({
    required String merchantId,
    required String zoneId,
    required String reasonCode,
    required String source,
    required String dateKey,
  }) async {
    return OutdatedInfoReportSubmitStatus.created;
  }
}
