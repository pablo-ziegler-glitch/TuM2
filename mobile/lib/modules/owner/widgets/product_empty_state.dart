import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class ProductEmptyState extends StatelessWidget {
  const ProductEmptyState({
    super.key,
    required this.onAddPressed,
  });

  final VoidCallback onAddPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 210,
              height: 210,
              decoration: BoxDecoration(
                color: AppColors.neutral50,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 40,
                    offset: Offset(0, 18),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Expanded(
                    flex: 4,
                    child: Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: AppColors.neutral100,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      alignment: Alignment.bottomLeft,
                      padding: const EdgeInsets.all(14),
                      child: Container(
                        width: 74,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.neutral300,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 6,
                    child: Container(
                      width: double.infinity,
                      color: AppColors.surface,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.inventory_2_outlined,
                        color: AppColors.neutral400,
                        size: 66,
                      ),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    height: 24,
                    color: AppColors.neutral50,
                  ),
                ],
              ),
            ),
            Positioned(
              top: -8,
              right: -8,
              child: Transform.rotate(
                angle: 0.3,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.tertiary100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.add,
                    color: AppColors.tertiary700,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'Todavía no cargaste productos',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 34,
            height: 1.05,
            letterSpacing: -0.6,
            fontWeight: FontWeight.w800,
            color: AppColors.neutral900,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Agregá algunos productos para que los Vecinos sepan qué pueden encontrar en tu Comercio.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMd.copyWith(
            color: AppColors.neutral700,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 18),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0044AA), Color(0xFF0E5BD8)],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33004CAA),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            onPressed: onAddPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              elevation: 0,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
            icon: const Icon(Icons.add_circle_outline),
            label: Text(
              'Agregar primer producto',
              style: AppTextStyles.labelMd.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.neutral100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.lightbulb_outline,
                  color: AppColors.primary500,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Podés empezar solo con el nombre. La foto y el precio pueden ir después.',
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.neutral700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
