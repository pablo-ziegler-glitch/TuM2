import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    await ref.read(authNotifierProvider.notifier).signIn(
          _emailController.text,
          _passwordController.text,
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
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('user-not-found') || msg.contains('wrong-password')) {
      return 'Email o contraseña incorrectos.';
    }
    if (msg.contains('too-many-requests')) {
      return 'Demasiados intentos. Intentá de nuevo en unos minutos.';
    }
    if (msg.contains('network')) {
      return 'Sin conexión. Revisá tu red.';
    }
    return 'No pudimos iniciar sesión. Intentá de nuevo.';
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 48),
                // Logo / Brand
                Text(
                  'TuM2',
                  style: TuM2TextStyles.displayLarge.copyWith(
                    color: TuM2Colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tu metro cuadrado',
                  style: TuM2TextStyles.bodyLarge.copyWith(
                    color: TuM2Colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 48),
                Text('Iniciar sesión',
                    style: TuM2TextStyles.headlineLarge.copyWith(
                      color: TuM2Colors.onBackground,
                    )),
                const SizedBox(height: 24),
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
                  onFieldSubmitted: (_) => _signIn(),
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Ingresá tu contraseña';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => _showResetDialog(context),
                    child: const Text('¿Olvidaste tu contraseña?'),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: isLoading ? null : _signIn,
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Entrar'),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => context.push('/auth/register'),
                  child: const Text('Crear cuenta'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showResetDialog(BuildContext context) {
    final resetController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recuperar contraseña'),
        content: TextField(
          controller: resetController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Tu email'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(authNotifierProvider.notifier)
                  .sendPasswordReset(resetController.text);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Revisá tu email para recuperar tu contraseña'),
                ),
              );
            },
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
  }
}
