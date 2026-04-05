import 'package:geolocator/geolocator.dart';

// ── Resultado de la solicitud de posición ─────────────────────────────────────

/// Resultado de intentar obtener la posición del usuario.
sealed class GeoPositionResult {}

/// La posición fue obtenida correctamente.
final class GeoPositionOk extends GeoPositionResult {
  final double lat;
  final double lng;
  GeoPositionOk({required this.lat, required this.lng});
}

/// El permiso fue denegado de forma temporal.
final class GeoPositionDenied extends GeoPositionResult {}

/// El permiso fue denegado permanentemente (requiere ir a ajustes del SO).
final class GeoPositionDeniedForever extends GeoPositionResult {}

/// GPS tardó demasiado (timeout) o no está disponible.
final class GeoPositionTimeout extends GeoPositionResult {}

/// Error inesperado al obtener la posición.
final class GeoPositionError extends GeoPositionResult {
  final String message;
  GeoPositionError(this.message);
}

// ── Servicio ──────────────────────────────────────────────────────────────────

/// Abstrae el acceso al GPS del dispositivo usando el paquete geolocator.
///
/// Permisos requeridos en plataformas nativas:
///   Android: ACCESS_FINE_LOCATION + ACCESS_COARSE_LOCATION en AndroidManifest.xml
///   iOS: NSLocationWhenInUseUsageDescription en Info.plist
class GeoLocationService {
  static const Duration _timeout = Duration(seconds: 8);

  /// Verifica el estado del permiso de ubicación sin pedirlo.
  Future<LocationPermission> checkPermission() {
    return Geolocator.checkPermission();
  }

  /// Solicita permiso de ubicación en contexto (debe llamarse desde un gesto del usuario).
  Future<LocationPermission> requestPermission() {
    return Geolocator.requestPermission();
  }

  /// Intenta obtener la posición actual del dispositivo.
  ///
  /// Flujo:
  /// 1. Verifica permiso actual.
  /// 2. Si no hay permiso → solicita al usuario.
  /// 3. Si el usuario deniega → retorna [GeoPositionDenied] o [GeoPositionDeniedForever].
  /// 4. Llama a [Geolocator.getCurrentPosition] con timeout de 8 segundos.
  /// 5. Si timeout → retorna [GeoPositionTimeout].
  Future<GeoPositionResult> getPosition() async {
    try {
      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        return GeoPositionDenied();
      }

      if (permission == LocationPermission.deniedForever) {
        return GeoPositionDeniedForever();
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: _timeout,
      );

      return GeoPositionOk(lat: position.latitude, lng: position.longitude);
    } on LocationServiceDisabledException {
      return GeoPositionDenied();
    } on TimeoutException {
      return GeoPositionTimeout();
    } catch (e) {
      return GeoPositionError(e.toString());
    }
  }
}

/// Exception interna para el timeout de posición.
class TimeoutException implements Exception {
  const TimeoutException();
}
