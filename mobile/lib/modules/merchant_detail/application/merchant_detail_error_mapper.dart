import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

enum MerchantDetailErrorType {
  connection,
  generic,
}

MerchantDetailErrorType classifyMerchantDetailError(Object error) {
  if (error is TimeoutException || error is SocketException) {
    return MerchantDetailErrorType.connection;
  }

  if (error is FirebaseException) {
    final code = error.code.toLowerCase();
    if (code == 'unavailable' ||
        code == 'network-request-failed' ||
        code == 'deadline-exceeded') {
      return MerchantDetailErrorType.connection;
    }
  }

  return MerchantDetailErrorType.generic;
}
