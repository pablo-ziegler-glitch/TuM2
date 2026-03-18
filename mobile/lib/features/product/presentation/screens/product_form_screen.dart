import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/product_model.dart';
import '../providers/product_providers.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  final String storeId;
  final String? productId; // null = create mode

  const ProductFormScreen(
      {super.key, required this.storeId, this.productId});

  @override
  ConsumerState<ProductFormScreen> createState() =>
      _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  StockStatus _stockStatus = StockStatus.available;
  bool _isLoading = false;

  bool get _isEditing => widget.productId != null;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final product = ProductModel(
        id: widget.productId ?? '',
        storeId: widget.storeId,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        price: double.tryParse(_priceController.text) ?? 0,
        stockStatus: _stockStatus,
        imageUrls: [],
        isVisible: true,
        updatedAt: DateTime.now(),
      );

      final repo = ref.read(productRepositoryProvider);

      if (_isEditing) {
        await repo.updateProduct(widget.storeId, widget.productId!, {
          'name': product.name,
          'description': product.description,
          'price': product.price,
          'stockStatus': _stockToString(_stockStatus),
        });
      } else {
        await repo.createProduct(product);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing
              ? 'Producto actualizado'
              : 'Producto agregado'),
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No se pudo guardar el producto'),
          backgroundColor: TuM2Colors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _stockToString(StockStatus status) {
    switch (status) {
      case StockStatus.available: return 'available';
      case StockStatus.low: return 'low';
      case StockStatus.out: return 'out';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar producto' : 'Nuevo producto'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _save,
            child: const Text('Guardar'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image placeholder
              Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: TuM2Colors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: TuM2Colors.outline),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_photo_alternate_outlined,
                        size: 40, color: TuM2Colors.onSurfaceVariant),
                    const SizedBox(height: 8),
                    Text('Agregar imagen',
                        style: TuM2TextStyles.bodySmall
                            .copyWith(color: TuM2Colors.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.sentences,
                decoration:
                    const InputDecoration(labelText: 'Nombre del producto'),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Campo requerido' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                maxLines: 2,
                maxLength: AppConstants.maxProductDescriptionLength,
                decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Precio',
                  prefixText: '\$ ',
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Ingresá el precio';
                  if (double.tryParse(v) == null) return 'Precio inválido';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              Text('Stock', style: TuM2TextStyles.titleMedium),
              const SizedBox(height: 8),
              SegmentedButton<StockStatus>(
                selected: {_stockStatus},
                onSelectionChanged: (set) =>
                    setState(() => _stockStatus = set.first),
                segments: const [
                  ButtonSegment(
                      value: StockStatus.available,
                      label: Text('Disponible')),
                  ButtonSegment(
                      value: StockStatus.low, label: Text('Poco stock')),
                  ButtonSegment(
                      value: StockStatus.out,
                      label: Text('Sin stock')),
                ],
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _save,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(_isEditing ? 'Guardar cambios' : 'Agregar producto'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
