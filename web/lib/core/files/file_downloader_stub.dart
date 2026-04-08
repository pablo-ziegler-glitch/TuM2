import 'dart:typed_data';

void downloadBytesFile({
  required String fileName,
  required Uint8List bytes,
  required String mimeType,
}) {
  throw UnsupportedError(
    'La descarga de archivos está disponible solo en Flutter Web.',
  );
}
