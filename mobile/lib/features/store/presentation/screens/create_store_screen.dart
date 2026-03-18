import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/store_providers.dart';

class CreateStoreScreen extends ConsumerStatefulWidget {
  const CreateStoreScreen({super.key});

  @override
  ConsumerState<CreateStoreScreen> createState() => _CreateStoreScreenState();
}

class _CreateStoreScreenState extends ConsumerState<CreateStoreScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  // Form controllers
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _neighborhoodController = TextEditingController();
  final _localityController = TextEditingController();
  String? _selectedCategory;

  final _formKey1 = GlobalKey<FormState>();

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _neighborhoodController.dispose();
    _localityController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage == 0 && !_formKey1.currentState!.validate()) return;

    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _submit() async {
    final notifier = ref.read(storeFormNotifierProvider.notifier);
    notifier.update((s) => s.copyWith(
          name: _nameController.text.trim(),
          category: _selectedCategory ?? '',
          description: _descriptionController.text.trim(),
          address: _addressController.text.trim(),
          neighborhood: _neighborhoodController.text.trim(),
          locality: _localityController.text.trim(),
        ));

    final storeId = await notifier.submit();

    if (!mounted) return;
    if (storeId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comercio creado con éxito')),
      );
      context.go('/tienda/$storeId/panel');
    }
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(storeFormNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi comercio'),
        leading: _currentPage > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
              )
            : null,
      ),
      body: Column(
        children: [
          // Step indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              children: List.generate(3, (index) {
                return Expanded(
                  child: Container(
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: index <= _currentPage
                          ? TuM2Colors.primary
                          : TuM2Colors.outline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (p) => setState(() => _currentPage = p),
              children: [
                // Page 1: Basic info
                _BasicInfoPage(
                  formKey: _formKey1,
                  nameController: _nameController,
                  descriptionController: _descriptionController,
                  selectedCategory: _selectedCategory,
                  onCategoryChanged: (v) =>
                      setState(() => _selectedCategory = v),
                ),
                // Page 2: Location
                _LocationPage(
                  addressController: _addressController,
                  neighborhoodController: _neighborhoodController,
                  localityController: _localityController,
                ),
                // Page 3: Review & submit
                _ReviewPage(
                  name: _nameController.text,
                  category: _selectedCategory ?? '',
                  address: _addressController.text,
                  isLoading: formState.isLoading,
                  error: formState.error,
                  onSubmit: _submit,
                ),
              ],
            ),
          ),
          // Bottom button
          if (_currentPage < 2)
            Padding(
              padding: const EdgeInsets.all(24),
              child: ElevatedButton(
                onPressed: _nextPage,
                child: const Text('Continuar'),
              ),
            ),
        ],
      ),
    );
  }
}

class _BasicInfoPage extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final String? selectedCategory;
  final ValueChanged<String?> onCategoryChanged;

  const _BasicInfoPage({
    required this.formKey,
    required this.nameController,
    required this.descriptionController,
    required this.selectedCategory,
    required this.onCategoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Datos del comercio', style: TuM2TextStyles.headlineMedium),
            const SizedBox(height: 24),
            TextFormField(
              controller: nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nombre del comercio'),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Ingresá el nombre' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedCategory,
              decoration: const InputDecoration(labelText: 'Rubro'),
              items: AppConstants.storeCategories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: onCategoryChanged,
              validator: (v) =>
                  v == null || v.isEmpty ? 'Seleccioná el rubro' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: descriptionController,
              maxLines: 3,
              maxLength: AppConstants.maxStoreDescriptionLength,
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationPage extends StatelessWidget {
  final TextEditingController addressController;
  final TextEditingController neighborhoodController;
  final TextEditingController localityController;

  const _LocationPage({
    required this.addressController,
    required this.neighborhoodController,
    required this.localityController,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ubicación', style: TuM2TextStyles.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Ingresá la dirección exacta de tu comercio.',
            style: TuM2TextStyles.bodyMedium
                .copyWith(color: TuM2Colors.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: addressController,
            decoration: const InputDecoration(
              labelText: 'Dirección',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: neighborhoodController,
            decoration: const InputDecoration(labelText: 'Barrio'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: localityController,
            decoration: const InputDecoration(labelText: 'Localidad / Ciudad'),
          ),
          const SizedBox(height: 24),
          // Map placeholder — Google Maps integration pending API key
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: TuM2Colors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: TuM2Colors.outline),
            ),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.map_outlined,
                      size: 48, color: TuM2Colors.onSurfaceVariant),
                  SizedBox(height: 8),
                  Text('Mapa — requiere configurar Google Maps API'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewPage extends StatelessWidget {
  final String name;
  final String category;
  final String address;
  final bool isLoading;
  final String? error;
  final VoidCallback onSubmit;

  const _ReviewPage({
    required this.name,
    required this.category,
    required this.address,
    required this.isLoading,
    this.error,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Revisá los datos', style: TuM2TextStyles.headlineMedium),
          const SizedBox(height: 24),
          _InfoRow(label: 'Nombre', value: name),
          const Divider(height: 24),
          _InfoRow(label: 'Rubro', value: category),
          const Divider(height: 24),
          _InfoRow(label: 'Dirección', value: address),
          const Spacer(),
          if (error != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: TuM2Colors.errorLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(error!,
                  style: TuM2TextStyles.bodySmall
                      .copyWith(color: TuM2Colors.error)),
            ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: isLoading ? null : onSubmit,
            child: isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Publicar comercio'),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(label,
              style: TuM2TextStyles.bodySmall
                  .copyWith(color: TuM2Colors.onSurfaceVariant)),
        ),
        Expanded(
          child: Text(value.isEmpty ? '—' : value,
              style: TuM2TextStyles.bodyMedium),
        ),
      ],
    );
  }
}
