import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/analytics/auth_analytics.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_text_input.dart';
import '../../../core/widgets/primary_button.dart';

/// AUTH-05 — Micro-step de nombre de usuario.
///
/// Se muestra SOLO en estas condiciones (validadas por el guard del router):
///   - El usuario se autenticó via magic link (no Google)
///   - user.displayName es null o vacío
///
/// Permite al usuario ingresar cómo quiere ser llamado.
/// El botón "Ahora no" salta el paso sin guardar nombre.
class DisplayNameScreen extends ConsumerStatefulWidget {
  const DisplayNameScreen({super.key});

  @override
  ConsumerState<DisplayNameScreen> createState() => _DisplayNameScreenState();
}

class _DisplayNameScreenState extends ConsumerState<DisplayNameScreen> {
  final _controller = TextEditingController();
  bool _isLoading = false;
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _nameIsValid {
    final name = _controller.text.trim();
    return name.length >= 2;
  }

  Future<void> _save() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;

    if (name.length < 2) {
      setState(() => _errorText = 'El nombre debe tener al menos 2 caracteres.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _goHome();
        return;
      }

      // Actualizar displayName en Firebase Auth y en Firestore en paralelo
      await Future.wait([
        user.updateDisplayName(name),
        FirebaseFirestore.instance.doc('users/${user.uid}').update({
          'displayName': name,
          'updatedAt': FieldValue.serverTimestamp(),
        }),
      ]);

      AuthAnalytics.logDisplayNameSet().ignore();
      if (mounted) _goHome();
    } catch (_) {
      setState(() {
        _isLoading = false;
        _errorText = 'No pudimos guardar tu nombre. Intentá de nuevo.';
      });
    }
  }

  /// Salta el paso sin guardar. Marca el provider para evitar redirect circular.
  void _skip() {
    AuthAnalytics.logDisplayNameSkipped().ignore();
    ref.read(displayNameSkippedProvider.notifier).state = true;
    _goHome();
  }

  void _goHome() => context.go(AppRoutes.home);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),

              // Ícono decorativo
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: AppColors.primary50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.waving_hand_outlined,
                  size: 28,
                  color: AppColors.primary500,
                ),
              ),

              const SizedBox(height: 24),

              Text('¿Cómo te llamamos?', style: AppTextStyles.headingMd),
              const SizedBox(height: 8),
              Text(
                'Podés cambiarlo después desde tu perfil.',
                style: AppTextStyles.bodySm.copyWith(
                  color: AppColors.neutral600,
                ),
              ),

              const SizedBox(height: 32),

              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return AppTextInput(
                    hint: 'Tu nombre',
                    controller: _controller,
                    errorText: _errorText,
                    enabled: !_isLoading,
                    textInputAction: TextInputAction.done,
                    prefixIcon: const Icon(Icons.person_outline, size: 20),
                    onSubmitted: (_) {
                      if (_nameIsValid) _save();
                    },
                    onChanged: (_) {
                      if (_errorText != null) {
                        setState(() => _errorText = null);
                      }
                    },
                  );
                },
              ),

              const SizedBox(height: 20),

              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return PrimaryButton(
                    label: 'Listo',
                    onPressed: _nameIsValid && !_isLoading ? _save : null,
                    isLoading: _isLoading,
                  );
                },
              ),

              const SizedBox(height: 16),

              // Botón secundario "Ahora no"
              Center(
                child: TextButton(
                  onPressed: _isLoading ? null : _skip,
                  child: Text(
                    'Ahora no',
                    style: AppTextStyles.labelSm.copyWith(
                      color: AppColors.neutral500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
