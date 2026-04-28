import 'package:cloud_firestore/cloud_firestore.dart';

const _kMvpCategoryIds = <String>{
  'farmacia',
  'kiosco',
  'almacen',
  'veterinaria',
  'comida_al_paso',
  'casa_de_comidas',
  'gomeria',
  'panaderia',
  'confiteria',
};

const _kMvpCategoryCandidateDocIds = <String>[
  'farmacia',
  'kiosco',
  'almacen',
  'veterinaria',
  'comida_al_paso',
  'casa_de_comidas',
  'gomeria',
  'panaderia',
  'confiteria',
];

const _kMvpCategoryOrder = <String, int>{
  'farmacia': 0,
  'kiosco': 1,
  'almacen': 2,
  'veterinaria': 3,
  'comida_al_paso': 4,
  'casa_de_comidas': 5,
  'gomeria': 6,
  'panaderia': 7,
  'confiteria': 8,
};

String canonicalCategoryId(String rawId) {
  final normalized = rawId.trim().toLowerCase();
  if (normalized == 'panaderías') return 'panaderia';
  if (normalized == 'panaderias') return 'panaderia';
  if (normalized == 'confiterías') return 'confiteria';
  if (normalized == 'confiterias') return 'confiteria';
  if (normalized == 'rotiserías') return 'casa_de_comidas';
  if (normalized == 'rotiserias') return 'casa_de_comidas';
  if (normalized == 'gomerías') return 'gomeria';
  if (normalized == 'gomerias') return 'gomeria';
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
      final scopedDocs = await _fetchScopedMvpDocs();
      if (scopedDocs.isEmpty) {
        _cache = _fallbackCategories;
        return _cache!;
      }
      final byId = <String, CategoryModel>{};
      for (final doc in scopedDocs) {
        final category = CategoryModel.fromMap(doc.id, doc.data());
        if (!_kMvpCategoryIds.contains(category.id)) continue;
        byId.putIfAbsent(category.id, () => category);
      }
      final normalized = byId.values.toList(growable: false)
        ..sort((left, right) {
          final leftOrder = _kMvpCategoryOrder[left.id] ?? 999;
          final rightOrder = _kMvpCategoryOrder[right.id] ?? 999;
          if (leftOrder != rightOrder) return leftOrder.compareTo(rightOrder);
          return left.label.toLowerCase().compareTo(right.label.toLowerCase());
        });
      _cache = normalized.isEmpty ? _fallbackCategories : normalized;
      return _cache!;
    } catch (_) {
      // Si Firestore no responde, usar fallback local
      _cache = _fallbackCategories;
      return _cache!;
    }
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _fetchScopedMvpDocs() async {
    final docsByPath = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    // Firestore limita whereIn a 10 valores; se divide en chunks para evitar
    // lecturas amplias de toda la colección.
    for (var i = 0; i < _kMvpCategoryCandidateDocIds.length; i += 10) {
      final end = (i + 10 < _kMvpCategoryCandidateDocIds.length)
          ? i + 10
          : _kMvpCategoryCandidateDocIds.length;
      final chunk = _kMvpCategoryCandidateDocIds.sublist(i, end);
      final snapshot = await _firestore
          .collection('categories')
          .where(FieldPath.documentId, whereIn: chunk)
          .limit(chunk.length)
          .get();
      for (final doc in snapshot.docs) {
        docsByPath[doc.reference.path] = doc;
      }
    }
    return docsByPath.values.toList(growable: false);
  }

  /// Invalida el caché (útil para tests o refresh forzado).
  static void clearCache() => _cache = null;

  static const List<CategoryModel> _fallbackCategories = [
    CategoryModel(
        id: 'farmacia', label: 'Farmacias', iconName: 'local_pharmacy'),
    CategoryModel(id: 'kiosco', label: 'Kioscos', iconName: 'storefront'),
    CategoryModel(
        id: 'almacen', label: 'Almacenes', iconName: 'shopping_basket'),
    CategoryModel(id: 'veterinaria', label: 'Veterinarias', iconName: 'pets'),
    CategoryModel(
      id: 'comida_al_paso',
      label: 'Comida al paso',
      iconName: 'fastfood',
    ),
    CategoryModel(
      id: 'casa_de_comidas',
      label: 'Rotiserías',
      iconName: 'restaurant',
    ),
    CategoryModel(id: 'gomeria', label: 'Gomerías', iconName: 'build'),
    CategoryModel(
      id: 'panaderia',
      label: 'Panaderías',
      iconName: 'bakery_dining',
    ),
    CategoryModel(
      id: 'confiteria',
      label: 'Confiterías',
      iconName: 'local_cafe',
    ),
  ];
}
