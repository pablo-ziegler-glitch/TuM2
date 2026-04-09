import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../providers/owner_providers.dart';

class OwnerEditProfileScreen extends ConsumerStatefulWidget {
  const OwnerEditProfileScreen({super.key});

  @override
  ConsumerState<OwnerEditProfileScreen> createState() =>
      _OwnerEditProfileScreenState();
}

class _OwnerEditProfileScreenState
    extends ConsumerState<OwnerEditProfileScreen> {
  final _razonSocialCtrl = TextEditingController();
  final _nombreFantasiaCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String? _boundMerchantId;
  bool _saving = false;

  @override
  void dispose() {
    _razonSocialCtrl.dispose();
    _nombreFantasiaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final merchantAsync = ref.watch(ownerMerchantProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Editar comercio', style: AppTextStyles.headingSm),
      ),
      body: merchantAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary500),
        ),
        error: (_, __) => Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'No pudimos cargar los datos de tu comercio.',
                  style: AppTextStyles.headingSm,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () => ref.invalidate(ownerMerchantProvider),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary500,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
        data: (resolution) {
          final merchant = resolution.primaryMerchant;
          if (merchant == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'No encontramos un comercio asociado a tu usuario.',
                  style: AppTextStyles.bodyMd,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          _bindInitialValues(
              merchant.id, merchant.razonSocial, merchant.nombreFantasia);

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Text(
                  'Configuración de tienda',
                  style: AppTextStyles.headingMd.copyWith(
                    color: AppColors.neutral900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Actualizá el nombre legal y el nombre visible de tu comercio.',
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.neutral700,
                  ),
                ),
                const SizedBox(height: 18),
                const _FieldLabel('Razón social *'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _razonSocialCtrl,
                  textInputAction: TextInputAction.next,
                  maxLength: 80,
                  validator: _validateRazonSocial,
                  decoration: const InputDecoration(
                    hintText: 'Ej: Farmacia del Centro S.R.L.',
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                const _FieldLabel('Nombre de fantasía'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nombreFantasiaCtrl,
                  textInputAction: TextInputAction.done,
                  maxLength: 80,
                  decoration: const InputDecoration(
                    hintText: 'Ej: Farmacia del Centro',
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Si no lo cargás, se va a mostrar la razón social como nombre visible.',
                  style: AppTextStyles.bodyXs
                      .copyWith(color: AppColors.neutral600),
                ),
                const SizedBox(height: 16),
                _NamePreview(
                  name: _effectiveVisibleName(),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _saving
                      ? null
                      : () => _saveChanges(
                            merchantId: merchant.id,
                          ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary500,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Guardar cambios'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _bindInitialValues(
    String merchantId,
    String razonSocial,
    String nombreFantasia,
  ) {
    if (_boundMerchantId == merchantId) return;
    _boundMerchantId = merchantId;
    _razonSocialCtrl.text = razonSocial.trim();
    _nombreFantasiaCtrl.text = nombreFantasia.trim();
  }

  String? _validateRazonSocial(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) return 'Ingresá la razón social.';
    if (trimmed.length < 2) return 'Debe tener al menos 2 caracteres.';
    if (trimmed.length > 80) return 'No puede superar 80 caracteres.';
    return null;
  }

  String _effectiveVisibleName() {
    final fantasy = _nombreFantasiaCtrl.text.trim();
    if (fantasy.isNotEmpty) return fantasy;
    final legal = _razonSocialCtrl.text.trim();
    if (legal.isNotEmpty) return legal;
    return 'Comercio sin nombre';
  }

  Future<void> _saveChanges({
    required String merchantId,
  }) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _saving = true);
    try {
      await ref.read(ownerRepositoryProvider).updateMerchantProfile(
            merchantId: merchantId,
            razonSocial: _razonSocialCtrl.text,
            nombreFantasia: _nombreFantasiaCtrl.text,
          );
      ref.invalidate(ownerMerchantProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil del comercio actualizado.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudieron guardar los cambios.'),
          backgroundColor: AppColors.errorFg,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.labelMd.copyWith(color: AppColors.neutral900),
    );
  }
}

class _NamePreview extends StatelessWidget {
  const _NamePreview({
    required this.name,
  });

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.infoBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary200),
      ),
      child: Row(
        children: [
          const Icon(Icons.visibility_outlined, color: AppColors.primary600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Nombre visible: $name',
              style: AppTextStyles.bodySm.copyWith(color: AppColors.primary700),
            ),
          ),
        ],
      ),
    );
  }
}
