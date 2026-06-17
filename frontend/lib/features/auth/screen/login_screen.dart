import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../provider/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  final formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider.select((state) => state.message), (previous, next) {
      if (next != null && next != previous) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(next)));
      }
    });
    final loading = ref.watch(authProvider).loading;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            margin: const EdgeInsets.all(20),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    const Icon(Icons.shopping_bag_rounded,
                        color: AppTheme.primary, size: 42),
                    const SizedBox(height: 14),
                    Text('Welcome back',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 6),
                    Text('Sign in to continue shopping.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.subtext,
                            )),
                    const SizedBox(height: 24),
                    TextFormField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.mail_outline_rounded)),
                        validator: requiredField),
                    const SizedBox(height: 12),
                    TextFormField(
                        controller: password,
                        obscureText: true,
                        decoration: const InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(Icons.lock_outline_rounded)),
                        validator: requiredField),
                    const SizedBox(height: 20),
                    ElevatedButton(
                        onPressed: loading ? null : submit,
                        child: Text(loading ? 'Signing in...' : 'Login')),
                    TextButton(
                        onPressed: () => context.go('/register'),
                        child: const Text("Don't have an account? Register")),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;
    try {
      await ref
          .read(authProvider.notifier)
          .login(email.text.trim(), password.text);
      if (mounted) context.go('/home');
    } on DioException catch (e) {
      if (mounted) {
        showError(
            context, e.response?.data['error']?.toString() ?? 'Login failed');
      }
    }
  }
}

String? requiredField(String? value) =>
    value == null || value.trim().isEmpty ? 'Required' : null;
void showError(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
