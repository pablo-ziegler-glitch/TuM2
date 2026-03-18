import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../providers/auth_providers.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    final uid = await ref.read(authNotifierProvider.notifier).register(
          email: _emailController.text,
          password: _passwordController.text,
          displayName: _nameController.text,
        );

    if (!mounted) return;

    final authState = ref.read(authNotifierProvider);
    authState.whenOrNull(
      error: (e, _) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_friendlyError(e)),
            backgroundColor: TuM2Colors.error,
          ),
        );
      },
    );

    if (uid != null) {
      context.go('/auth/role-select');
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('email-already-in-use')) {
      return 'Ya existe una cuenta con ese email.';
    }
    if (msg.contains('weak-password')) {
      return 'La contraseña es muy débil.';
    }
    if (msg.contains('network')) {
      return 'Sin conexión. Revisá tu red.';
    }
    return 'No pudimos crear tu cuenta. Intentá de nuevo.';
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bienvenido a TuM2',
                  style: TuM2TextStyles.headlineLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Creá tu cuenta para acceder al comercio de tu zona.',
                  style: TuM2TextStyles.bodyMedium
                      .copyWith(color: TuM2Colors.onSurfaceVariant),
                ),
                const SizedBox(height: 32),
                // Name
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Ingresá tu nombre';
                    if (v.trim().length < 2) return 'Nombre demasiado corto';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Ingresá tu email';
                    if (!v.contains('@')) return 'Email inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Password
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _register(),
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock_outline),
                    helperText:
                        'Mínimo ${AppConstants.minPasswordLength} caracteres',
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Ingresá una contraseña';
                    if (v.length < AppConstants.minPasswordLength) {
                      return 'Mínimo ${AppConstants.minPasswordLength} caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: isLoading ? null : _register,
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Crear cuenta'),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '¿Ya tenés cuenta? ',
                      style: TuM2TextStyles.bodyMedium,
                    ),
                    TextButton(
                      onPressed: () => context.go('/auth/login'),
                      child: const Text('Iniciá sesión'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
