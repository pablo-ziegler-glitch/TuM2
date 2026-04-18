import 'package:cloud_firestore/cloud_firestore.dart';

String canonicalCategoryId(String rawId) {
  final normalized = rawId.trim().toLowerCase();
  if (normalized == 'vet' || normalized == 'veterinary') return 'veterinaria';
  if (normalized == 'pharmacy') return 'farmacia';
  if (normalized == 'kiosk') return 'kiosco';
  if (normalized == 'grocery') return 'almacen';
  if (normalized == 'supermarket') return 'supermercado';
  if (normalized == 'prepared_food') return 'casa_de_comidas';
  if (normalized == 'fast_food') return 'comida_al_paso';
  if (normalized == 'tire_shop') return 'gomeria';
  if (normalized == 'bakery') return 'panaderia';
  if (normalized == 'other') return 'otro';
  return normalized;
}

/// Modelo de categoría para el step 1 del onboarding OWNER.
class CategoryModel {
  final String id;
  final String label;
  final String iconName;

  const CategoryModel({
    required this.id,
    required this.label,
    required this.iconName,
  });

  factory CategoryModel.fromMap(String id, Map<String, dynamic> map) {
    return CategoryModel(
      id: canonicalCategoryId(id),
      label: map['label'] as String? ?? id,
      iconName: map['iconName'] as String? ?? 'store',
    );
  }
}

/// SL-03 — CategoriesRepository
///
/// Lee la colección `categories` de Firestore.
/// Cachea el resultado en memoria durante la sesión (las categorías no cambian frecuentemente).
/// Si Firestore no responde, retorna las categorías por defecto hardcodeadas.
class CategoriesRepository {
  final FirebaseFirestore _firestore;

  // Caché en memoria (una sola instancia por sesión)
  static List<CategoryModel>? _cache;

  CategoriesRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Retorna la lista de categorías. Usa caché en memoria si ya fueron cargadas.
  Future<List<CategoryModel>> getCategories() async {
    if (_cache != null) return _cache!;

    try {
      final snap = await _firestore.collection('categories').get();
      if (snap.docs.isEmpty) {
        _cache = _fallbackCategories;
        return _cache!;
      }
      final byId = <String, CategoryModel>{};
      for (final doc in snap.docs) {
        final category = CategoryModel.fromMap(doc.id, doc.data());
        byId.putIfAbsent(category.id, () => category);
      }
      _cache = byId.values.toList(growable: false);
      return _cache!;
    } catch (_) {
      // Si Firestore no responde, usar fallback local
      _cache = _fallbackCategories;
      return _cache!;
    }
  }

  /// Invalida el caché (útil para tests o refresh forzado).
  static void clearCache() => _cache = null;

  static const List<CategoryModel> _fallbackCategories = [
    CategoryModel(
        id: 'farmacia', label: 'Farmacia', iconName: 'local_pharmacy'),
    CategoryModel(id: 'kiosco', label: 'Kiosco', iconName: 'storefront'),
    CategoryModel(id: 'almacen', label: 'Almacén', iconName: 'shopping_basket'),
    CategoryModel(id: 'veterinaria', label: 'Veterinaria', iconName: 'pets'),
    CategoryModel(id: 'panaderia', label: 'Panadería', iconName: 'bakery_dining'),
    CategoryModel(id: 'otro', label: 'Otro', iconName: 'store'),
  ];
}
