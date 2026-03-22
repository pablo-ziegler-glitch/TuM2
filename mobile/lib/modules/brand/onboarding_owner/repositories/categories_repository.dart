import 'package:cloud_firestore/cloud_firestore.dart';

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
      id: id,
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
      _cache = snap.docs
          .map((doc) => CategoryModel.fromMap(doc.id, doc.data()))
          .toList();
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
    CategoryModel(id: 'pharmacy', label: 'Farmacia', iconName: 'local_pharmacy'),
    CategoryModel(id: 'kiosk', label: 'Kiosco', iconName: 'storefront'),
    CategoryModel(id: 'grocery', label: 'Almacén', iconName: 'shopping_basket'),
    CategoryModel(id: 'vet', label: 'Veterinaria', iconName: 'pets'),
    CategoryModel(id: 'bakery', label: 'Panadería', iconName: 'bakery_dining'),
    CategoryModel(id: 'other', label: 'Otro', iconName: 'store'),
  ];
}
