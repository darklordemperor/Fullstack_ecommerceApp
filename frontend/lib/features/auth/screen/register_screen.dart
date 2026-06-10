import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../provider/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final lastname = TextEditingController();
  final age = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();
  final passwordRegex = RegExp(r'^[a-z0-9]{8,}$');

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(authProvider).loading;
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Form(
            key: formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                TextFormField(controller: name, decoration: const InputDecoration(labelText: 'Name'), validator: _requiredField),
                const SizedBox(height: 12),
                TextFormField(controller: lastname, decoration: const InputDecoration(labelText: 'Lastname'), validator: _requiredField),
                const SizedBox(height: 12),
                TextFormField(controller: age, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Age'), validator: (v) => (int.tryParse(v ?? '') ?? 0) < 18 ? 'Must be at least 18' : null),
                const SizedBox(height: 12),
                TextFormField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email'), validator: (v) => (v ?? '').contains('@') ? null : 'Valid email required'),
                const SizedBox(height: 12),
                TextFormField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Password', helperText: 'Lowercase letters and numbers only, min 8 characters'), validator: (v) => passwordRegex.hasMatch(v ?? '') ? null : 'Invalid password'),
                const SizedBox(height: 12),
                TextFormField(controller: confirm, obscureText: true, decoration: const InputDecoration(labelText: 'Confirm Password'), validator: (v) => v == password.text ? null : 'Passwords must match'),
                const SizedBox(height: 20),
                ElevatedButton(onPressed: loading ? null : submit, child: Text(loading ? 'Creating...' : 'Register')),
                TextButton(onPressed: () => context.go('/login'), child: const Text('Already have an account? Login')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;
    try {
      await ref.read(authProvider.notifier).register({
        'name': name.text.trim(),
        'lastname': lastname.text.trim(),
        'age': int.parse(age.text),
        'email': email.text.trim(),
        'password': password.text,
        'confirm_password': confirm.text,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account created. Please log in.')));
        context.go('/login');
      }
    } on DioException catch (e) {
      if (mounted) _showError(context, e.response?.data['error']?.toString() ?? 'Registration failed');
    }
  }
}

String? _requiredField(String? value) {
  return value == null || value.trim().isEmpty ? 'Required' : null;
}

void _showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
