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
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _descriptionFocusNode = FocusNode();
  final FocusNode _priceFocusNode = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();
  int _createStep = 0;

  bool _seededControllers = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _priceController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _nameFocusNode.dispose();
    _descriptionFocusNode.dispose();
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
        final merchantProductsAsync = widget.isEditing
            ? const AsyncValue<List<MerchantProduct>>.data(<MerchantProduct>[])
            : ref.watch(merchantProductsProvider(merchant.id));
        final duplicateCandidate = _findPotentialDuplicate(
          incomingName: formState.name,
          products: merchantProductsAsync.valueOrNull ?? const [],
        );

        _seedTextControllers(formState);
        final imageProvider = _resolveImageProvider(formState);
        final isCreateFlow = !widget.isEditing;
        final stepTotal = 3;
        final stepLabel = isCreateFlow
            ? 'Paso ${_createStep + 1} de $stepTotal'
            : 'Editá y guardá cambios';
        final canGoNext = _canContinueStep(formState);

        return _FormScaffold(
          title: widget.isEditing ? 'Editar producto' : 'Agregar producto',
          subtitle: stepLabel,
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
                                if (!isCreateFlow || _createStep == 0) ...[
                                  Text(
                                    'Empezá con lo básico.',
                                    style: AppTextStyles.headingLg,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Después podés sumar más detalles.',
                                    style: AppTextStyles.bodyMd.copyWith(
                                      color: AppColors.neutral700,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  _LabeledField(
                                    label: 'Nombre del producto',
                                    child: TextField(
                                      controller: _nameController,
                                      focusNode: _nameFocusNode,
                                      textInputAction: TextInputAction.next,
                                      onSubmitted: (_) =>
                                          _descriptionFocusNode.requestFocus(),
                                      onChanged: notifier.setName,
                                      maxLength: productNameMaxLength,
                                      decoration: InputDecoration(
                                        hintText:
                                            'Ej: alimento balanceado, gaseosa fría, analgésico',
                                        errorText: formState.nameError,
                                        counterText: '',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Usá el nombre que el Vecino buscaría.',
                                    style: AppTextStyles.bodySm.copyWith(
                                      color: AppColors.neutral700,
                                    ),
                                  ),
                                  if (duplicateCandidate != null) ...[
                                    const SizedBox(height: 8),
                                    _DuplicateWarningInline(
                                      onOpen: () => _showDuplicateWarningSheet(
                                        product: duplicateCandidate,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 14),
                                  _LabeledField(
                                    label: 'Disponibilidad',
                                    child: _AvailabilityToggle(
                                      stockStatus: formState.stockStatus,
                                      onChanged: notifier.setStockStatus,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Podés cambiarlo cuando quieras.',
                                    style: AppTextStyles.bodySm.copyWith(
                                      color: AppColors.neutral700,
                                    ),
                                  ),
                                  if (!isCreateFlow) ...[
                                    const SizedBox(height: 16),
                                    _OperationalStateCard(
                                      stockStatus: formState.stockStatus,
                                      visibilityStatus:
                                          formState.visibilityStatus,
                                      onStockChanged: notifier.setStockStatus,
                                      onVisibilityChanged:
                                          notifier.setVisibilityStatus,
                                    ),
                                  ],
                                ],
                                if (!isCreateFlow || _createStep == 1) ...[
                                  if (isCreateFlow) ...[
                                    Text(
                                      'Detalles del producto',
                                      style: AppTextStyles.headingLg,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Podés completar esto después.',
                                      style: AppTextStyles.bodyMd.copyWith(
                                        color: AppColors.neutral700,
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                  ],
                                  _ImagePickerSection(
                                    imageProvider: imageProvider,
                                    imageError: formState.imageError,
                                    onPickImage: () => _onPickImage(notifier),
                                    onSkipPhoto: formState.hasLocalImage ||
                                            formState.hasCurrentImage
                                        ? null
                                        : () {
                                            FocusScope.of(context).unfocus();
                                            AppToast.show(
                                              context,
                                              message:
                                                  'Podés agregar la foto después.',
                                              type: ToastType.success,
                                            );
                                          },
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
                                  const SizedBox(height: 16),
                                  _LabeledField(
                                    label: 'Descripción breve',
                                    child: TextField(
                                      controller: _descriptionController,
                                      focusNode: _descriptionFocusNode,
                                      textInputAction: TextInputAction.next,
                                      onSubmitted: (_) =>
                                          _priceFocusNode.requestFocus(),
                                      maxLength: productDescriptionMaxLength,
                                      onChanged: notifier.setDescription,
                                      decoration: InputDecoration(
                                        hintText:
                                            'Ej: presentación chica, sabor clásico, venta por unidad',
                                        errorText: formState.descriptionError,
                                        counterText: '',
                                      ),
                                      minLines: 2,
                                      maxLines: 3,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Una frase corta alcanza.',
                                    style: AppTextStyles.bodySm.copyWith(
                                      color: AppColors.neutral700,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  _LabeledField(
                                    label: 'Precio',
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        TextField(
                                          controller: _priceController,
                                          focusNode: _priceFocusNode,
                                          textInputAction: TextInputAction.done,
                                          onChanged: (value) {
                                            notifier.setPriceLabel(value);
                                            final normalized =
                                                normalizeProductField(value);
                                            if (normalized.isEmpty &&
                                                formState.priceMode ==
                                                    ProductPriceMode.fixed) {
                                              notifier.setPriceMode(
                                                ProductPriceMode.none,
                                              );
                                            }
                                            if (normalized.isNotEmpty &&
                                                formState.priceMode !=
                                                    ProductPriceMode.consult) {
                                              notifier.setPriceMode(
                                                ProductPriceMode.fixed,
                                              );
                                            }
                                          },
                                          maxLength: productPriceLabelMaxLength,
                                          keyboardType: const TextInputType
                                              .numberWithOptions(decimal: true),
                                          decoration: InputDecoration(
                                            hintText: '\$ Ej: 2900',
                                            errorText:
                                                formState.priceLabelError,
                                            counterText: '',
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Opcional. Si cambia seguido, dejalo sin precio.',
                                          style: AppTextStyles.bodySm.copyWith(
                                            color: AppColors.neutral700,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        CheckboxListTile(
                                          value: formState.priceMode ==
                                              ProductPriceMode.consult,
                                          contentPadding: EdgeInsets.zero,
                                          controlAffinity:
                                              ListTileControlAffinity.leading,
                                          onChanged: (value) {
                                            if (value == true) {
                                              notifier.setPriceMode(
                                                ProductPriceMode.consult,
                                              );
                                              _priceController.text = '';
                                              notifier.setPriceLabel('');
                                              return;
                                            }
                                            notifier.setPriceMode(
                                              _priceController.text
                                                      .trim()
                                                      .isEmpty
                                                  ? ProductPriceMode.none
                                                  : ProductPriceMode.fixed,
                                            );
                                          },
                                          title: const Text(
                                            'Mostrar como consultar precio',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                if (!isCreateFlow || _createStep == 2) ...[
                                  if (isCreateFlow) ...[
                                    Text(
                                      'Así se va a ver en Tu zona.',
                                      style: AppTextStyles.headingLg,
                                    ),
                                    const SizedBox(height: 14),
                                  ],
                                  ProductPublicPreviewCard(
                                    merchantName: merchant.name,
                                    name: formState.name,
                                    description: formState.description,
                                    priceLabel: formState.priceLabel,
                                    priceMode: formState.priceMode,
                                    stockStatus: formState.stockStatus,
                                    visibilityStatus:
                                        formState.visibilityStatus,
                                    status: formState.status,
                                    imageProvider: imageProvider,
                                  ),
                                  const SizedBox(height: 14),
                                  const _InlineBanner(
                                    message:
                                        'Este producto puede aparecer para Vecinos que busquen en Tu zona.',
                                  ),
                                ],
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
                                        : () => _handlePrimaryAction(
                                              isCreateFlow: isCreateFlow,
                                              canGoNext: canGoNext,
                                              formState: formState,
                                              notifier: notifier,
                                              merchantId: merchant.id,
                                              scope: scope,
                                              ownerUserId: ownerUserId,
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
                                                : (_createStep < 2
                                                    ? 'Continuar'
                                                    : (isCreateBlocked
                                                        ? 'Límite alcanzado'
                                                        : (isCreateDisabledByFlag
                                                            ? 'Temporalmente deshabilitado'
                                                            : 'Publicar producto'))),
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
                                        if (!widget.isEditing &&
                                            _createStep > 0) {
                                          setState(() {
                                            _createStep -= 1;
                                          });
                                          return;
                                        }
                                        if (context.canPop()) {
                                          context.pop();
                                        } else {
                                          context.go(AppRoutes.ownerProducts);
                                        }
                                      },
                                child: Text(
                                  (!widget.isEditing && _createStep > 0)
                                      ? 'Volver'
                                      : 'Cancelar',
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
    _descriptionController.text = state.description;
    _priceController.text = state.priceLabel;
  }

  bool _canContinueStep(ProductFormState state) {
    if (widget.isEditing) return true;
    if (_createStep == 0) {
      return normalizeProductField(state.name).isNotEmpty;
    }
    if (_createStep == 1) {
      return true;
    }
    return true;
  }

  bool _looksLikeDuplicate({
    required String incomingName,
    required String existingName,
    required String? editingProductId,
    required String existingProductId,
  }) {
    if (editingProductId != null && editingProductId == existingProductId) {
      return false;
    }
    final incoming = normalizeProductName(incomingName);
    final existing = normalizeProductName(existingName);
    if (incoming.isEmpty || existing.isEmpty) return false;
    if (incoming == existing) return true;
    return incoming.length >= 5 &&
        existing.length >= 5 &&
        (incoming.contains(existing) || existing.contains(incoming));
  }

  MerchantProduct? _findPotentialDuplicate({
    required String incomingName,
    required List<MerchantProduct> products,
  }) {
    for (final item in products) {
      if (item.status != ProductStatus.active) continue;
      if (_looksLikeDuplicate(
        incomingName: incomingName,
        existingName: item.name,
        editingProductId: widget.productId,
        existingProductId: item.id,
      )) {
        return item;
      }
    }
    return null;
  }

  Future<void> _showDuplicateWarningSheet({
    required MerchantProduct product,
  }) async {
    final parentContext = context;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ya tenés un producto parecido',
                  style: AppTextStyles.headingSm,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Podés editar el producto existente o cargar este igual si es distinto.',
                  style: AppTextStyles.bodySm,
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.neutral100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: AppTextStyles.labelMd,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        product.displayPriceLabel,
                        style: AppTextStyles.bodyXs.copyWith(
                          color: AppColors.neutral600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      parentContext.push(
                        AppRoutes.ownerProductsEditPath(product.id),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary500,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Ver producto existente'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cargar igual'),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _nameFocusNode.requestFocus();
                    },
                    child: const Text('Volver y editar'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handlePrimaryAction({
    required bool isCreateFlow,
    required bool canGoNext,
    required ProductFormState formState,
    required ProductFormNotifier notifier,
    required String merchantId,
    required ProductFormScope scope,
    required String ownerUserId,
    required OwnerCatalogCapacity? catalogCapacity,
    required bool catalogPolicyEnabled,
    required bool catalogHardBlockEnabled,
    required bool catalogCreateViaCfEnabled,
  }) async {
    if (!isCreateFlow) {
      await _handleSubmit(
        scope: scope,
        ownerUserId: ownerUserId,
        merchantId: merchantId,
        catalogCapacity: catalogCapacity,
        catalogPolicyEnabled: catalogPolicyEnabled,
        catalogHardBlockEnabled: catalogHardBlockEnabled,
        catalogCreateViaCfEnabled: catalogCreateViaCfEnabled,
      );
      return;
    }

    if (_createStep == 0) {
      notifier.setName(_nameController.text);
      final isValid = notifier.validateStepBasic();
      if (!isValid) {
        return;
      }
      if (!canGoNext) return;
      setState(() => _createStep = 1);
      return;
    }

    if (_createStep == 1) {
      notifier.setDescription(_descriptionController.text);
      notifier.setPriceLabel(_priceController.text);
      if (normalizeProductField(_priceController.text).isNotEmpty &&
          formState.priceMode != ProductPriceMode.consult) {
        notifier.setPriceMode(ProductPriceMode.fixed);
      } else if (normalizeProductField(_priceController.text).isEmpty &&
          formState.priceMode == ProductPriceMode.fixed) {
        notifier.setPriceMode(ProductPriceMode.none);
      }
      final isValid = notifier.validateStepDetails();
      if (!isValid) {
        return;
      }
      if (!canGoNext) return;
      setState(() => _createStep = 2);
      return;
    }

    await _handleSubmit(
      scope: scope,
      ownerUserId: ownerUserId,
      merchantId: merchantId,
      catalogCapacity: catalogCapacity,
      catalogPolicyEnabled: catalogPolicyEnabled,
      catalogHardBlockEnabled: catalogHardBlockEnabled,
      catalogCreateViaCfEnabled: catalogCreateViaCfEnabled,
    );
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
            'Llegaste al máximo de productos activos. Para cargar otro, ocultá alguno que ya no quieras mostrar en Tu zona.',
        type: ToastType.error,
      );
      return;
    }

    FocusScope.of(context).unfocus();
    final notifier = ref.read(productFormNotifierProvider(scope).notifier);
    final repository = ref.read(productRepositoryProvider);
    notifier.setName(_nameController.text);
    notifier.setDescription(_descriptionController.text);
    notifier.setPriceLabel(_priceController.text);
    if (normalizeProductField(_priceController.text).isNotEmpty &&
        ref.read(productFormNotifierProvider(scope)).priceMode !=
            ProductPriceMode.consult) {
      notifier.setPriceMode(ProductPriceMode.fixed);
    }

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
        priceLabel: (createdProduct?.displayPriceLabel ??
                _resolveDisplayPriceLabel(
                  priceMode: latestState.priceMode,
                  rawPriceLabel: latestState.priceLabel,
                ))
            .trim(),
        imageUrl: createdProduct?.imageUrl,
        isPublic: (createdProduct?.status ?? latestState.status) ==
                ProductStatus.active &&
            (createdProduct?.visibilityStatus ??
                    latestState.visibilityStatus) ==
                ProductVisibilityStatus.visible,
        imageUploadFailed: result.imageUploadFailed,
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
    this.subtitle,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, style: AppTextStyles.headingSm),
            if (subtitle != null)
              Text(
                subtitle!,
                style: AppTextStyles.bodyXs.copyWith(
                  color: AppColors.neutral600,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
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
    this.onSkipPhoto,
    this.onClearImage,
  });

  final ImageProvider<Object>? imageProvider;
  final String? imageError;
  final VoidCallback onPickImage;
  final VoidCallback? onSkipPhoto;
  final VoidCallback? onClearImage;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Foto del producto',
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
                      child: const Text('Agregar foto'),
                    ),
                    if (onSkipPhoto != null) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: onSkipPhoto,
                        child: const Text('Foto luego'),
                      ),
                    ],
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
          'Ayuda a que el Vecino lo reconozca, pero podés cargarla después.',
          style: AppTextStyles.bodyXs.copyWith(
            color: AppColors.neutral600,
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

class _AvailabilityToggle extends StatelessWidget {
  const _AvailabilityToggle({
    required this.stockStatus,
    required this.onChanged,
  });

  final ProductStockStatus stockStatus;
  final ValueChanged<ProductStockStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    return _SegmentedOptionBar<ProductStockStatus>(
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
            return 'Agotado';
        }
      },
      onChanged: onChanged,
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

class _DuplicateWarningInline extends StatelessWidget {
  const _DuplicateWarningInline({
    required this.onOpen,
  });

  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ya tenés un producto parecido.',
            style: AppTextStyles.bodySm.copyWith(
              color: AppColors.warningFg,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              TextButton(
                onPressed: onOpen,
                child: const Text('Ver producto existente'),
              ),
              Expanded(
                child: Text(
                  'Podés cargarlo igual si es distinto.',
                  textAlign: TextAlign.right,
                  style: AppTextStyles.bodyXs.copyWith(
                    color: AppColors.warningFg,
                  ),
                ),
              ),
            ],
          ),
        ],
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

String _resolveDisplayPriceLabel({
  required ProductPriceMode priceMode,
  required String rawPriceLabel,
}) {
  switch (priceMode) {
    case ProductPriceMode.consult:
      return 'Consultar precio';
    case ProductPriceMode.none:
      return '';
    case ProductPriceMode.fixed:
      return normalizeProductField(rawPriceLabel);
  }
}
