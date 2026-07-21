import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/theme/app_dimens.dart';
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
  bool _obscurePassword = true;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider.select((state) => state.message), (previous, next) {
      if (next != null && next != previous) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(next)));
      }
    });
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final loading = ref.watch(authProvider).loading;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            margin: const EdgeInsets.all(AppSpace.lg),
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.xl),
              child: Form(
                key: formKey,
                child: AutofillGroup(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      Icon(Icons.shopping_bag_rounded,
                          color: colors.primary, size: 42),
                      AppSpace.gapMd,
                      Text(tr(ref, 'Welcome back', 'ยินดีต้อนรับกลับ'),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineMedium),
                      AppSpace.gapSm,
                      Text(
                          tr(ref, 'Sign in to continue shopping.',
                              'เข้าสู่ระบบเพื่อเลือกซื้อสินค้าต่อ'),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: colors.onSurfaceVariant)),
                      AppSpace.gapXl,
                      TextFormField(
                          controller: email,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          decoration: InputDecoration(
                              labelText: tr(ref, 'Email', 'อีเมล'),
                              prefixIcon:
                                  const Icon(Icons.mail_outline_rounded)),
                          validator: (value) => requiredField(
                              value, tr(ref, 'Required', 'จำเป็นต้องกรอก'))),
                      AppSpace.gapMd,
                      TextFormField(
                          controller: password,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          onFieldSubmitted: loading ? null : (_) => submit(),
                          decoration: InputDecoration(
                              labelText: tr(ref, 'Password', 'รหัสผ่าน'),
                              prefixIcon:
                                  const Icon(Icons.lock_outline_rounded),
                              suffixIcon: IconButton(
                                tooltip: _obscurePassword
                                    ? tr(ref, 'Show password', 'แสดงรหัสผ่าน')
                                    : tr(ref, 'Hide password', 'ซ่อนรหัสผ่าน'),
                                icon: Icon(_obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined),
                                onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword),
                              )),
                          validator: (value) => requiredField(
                              value, tr(ref, 'Required', 'จำเป็นต้องกรอก'))),
                      AppSpace.gapLg,
                      ElevatedButton(
                          onPressed: loading ? null : submit,
                          child: Text(loading
                              ? tr(ref, 'Signing in...', 'กำลังเข้าสู่ระบบ...')
                              : tr(ref, 'Login', 'เข้าสู่ระบบ'))),
                      TextButton(
                          onPressed: () {
                            final next = GoRouterState.of(context)
                                .uri
                                .queryParameters['next'];
                            context.go(registerLocationFor(next));
                          },
                          child: Text(tr(ref, "Don't have an account? Register",
                              'ยังไม่มีบัญชี? สมัครสมาชิก'))),
                    ],
                  ),
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
      if (mounted) {
        final next = GoRouterState.of(context).uri.queryParameters['next'];
        context.go(postLoginLocation(next));
      }
    } on DioException catch (e) {
      if (mounted) {
        showError(
            context,
            loginErrorMessage(e,
                thai: ref.read(appSettingsProvider).languageCode == 'th'));
      }
    }
  }
}

String loginErrorMessage(DioException error, {bool thai = false}) {
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.connectionError:
      return thai
          ? 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้ กรุณาลองอีกครั้ง'
          : 'Cannot connect to the server. Please try again.';
    default:
      final data = error.response?.data;
      if (data is Map && data['error'] != null) {
        return data['error'].toString();
      }
      return thai ? 'เข้าสู่ระบบไม่สำเร็จ' : 'Login failed';
  }
}

String? requiredField(String? value, [String message = 'Required']) =>
    value == null || value.trim().isEmpty ? message : null;
void showError(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
