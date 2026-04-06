import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

class MerchantUserLocation {
  const MerchantUserLocation({
    required this.lat,
    required this.lng,
  });

  final double lat;
  final double lng;
}

abstract interface class MerchantLocationReader {
  Future<MerchantUserLocation?> getCurrentLocationIfPermitted();
}

class GeolocatorMerchantLocationReader implements MerchantLocationReader {
  static const Duration _timeout = Duration(seconds: 3);

  @override
  Future<MerchantUserLocation?> getCurrentLocationIfPermitted() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        // Importante: no pedir permiso en esta pantalla.
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: _timeout,
      );

      return MerchantUserLocation(
        lat: position.latitude,
        lng: position.longitude,
      );
    } catch (_) {
      return null;
    }
  }
}

final merchantLocationReaderProvider = Provider<MerchantLocationReader>(
  (ref) => GeolocatorMerchantLocationReader(),
);
