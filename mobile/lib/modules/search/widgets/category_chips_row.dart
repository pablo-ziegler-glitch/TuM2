import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class CategoryChipsRow extends StatelessWidget {
  const CategoryChipsRow({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelected,
  });

  final List<String> categories;
  final String? selectedCategoryId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final chips = ['Todos', ...categories];
    return SizedBox(
      height: 36,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final value = chips[i];
          final categoryId = value == 'Todos' ? null : value;
          final selected = selectedCategoryId == categoryId;
          return GestureDetector(
            onTap: () => onSelected(categoryId),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary500 : AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? AppColors.primary500 : AppColors.neutral300,
                ),
              ),
              child: Row(
                children: [
                  if (value != 'Todos') ...[
                    const Icon(Icons.sell_outlined, size: 14),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    value,
                    style: AppTextStyles.labelSm.copyWith(
                      color:
                          selected ? AppColors.surface : AppColors.neutral700,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
