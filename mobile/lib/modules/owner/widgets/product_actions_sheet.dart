import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/merchant_product.dart';

Future<void> showProductActionsSheet(
  BuildContext context, {
  required MerchantProduct product,
  required VoidCallback onEdit,
  required VoidCallback onToggleVisibility,
  required VoidCallback onDeactivate,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    builder: (context) {
      final hideOrShowLabel =
          product.visibilityStatus == ProductVisibilityStatus.visible
              ? 'Ocultar'
              : 'Mostrar';
      final isInactive = product.status == ProductStatus.inactive;

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.headingSm,
              ),
              const SizedBox(height: 10),
              _ActionTile(
                icon: Icons.edit_outlined,
                label: 'Editar',
                onTap: () {
                  Navigator.of(context).pop();
                  onEdit();
                },
              ),
              _ActionTile(
                icon:
                    product.visibilityStatus == ProductVisibilityStatus.visible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                label: hideOrShowLabel,
                enabled: !isInactive,
                onTap: () {
                  Navigator.of(context).pop();
                  onToggleVisibility();
                },
              ),
              _ActionTile(
                icon: Icons.delete_outline,
                label: 'Dar de baja',
                color: AppColors.errorFg,
                enabled: !isInactive,
                onTap: () {
                  Navigator.of(context).pop();
                  onDeactivate();
                },
              ),
              if (isInactive)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Este producto ya está inactivo.',
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.neutral600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppColors.neutral900,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        icon,
        color: enabled ? color : AppColors.neutral400,
      ),
      title: Text(
        label,
        style: AppTextStyles.labelMd.copyWith(
          color: enabled ? color : AppColors.neutral500,
        ),
      ),
      onTap: enabled ? onTap : null,
    );
  }
}
