import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirebaseBootstrap {
  static const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const _messagingSenderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const _authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  static const _storageBucket =
      String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  static const _measurementId =
      String.fromEnvironment('FIREBASE_MEASUREMENT_ID');
  static const _useEmulators =
      String.fromEnvironment('USE_FIREBASE_EMULATORS', defaultValue: 'false');

  static Future<void> initialize() async {
    if (!kIsWeb) {
      await Firebase.initializeApp();
      return;
    }

    if (_apiKey.isEmpty ||
        _appId.isEmpty ||
        _messagingSenderId.isEmpty ||
        _projectId.isEmpty) {
      throw StateError(
        'Faltan variables Firebase para Web. '
        'Definí FIREBASE_API_KEY, FIREBASE_APP_ID, '
        'FIREBASE_MESSAGING_SENDER_ID y FIREBASE_PROJECT_ID.',
      );
    }

    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: _apiKey,
        appId: _appId,
        messagingSenderId: _messagingSenderId,
        projectId: _projectId,
        authDomain: _authDomain.isEmpty ? null : _authDomain,
        storageBucket: _storageBucket.isEmpty ? null : _storageBucket,
        measurementId: _measurementId.isEmpty ? null : _measurementId,
      ),
    );

    if (_useEmulators == 'true') {
      FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
      FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
    }
  }
}
