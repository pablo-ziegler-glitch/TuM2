import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';

class CategoryOption {
  final String id;
  final String label;
  final IconData icon;

  const CategoryOption(
      {required this.id, required this.label, required this.icon});
}

const kCategories = [
  CategoryOption(
      id: 'farmacia', label: 'Farmacias', icon: Icons.local_pharmacy_outlined),
  CategoryOption(id: 'kiosco', label: 'Kioscos', icon: Icons.store_outlined),
  CategoryOption(
      id: 'almacen', label: 'Almacenes', icon: Icons.shopping_basket_outlined),
  CategoryOption(
      id: 'veterinaria', label: 'Veterinarias', icon: Icons.pets_outlined),
  CategoryOption(
      id: 'comida_al_paso',
      label: 'Comida al paso',
      icon: Icons.fastfood_outlined),
  CategoryOption(
      id: 'casa_de_comidas',
      label: 'Rotiserías',
      icon: Icons.restaurant_outlined),
  CategoryOption(id: 'gomeria', label: 'Gomerías', icon: Icons.build_outlined),
  CategoryOption(
      id: 'panaderia', label: 'Panaderías', icon: Icons.bakery_dining_outlined),
  CategoryOption(
      id: 'confiteria', label: 'Confiterías', icon: Icons.local_cafe_outlined),
];

class CategoryGrid extends StatelessWidget {
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final bool hasError;

  /// Si se provee, usa estas categorías en lugar de [kCategories].
  final List<CategoryOption>? categories;

  const CategoryGrid({
    super.key,
    required this.selectedId,
    required this.onSelect,
    this.hasError = false,
    this.categories,
  });

  @override
  Widget build(BuildContext context) {
    final items = categories ?? kCategories;
    return Container(
      decoration: hasError
          ? BoxDecoration(
              border: Border.all(color: AppColors.errorFg),
              borderRadius: BorderRadius.circular(8),
            )
          : null,
      padding: hasError ? const EdgeInsets.all(8) : EdgeInsets.zero,
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.1,
        children: items.map((cat) {
          final isSelected = cat.id == selectedId;
          return _CategoryChip(
            option: cat,
            isSelected: isSelected,
            onTap: () => onSelect(cat.id),
          );
        }).toList(),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final CategoryOption option;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary50 : AppColors.surface,
          border: Border.all(
            color: isSelected ? AppColors.primary500 : AppColors.neutral200,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              option.icon,
              size: 22,
              color: isSelected ? AppColors.primary500 : AppColors.neutral600,
            ),
            const SizedBox(height: 4),
            Text(
              option.label,
              style: AppTextStyles.bodyXs.copyWith(
                color: isSelected ? AppColors.primary500 : AppColors.neutral800,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
