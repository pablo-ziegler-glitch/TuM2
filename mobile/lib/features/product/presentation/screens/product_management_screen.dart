import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/product_providers.dart';

class ProductManagementScreen extends ConsumerWidget {
  final String storeId;

  const ProductManagementScreen({super.key, required this.storeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(storeProductsProvider(storeId));

    return Scaffold(
      appBar: AppBar(title: const Text('Productos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            context.push('/tienda/$storeId/productos/nuevo'),
        icon: const Icon(Icons.add),
        label: const Text('Agregar'),
      ),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (products) {
          if (products.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.inventory_2_outlined,
                      size: 64, color: TuM2Colors.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text('Aún no cargaste productos',
                      style: TuM2TextStyles.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Agregá tus productos para que los clientes los vean.',
                    style: TuM2TextStyles.bodySmall
                        .copyWith(color: TuM2Colors.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: products.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) {
              final product = products[i];
              return ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: TuM2Colors.outline),
                ),
                leading: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: TuM2Colors.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.image_outlined,
                      color: TuM2Colors.onSurfaceVariant),
                ),
                title: Text(product.name, style: TuM2TextStyles.titleMedium),
                subtitle: Text(
                  '\$${product.price.toStringAsFixed(0)}',
                  style: TuM2TextStyles.bodySmall
                      .copyWith(color: TuM2Colors.primary),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => context.push(
                          '/tienda/$storeId/productos/${product.id}/editar'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: TuM2Colors.error),
                      onPressed: () => _confirmDelete(context, ref, product),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, WidgetRef ref, dynamic product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ocultar producto'),
        content: Text(
            '¿Querés ocultar "${product.name}"? No se borrará, solo dejará de verse.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: TuM2Colors.error),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(productRepositoryProvider)
                  .hideProduct(storeId, product.id);
            },
            child: const Text('Ocultar'),
          ),
        ],
      ),
    );
  }
}
