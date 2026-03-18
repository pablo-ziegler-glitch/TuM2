/// Application-wide constants for TuM2
class AppConstants {
  AppConstants._();

  // App info
  static const String appName = 'TuM2';
  static const String appTagline = 'Tu metro cuadrado';

  // Firebase
  static const String defaultTimezone = 'America/Argentina/Buenos_Aires';

  // Geo
  static const int geohashPrecision = 7;
  static const double defaultSearchRadiusMeters = 5000; // 5km
  static const double defaultMapZoom = 14.0;

  // Ranks
  static const Map<String, int> rankThresholds = {
    'Radar': 5000,
    'Conector': 1500,
    'Referente': 500,
    'Explorador': 100,
    'Vecino': 0,
  };

  // XP
  static const int xpPerVote = 10;

  // Store categories
  static const List<String> storeCategories = [
    'Almacén',
    'Panadería',
    'Farmacia',
    'Kiosco',
    'Verdulería',
    'Carnicería',
    'Ferretería',
    'Librería',
    'Peluquería',
    'Veterinaria',
    'Indumentaria',
    'Zapatería',
    'Electrónica',
    'Óptica',
    'Gimnasio',
    'Restaurante',
    'Bar / Cafetería',
    'Parrilla',
    'Pizzería',
    'Heladería',
    'Perfumería',
    'Locutorio',
    'Lavandería',
    'Cerrajería',
    'Otro',
  ];

  // Validation
  static const int minPasswordLength = 6;
  static const int maxStoreDescriptionLength = 500;
  static const int maxProductDescriptionLength = 300;
  static const int maxProposalDescriptionLength = 1000;

  // Pagination
  static const int storesPerPage = 20;
  static const int productsPerPage = 30;
  static const int proposalsPerPage = 15;

  // Image limits
  static const int maxStorageImageSizeMb = 5;
  static const int maxProductImages = 3;

  // Operational signal freshness threshold
  static const int freshnessThresholdHours = 72; // 3 days
}
