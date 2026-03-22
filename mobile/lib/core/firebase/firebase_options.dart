// ignore_for_file: lines_longer_than_80_chars, avoid_classes_with_only_static_members
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Opciones de Firebase por plataforma y ambiente.
///
/// Este archivo es un stub que debe ser reemplazado por la salida real de
/// `flutterfire configure` una vez que los GoogleService-Info.plist y
/// google-services.json estén disponibles para cada ambiente (dev/staging/prod).
///
/// Para dev local con emuladores, los valores reales no son necesarios
/// — los emuladores no validan las opciones. Solo se requiere el projectId.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions no está configurado para esta plataforma. '
          'Ejecutá flutterfire configure para generar las opciones correctas.',
        );
    }
  }

  // Proyecto: tum2-dev (ambiente de desarrollo)
  // Reemplazar con la salida real de `flutterfire configure --project=tum2-dev`

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'PLACEHOLDER_API_KEY',
    appId: '1:000000000000:web:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'tum2-dev',
    authDomain: 'tum2-dev.firebaseapp.com',
    storageBucket: 'tum2-dev.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'PLACEHOLDER_API_KEY',
    appId: '1:000000000000:android:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'tum2-dev',
    storageBucket: 'tum2-dev.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'PLACEHOLDER_API_KEY',
    appId: '1:000000000000:ios:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'tum2-dev',
    storageBucket: 'tum2-dev.appspot.com',
    iosClientId: 'PLACEHOLDER_IOS_CLIENT_ID',
    iosBundleId: 'com.tum2.app',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'PLACEHOLDER_API_KEY',
    appId: '1:000000000000:ios:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'tum2-dev',
    storageBucket: 'tum2-dev.appspot.com',
    iosClientId: 'PLACEHOLDER_IOS_CLIENT_ID',
    iosBundleId: 'com.tum2.app',
  );
}
