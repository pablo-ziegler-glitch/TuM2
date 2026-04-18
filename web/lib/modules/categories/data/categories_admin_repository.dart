import 'package:cloud_functions/cloud_functions.dart';

class CategoryAdminItem {
  const CategoryAdminItem({
    required this.categoryId,
    required this.label,
    required this.iconName,
    required this.aliases,
    required this.isActive,
    required this.productLimit,
    required this.updatedAtMillis,
  });

  final String categoryId;
  final String label;
  final String iconName;
  final List<String> aliases;
  final bool isActive;
  final int? productLimit;
  final int? updatedAtMillis;

  factory CategoryAdminItem.fromMap(Map<String, dynamic> map) {
    return CategoryAdminItem(
      categoryId: (map['categoryId'] as String? ?? '').trim().toLowerCase(),
      label: (map['label'] as String? ?? '').trim(),
      iconName: (map['iconName'] as String? ?? 'store').trim().toLowerCase(),
      aliases: ((map['aliases'] as List?) ?? const <dynamic>[])
          .whereType<String>()
          .map((value) => value.trim().toLowerCase())
          .where((value) => value.isNotEmpty)
          .toList(growable: false),
      isActive: map['isActive'] != false,
      productLimit: map['productLimit'] is int ? map['productLimit'] as int : null,
      updatedAtMillis:
          map['updatedAtMillis'] is int ? map['updatedAtMillis'] as int : null,
    );
  }
}

class CategoryAdminPage {
  const CategoryAdminPage({
    required this.items,
    required this.nextCursor,
  });

  final List<CategoryAdminItem> items;
  final String? nextCursor;
}

class UpsertCategoryInput {
  const UpsertCategoryInput({
    required this.categoryId,
    required this.label,
    required this.iconName,
    required this.aliases,
    required this.isActive,
  });

  final String categoryId;
  final String label;
  final String iconName;
  final List<String> aliases;
  final bool isActive;
}

class CategoriesAdminRepository {
  CategoriesAdminRepository({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<CategoryAdminPage> list({
    required int limit,
    String? cursor,
    bool includeInactive = true,
  }) async {
    final response = await _functions.httpsCallable('listAdminCategories').call(
      <String, dynamic>{
        'limit': limit,
        'cursor': cursor,
        'includeInactive': includeInactive,
      },
    );
    final data = (response.data as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final rows = ((data['categories'] as List?) ?? const <dynamic>[])
        .whereType<Map>()
        .map((row) => CategoryAdminItem.fromMap(row.cast<String, dynamic>()))
        .toList(growable: false);
    final nextCursor = (data['nextCursor'] as String?)?.trim();
    return CategoryAdminPage(
      items: rows,
      nextCursor: nextCursor == null || nextCursor.isEmpty ? null : nextCursor,
    );
  }

  Future<CategoryAdminItem> upsert(UpsertCategoryInput input) async {
    final response = await _functions.httpsCallable('upsertAdminCategory').call(
      <String, dynamic>{
        'categoryId': input.categoryId,
        'label': input.label,
        'iconName': input.iconName,
        'aliases': input.aliases,
        'isActive': input.isActive,
      },
    );
    final data = (response.data as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final category =
        (data['category'] as Map?)?.cast<String, dynamic>() ?? const {};
    return CategoryAdminItem.fromMap(category);
  }

  Future<void> toggleActive({
    required String categoryId,
    required bool isActive,
  }) async {
    await _functions.httpsCallable('toggleAdminCategoryActive').call(
      <String, dynamic>{
        'categoryId': categoryId,
        'isActive': isActive,
      },
    );
  }
}
