import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/merchant_product.dart';

Future<void> showProductActionsSheet(
  BuildContext context, {
  required MerchantProduct product,
  required VoidCallback onEdit,
  required VoidCallback onMarkOutOfStock,
  required VoidCallback onMarkAvailable,
  required VoidCallback onHide,
  required VoidCallback onReactivate,
  required VoidCallback onDelete,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    builder: (context) {
      final isInactive = product.status == ProductStatus.inactive;
      final isOutOfStock = product.stockStatus == ProductStockStatus.outOfStock;

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
                label: 'Editar producto',
                onTap: () {
                  Navigator.of(context).pop();
                  onEdit();
                },
              ),
              if (!isInactive)
                _ActionTile(
                  icon: isOutOfStock
                      ? Icons.check_circle_outline
                      : Icons.remove_circle_outline,
                  label: isOutOfStock
                      ? 'Marcar como disponible'
                      : 'Marcar como agotado',
                  onTap: () {
                    Navigator.of(context).pop();
                    if (isOutOfStock) {
                      onMarkAvailable();
                      return;
                    }
                    onMarkOutOfStock();
                  },
                ),
              _ActionTile(
                icon: isInactive
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                label: isInactive ? 'Volver a mostrar' : 'Ocultar de Tu zona',
                onTap: () {
                  Navigator.of(context).pop();
                  if (isInactive) {
                    onReactivate();
                    return;
                  }
                  onHide();
                },
              ),
              _ActionTile(
                icon: Icons.delete_outline,
                label: 'Eliminar producto',
                color: AppColors.errorFg,
                onTap: () {
                  Navigator.of(context).pop();
                  onDelete();
                },
              ),
              if (isInactive)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Ocultar lo saca de la vista de los Vecinos, pero podés volver a mostrarlo después.',
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
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        icon,
        color: color,
      ),
      title: Text(
        label,
        style: AppTextStyles.labelMd.copyWith(
          color: color,
        ),
      ),
      onTap: onTap,
    );
  }
}
