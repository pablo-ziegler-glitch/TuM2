import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import '../constants/app_constants.dart';

/// Utility wrapper for geohash operations using geoflutterfire_plus
class GeohashUtils {
  GeohashUtils._();

  /// Encodes a lat/lng pair into a geohash string.
  static String encode(double lat, double lng) {
    return GeoFirePoint(GeoPoint(lat, lng))
        .geohash
        .substring(0, AppConstants.geohashPrecision);
  }

  /// Creates a GeoFirePoint for proximity queries.
  static GeoFirePoint toFirePoint(double lat, double lng) {
    return GeoFirePoint(GeoPoint(lat, lng));
  }
}

// Re-export for convenience
export 'package:cloud_firestore/cloud_firestore.dart' show GeoPoint;
