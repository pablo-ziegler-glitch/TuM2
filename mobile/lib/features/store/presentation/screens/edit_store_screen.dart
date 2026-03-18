import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/store_providers.dart';

class EditStoreScreen extends ConsumerStatefulWidget {
  final String storeId;

  const EditStoreScreen({super.key, required this.storeId});

  @override
  ConsumerState<EditStoreScreen> createState() => _EditStoreScreenState();
}

class _EditStoreScreenState extends ConsumerState<EditStoreScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  String? _selectedCategory;
  bool _isLoading = false;
  bool _initialized = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await ref.read(storeRepositoryProvider).updateStore(widget.storeId, {
        'name': _nameController.text.trim(),
        'category': _selectedCategory,
        'description': _descriptionController.text.trim(),
        'address': _addressController.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cambios guardados')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No se pudieron guardar los cambios'),
          backgroundColor: TuM2Colors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final storeAsync = ref.watch(storeDetailProvider(widget.storeId));

    return storeAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Error: $e')),
      ),
      data: (store) {
        if (store == null) {
          return const Scaffold(
            body: Center(child: Text('Comercio no encontrado')),
          );
        }

        // Initialize form fields once
        if (!_initialized) {
          _nameController.text = store.name;
          _descriptionController.text = store.description;
          _addressController.text = store.address;
          _selectedCategory = store.category;
          _initialized = true;
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Editar comercio'),
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
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration:
                        const InputDecoration(labelText: 'Nombre del comercio'),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Campo requerido' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(labelText: 'Rubro'),
                    items: AppConstants.storeCategories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _selectedCategory = v),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 3,
                    maxLength: AppConstants.maxStoreDescriptionLength,
                    decoration: const InputDecoration(
                      labelText: 'Descripción',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(labelText: 'Dirección'),
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
                        : const Text('Guardar cambios'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
