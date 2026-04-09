import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/auth/auth_notifier.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/providers/feature_flags_provider.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_toast.dart';
import '../analytics/owner_products_analytics.dart';
import '../models/catalog_capacity.dart';
import '../models/merchant_product.dart';
import '../providers/catalog_capacity_providers.dart';
import '../providers/owner_providers.dart';
import '../providers/product_providers.dart';
import '../repositories/product_repository.dart';
import '../widgets/product_public_preview_card.dart';
import 'product_form_controller.dart';
import 'product_saved_screen.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  const ProductFormScreen({
    super.key,
    this.productId,
    this.debugOwnerUserId,
  });

  final String? productId;
  final String? debugOwnerUserId;

  bool get isEditing =>
      productId != null && normalizeProductField(productId!) != '';

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _priceFocusNode = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();

  bool _seededControllers = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _priceController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _nameFocusNode.dispose();
    _priceFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ownerMerchantAsync = ref.watch(ownerMerchantProvider);
    final catalogCapacityPolicyEnabledAsync =
        ref.watch(catalogCapacityPolicyEnabledProvider);
    final catalogCapacityHardBlockEnabledAsync =
        ref.watch(catalogCapacityHardBlockEnabledProvider);
    final catalogCreateViaCfEnabledAsync =
        ref.watch(catalogProductCreateViaCfEnabledProvider);
    final catalogLimitsConfigAsync = ref.watch(catalogLimitsConfigProvider);
    final ownerUserId = widget.debugOwnerUserId != null
        ? normalizeProductField(widget.debugOwnerUserId!)
        : _ownerUserIdFromAuth();
    if (ownerUserId.isEmpty) {
      return const _FormScaffold(
        title: 'Producto',
        child: _FormErrorState(
          message: 'Tu sesión cambió. Volvé a iniciar sesión.',
        ),
      );
    }

    return ownerMerchantAsync.when(
      loading: _buildLoadingScaffold,
      error: (_, __) => _FormScaffold(
        title: widget.isEditing ? 'Editar producto' : 'Nuevo producto',
        child: _FormErrorState(
          message: 'No pudimos validar tu comercio.',
          onRetry: () => ref.invalidate(ownerMerchantProvider),
        ),
      ),
      data: (resolution) {
        final merchant = resolution.primaryMerchant;
        if (merchant == null) {
          return const _FormScaffold(
            title: 'Producto',
            child: _FormErrorState(
              message: 'No encontramos un comercio asociado a tu usuario.',
            ),
          );
        }

        final catalogPolicyEnabled =
            catalogCapacityPolicyEnabledAsync.valueOrNull ?? true;
        final catalogHardBlockEnabled =
            catalogCapacityHardBlockEnabledAsync.valueOrNull ?? true;
        final catalogCreateViaCfEnabled =
            catalogCreateViaCfEnabledAsync.valueOrNull ?? true;
        final catalogCapacity =
            catalogPolicyEnabled && catalogLimitsConfigAsync.hasValue
                ? resolveOwnerCatalogCapacity(
                    categoryId: merchant.categoryId,
                    activeProductCount: merchant.activeProductCount,
                    merchantLimitOverride: merchant.catalogProductLimitOverride,
                    config: catalogLimitsConfigAsync.requireValue,
                  )
                : null;
        final isCreateBlocked = !widget.isEditing &&
            catalogPolicyEnabled &&
            catalogHardBlockEnabled &&
            (catalogCapacity?.isBlocked ?? false);
        final isCreateDisabledByFlag =
            !widget.isEditing && !catalogCreateViaCfEnabled;
        final isCreateWarning = !widget.isEditing &&
            catalogPolicyEnabled &&
            (catalogCapacity?.isWarning ?? false);

        final scope = ProductFormScope(
          merchantId: merchant.id,
          ownerUserId: ownerUserId,
          productId: widget.productId,
        );
        final formState = ref.watch(productFormNotifierProvider(scope));
        final notifier = ref.read(productFormNotifierProvider(scope).notifier);
        final uploadState = ref.watch(productImageUploadStateProvider(scope));

        _seedTextControllers(formState);
        final imageProvider = _resolveImageProvider(formState);

        return _FormScaffold(
          title: widget.isEditing ? 'Editar producto' : 'Nuevo producto',
          child: formState.isInitialLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary500),
                )
              : GestureDetector(
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: SafeArea(
                    child: Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (formState.message != null &&
                                    formState.submitStatus ==
                                        ProductFormSubmitStatus.error) ...[
                                  _InlineBanner(
                                    message: formState.message!,
                                    isError: true,
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                if (formState.isEditing &&
                                    formState.status ==
                                        ProductStatus.inactive) ...[
                                  const _InlineBanner(
                                    message:
                                        'Este producto está inactivo. Podés editarlo, pero no se mostrará públicamente.',
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                if (isCreateWarning && catalogCapacity != null)
                                  _CatalogCapacityNotice(
                                    message:
                                        'Te estás quedando con poco espacio para tu catálogo (${catalogCapacity.used}/${catalogCapacity.limit}).',
                                    isError: false,
                                  ),
                                if (isCreateBlocked && catalogCapacity != null)
                                  _CatalogCapacityNotice(
                                    message:
                                        'Límite alcanzado (${catalogCapacity.used}/${catalogCapacity.limit}). No podés crear nuevos productos.',
                                    isError: true,
                                  ),
                                if (isCreateDisabledByFlag)
                                  const _CatalogCapacityNotice(
                                    message:
                                        'La creación de productos está temporalmente deshabilitada por configuración.',
                                    isError: true,
                                  ),
                                if (((isCreateWarning || isCreateBlocked) &&
                                        catalogCapacity != null) ||
                                    isCreateDisabledByFlag)
                                  const SizedBox(height: 12),
                                _ImagePickerSection(
                                  imageProvider: imageProvider,
                                  imageError: formState.imageError,
                                  onPickImage: () => _onPickImage(notifier),
                                  onClearImage: formState.hasLocalImage
                                      ? notifier.clearLocalImage
                                      : null,
                                ),
                                if (uploadState.isUploading) ...[
                                  const SizedBox(height: 10),
                                  LinearProgressIndicator(
                                    value: uploadState.progress == 0
                                        ? null
                                        : uploadState.progress,
                                  ),
                                ],
                                const SizedBox(height: 18),
                                _LabeledField(
                                  label: 'Nombre',
                                  child: TextField(
                                    controller: _nameController,
                                    focusNode: _nameFocusNode,
                                    textInputAction: TextInputAction.next,
                                    onSubmitted: (_) =>
                                        _priceFocusNode.requestFocus(),
                                    onChanged: notifier.setName,
                                    maxLength: productNameMaxLength,
                                    decoration: InputDecoration(
                                      hintText: 'Nombre del producto',
                                      errorText: formState.nameError,
                                      counterText: '',
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                _LabeledField(
                                  label: 'Precio visible',
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      TextField(
                                        controller: _priceController,
                                        focusNode: _priceFocusNode,
                                        textInputAction: TextInputAction.done,
                                        onSubmitted: (_) => _handleSubmit(
                                          scope: scope,
                                          ownerUserId: ownerUserId,
                                          merchantId: merchant.id,
                                          catalogCapacity: catalogCapacity,
                                          catalogPolicyEnabled:
                                              catalogPolicyEnabled,
                                          catalogHardBlockEnabled:
                                              catalogHardBlockEnabled,
                                          catalogCreateViaCfEnabled:
                                              catalogCreateViaCfEnabled,
                                        ),
                                        onChanged: notifier.setPriceLabel,
                                        maxLength: productPriceLabelMaxLength,
                                        decoration: InputDecoration(
                                          hintText: '\$ 0.00',
                                          errorText: formState.priceLabelError,
                                          counterText: '',
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            left: 4, top: 4),
                                        child: Text(
                                          'Ej: \$2.500, Desde \$4.000 o Consultar',
                                          style: AppTextStyles.bodyXs.copyWith(
                                            color: AppColors.neutral600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _OperationalStateCard(
                                  stockStatus: formState.stockStatus,
                                  visibilityStatus: formState.visibilityStatus,
                                  onStockChanged: notifier.setStockStatus,
                                  onVisibilityChanged:
                                      notifier.setVisibilityStatus,
                                ),
                                const SizedBox(height: 14),
                                ProductPublicPreviewCard(
                                  name: formState.name,
                                  priceLabel: formState.priceLabel,
                                  stockStatus: formState.stockStatus,
                                  visibilityStatus: formState.visibilityStatus,
                                  status: formState.status,
                                  imageProvider: imageProvider,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: Column(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFF0044AA),
                                        Color(0xFF0E5BD8)
                                      ],
                                    ),
                                  ),
                                  child: ElevatedButton(
                                    onPressed: formState.isSubmitting ||
                                            isCreateBlocked ||
                                            isCreateDisabledByFlag
                                        ? null
                                        : () => _handleSubmit(
                                              scope: scope,
                                              ownerUserId: ownerUserId,
                                              merchantId: merchant.id,
                                              catalogCapacity: catalogCapacity,
                                              catalogPolicyEnabled:
                                                  catalogPolicyEnabled,
                                              catalogHardBlockEnabled:
                                                  catalogHardBlockEnabled,
                                              catalogCreateViaCfEnabled:
                                                  catalogCreateViaCfEnabled,
                                            ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      foregroundColor: Colors.white,
                                      shadowColor: Colors.transparent,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                    ),
                                    child: formState.isSubmitting
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Text(
                                            widget.isEditing
                                                ? 'Guardar cambios'
                                                : (isCreateBlocked
                                                    ? 'Límite alcanzado'
                                                    : (isCreateDisabledByFlag
                                                        ? 'Temporalmente deshabilitado'
                                                        : 'Guardar producto')),
                                            style:
                                                AppTextStyles.labelMd.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: formState.isSubmitting
                                    ? null
                                    : () {
                                        if (context.canPop()) {
                                          context.pop();
                                        } else {
                                          context.go(AppRoutes.ownerProducts);
                                        }
                                      },
                                child: Text(
                                  'Cancelar',
                                  style: AppTextStyles.labelMd.copyWith(
                                    color: AppColors.neutral700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  String _ownerUserIdFromAuth() {
    final authState = ref.watch(authNotifierProvider).authState;
    if (authState is! AuthAuthenticated) return '';
    return normalizeProductField(authState.user.uid);
  }

  _FormScaffold _buildLoadingScaffold() {
    return _FormScaffold(
      title: widget.isEditing ? 'Editar producto' : 'Nuevo producto',
      child: const Center(
        child: CircularProgressIndicator(color: AppColors.primary500),
      ),
    );
  }

  void _seedTextControllers(ProductFormState state) {
    if (_seededControllers || state.isInitialLoading) return;
    _seededControllers = true;
    _nameController.text = state.name;
    _priceController.text = state.priceLabel;
  }

  ImageProvider<Object>? _resolveImageProvider(ProductFormState state) {
    if (state.localImage != null) {
      return MemoryImage(state.localImage!.bytes);
    }
    final imageUrl = normalizeNullableProductField(state.currentImageUrl);
    if (imageUrl != null) {
      return NetworkImage(imageUrl);
    }
    return null;
  }

  Future<void> _onPickImage(ProductFormNotifier notifier) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final mimeType = normalizeNullableProductField(picked.mimeType) ??
          _guessContentType(picked.name);
      notifier.setLocalImage(
        ProductImageUploadData(
          bytes: bytes,
          contentType: mimeType,
          fileName: picked.name,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      AppToast.show(
        context,
        message: 'No se pudo seleccionar la imagen.',
        type: ToastType.error,
      );
    }
  }

  Future<void> _handleSubmit({
    required ProductFormScope scope,
    required String ownerUserId,
    required String merchantId,
    required OwnerCatalogCapacity? catalogCapacity,
    required bool catalogPolicyEnabled,
    required bool catalogHardBlockEnabled,
    required bool catalogCreateViaCfEnabled,
  }) async {
    final isCreateViaCfDisabled =
        !widget.isEditing && !catalogCreateViaCfEnabled;
    if (isCreateViaCfDisabled) {
      if (!mounted) return;
      AppToast.show(
        context,
        message:
            'La creación de productos está temporalmente deshabilitada por configuración.',
        type: ToastType.error,
      );
      return;
    }

    final isCreateBlocked = !widget.isEditing &&
        catalogPolicyEnabled &&
        catalogHardBlockEnabled &&
        (catalogCapacity?.isBlocked ?? false);
    if (isCreateBlocked) {
      await OwnerProductsAnalytics.logProductCreateBlockedByLimit(
        merchantId: merchantId,
        used: catalogCapacity?.used ?? 0,
        limit: catalogCapacity?.limit ?? 0,
        source: catalogCapacity?.source.value ?? 'global_default',
      );
      if (!mounted) return;
      AppToast.show(
        context,
        message:
            'Alcanzaste el límite del catálogo. Contactá a administración para ampliar el cupo.',
        type: ToastType.error,
      );
      return;
    }

    FocusScope.of(context).unfocus();
    final notifier = ref.read(productFormNotifierProvider(scope).notifier);
    final repository = ref.read(productRepositoryProvider);
    notifier.setName(_nameController.text);
    notifier.setPriceLabel(_priceController.text);

    final result = await notifier.submit(actorUserId: ownerUserId);
    if (!result.success || !mounted) return;

    ref.invalidate(merchantProductsProvider(scope.merchantId));
    ref.invalidate(ownerMerchantProvider);
    if (widget.productId != null) {
      ref.invalidate(merchantProductByIdProvider(widget.productId!));
    }

    if (result.isCreate) {
      final createdId = result.productId;
      MerchantProduct? createdProduct;
      if (createdId != null && createdId.isNotEmpty) {
        try {
          createdProduct = await repository.getProductById(createdId);
        } catch (_) {
          createdProduct = null;
        }
      }

      final latestState = ref.read(productFormNotifierProvider(scope));
      final payload = ProductSavedPayload(
        productId: createdId ?? '',
        name: createdProduct?.name ?? normalizeProductField(latestState.name),
        priceLabel: createdProduct?.priceLabel ??
            normalizeProductField(latestState.priceLabel),
        imageUrl: createdProduct?.imageUrl,
        isPublic: (createdProduct?.status ?? latestState.status) ==
                ProductStatus.active &&
            (createdProduct?.visibilityStatus ??
                    latestState.visibilityStatus) ==
                ProductVisibilityStatus.visible,
      );
      if (!mounted) return;
      context.go(AppRoutes.ownerProductsSaved, extra: payload);
      return;
    }

    AppToast.show(
      context,
      message: 'Producto actualizado correctamente.',
      type: ToastType.success,
    );
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.ownerProducts);
    }
  }
}

class _FormScaffold extends StatelessWidget {
  const _FormScaffold({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: Text(title, style: AppTextStyles.headingSm),
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: child,
    );
  }
}

class _ImagePickerSection extends StatelessWidget {
  const _ImagePickerSection({
    required this.imageProvider,
    required this.imageError,
    required this.onPickImage,
    this.onClearImage,
  });

  final ImageProvider<Object>? imageProvider;
  final String? imageError;
  final VoidCallback onPickImage;
  final VoidCallback? onClearImage;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Imagen del producto',
          style: AppTextStyles.labelMd.copyWith(color: AppColors.neutral700),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          height: 182,
          decoration: BoxDecoration(
            color: AppColors.neutral100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  imageError == null ? AppColors.neutral300 : AppColors.errorFg,
              style: BorderStyle.solid,
              width: 1.2,
            ),
          ),
          child: imageProvider == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.add_a_photo_outlined,
                      size: 38,
                      color: AppColors.neutral500,
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: onPickImage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary500,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                      ),
                      child: const Text('Subir foto'),
                    ),
                  ],
                )
              : Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: Image(
                          image: imageProvider!,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 10,
                      top: 10,
                      child: Row(
                        children: [
                          if (onClearImage != null)
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.95),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: onClearImage,
                                tooltip: 'Quitar foto',
                              ),
                            ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.upload_outlined),
                              onPressed: onPickImage,
                              tooltip: 'Cambiar foto',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 6),
        Text(
          'Usá una foto clara y liviana',
          style: AppTextStyles.bodyXs.copyWith(
            color: AppColors.neutral600,
            fontStyle: FontStyle.italic,
          ),
        ),
        if (imageError != null) ...[
          const SizedBox(height: 4),
          Text(
            imageError!,
            style: AppTextStyles.bodyXs.copyWith(
              color: AppColors.errorFg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.labelMd.copyWith(
            color: AppColors.neutral700,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _OperationalStateCard extends StatelessWidget {
  const _OperationalStateCard({
    required this.stockStatus,
    required this.visibilityStatus,
    required this.onStockChanged,
    required this.onVisibilityChanged,
  });

  final ProductStockStatus stockStatus;
  final ProductVisibilityStatus visibilityStatus;
  final ValueChanged<ProductStockStatus> onStockChanged;
  final ValueChanged<ProductVisibilityStatus> onVisibilityChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.neutral100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ESTADO OPERATIVO',
            style: AppTextStyles.labelSm.copyWith(
              color: AppColors.neutral600,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Stock',
            style: AppTextStyles.labelSm.copyWith(
              color: AppColors.neutral700,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          _SegmentedOptionBar<ProductStockStatus>(
            values: const [
              ProductStockStatus.available,
              ProductStockStatus.outOfStock,
            ],
            selected: stockStatus,
            labelBuilder: (value) {
              switch (value) {
                case ProductStockStatus.available:
                  return 'Disponible';
                case ProductStockStatus.outOfStock:
                  return 'Sin stock';
              }
            },
            onChanged: onStockChanged,
          ),
          const SizedBox(height: 12),
          Text(
            'Visibilidad',
            style: AppTextStyles.labelSm.copyWith(
              color: AppColors.neutral700,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          _SegmentedOptionBar<ProductVisibilityStatus>(
            values: const [
              ProductVisibilityStatus.visible,
              ProductVisibilityStatus.hidden,
            ],
            selected: visibilityStatus,
            labelBuilder: (value) {
              switch (value) {
                case ProductVisibilityStatus.visible:
                  return 'Visible';
                case ProductVisibilityStatus.hidden:
                  return 'Oculto';
              }
            },
            onChanged: onVisibilityChanged,
          ),
          const SizedBox(height: 8),
          Text(
            visibilityStatus == ProductVisibilityStatus.visible
                ? 'Los vecinos lo pueden ver'
                : 'Solo lo ves vos',
            style: AppTextStyles.bodyXs.copyWith(
              color: AppColors.neutral600,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentedOptionBar<T> extends StatelessWidget {
  const _SegmentedOptionBar({
    required this.values,
    required this.selected,
    required this.labelBuilder,
    required this.onChanged,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) labelBuilder;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.neutral200,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          for (final value in values)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: InkWell(
                  onTap: () => onChanged(value),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: selected == value
                          ? AppColors.surface
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: selected == value
                          ? const [
                              BoxShadow(
                                color: Color(0x13000000),
                                blurRadius: 6,
                                offset: Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      labelBuilder(value),
                      style: AppTextStyles.labelSm.copyWith(
                        color: selected == value
                            ? AppColors.primary500
                            : AppColors.neutral700,
                        fontWeight: selected == value
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CatalogCapacityNotice extends StatelessWidget {
  const _CatalogCapacityNotice({
    required this.message,
    required this.isError,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isError ? AppColors.errorBg : AppColors.warningBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.block_rounded : Icons.warning_amber_rounded,
            size: 16,
            color: isError ? AppColors.errorFg : AppColors.warningFg,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySm.copyWith(
                color: isError ? AppColors.errorFg : AppColors.warningFg,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineBanner extends StatelessWidget {
  const _InlineBanner({
    required this.message,
    this.isError = false,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final foreground = isError ? AppColors.errorFg : AppColors.primary700;
    final background = isError ? AppColors.errorBg : AppColors.primary50;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        message,
        style: AppTextStyles.bodySm.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _FormErrorState extends StatelessWidget {
  const _FormErrorState({
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 32, color: AppColors.errorFg),
            const SizedBox(height: 12),
            Text(
              message,
              style: AppTextStyles.bodyMd,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: onRetry,
                child: const Text('Reintentar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _guessContentType(String fileName) {
  final normalized = normalizeProductField(fileName).toLowerCase();
  if (normalized.endsWith('.png')) return 'image/png';
  if (normalized.endsWith('.webp')) return 'image/webp';
  if (normalized.endsWith('.gif')) return 'image/gif';
  if (normalized.endsWith('.heic')) return 'image/heic';
  return 'image/jpeg';
}
