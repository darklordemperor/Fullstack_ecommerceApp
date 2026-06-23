import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/router/app_router.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widget/app_ui.dart';
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
  final address = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();
  final picker = ImagePicker();
  final passwordRegex = RegExp(r'^[a-z0-9]{8,}$');
  String gender = 'Other';
  String profileImage = '';

  @override
  void dispose() {
    name.dispose();
    lastname.dispose();
    age.dispose();
    address.dispose();
    email.dispose();
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(authProvider).loading;
    return Scaffold(
      appBar: AppBar(
          leading: const AppBackButton(fallback: '/login'),
          title: Text(tr(ref, 'Create Account', 'สร้างบัญชี'))),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Form(
              key: formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                          color: AppTheme.primary.withValues(alpha: .16)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(Icons.person_add_alt_1_rounded,
                              color: AppTheme.primaryDark),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(tr(ref, 'Buyer account', 'บัญชีผู้ซื้อ'),
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontSize: 24)),
                              const SizedBox(height: 4),
                              Text(
                                  tr(ref, 'Create your shopping profile.',
                                      'สร้างโปรไฟล์สำหรับการซื้อสินค้า'),
                                  style:
                                      const TextStyle(color: AppTheme.subtext)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  AppInfoPanel(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionTitle(
                          icon: Icons.badge_outlined,
                          title: tr(ref, 'Personal details', 'ข้อมูลส่วนตัว'),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 36,
                              backgroundColor:
                                  AppTheme.primary.withValues(alpha: .10),
                              child: ClipOval(
                                child: profileImage.isEmpty
                                    ? const Icon(
                                        Icons.person_outline_rounded,
                                        color: AppTheme.primaryDark,
                                        size: 34,
                                      )
                                    : AppProductImage(
                                        image: profileImage,
                                        width: 72,
                                        height: 72,
                                      ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tr(ref, 'Profile photo', 'รูปโปรไฟล์'),
                                    style:
                                        Theme.of(context).textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: () => pickProfileImage(
                                            ImageSource.gallery),
                                        icon: const Icon(Icons.photo_outlined),
                                        label: Text(
                                            tr(ref, 'Gallery', 'แกลเลอรี')),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: () => pickProfileImage(
                                            ImageSource.camera),
                                        icon: const Icon(
                                            Icons.photo_camera_outlined),
                                        label: Text(tr(ref, 'Camera', 'กล้อง')),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                            controller: name,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: tr(ref, 'Name', 'ชื่อ'),
                              prefixIcon:
                                  const Icon(Icons.person_outline_rounded),
                            ),
                            validator: (value) => _requiredField(
                                value, tr(ref, 'Required', 'จำเป็นต้องกรอก'))),
                        const SizedBox(height: 12),
                        TextFormField(
                            controller: lastname,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: tr(ref, 'Lastname', 'นามสกุล'),
                              prefixIcon:
                                  const Icon(Icons.person_search_outlined),
                            ),
                            validator: (value) => _requiredField(
                                value, tr(ref, 'Required', 'จำเป็นต้องกรอก'))),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                  controller: age,
                                  textInputAction: TextInputAction.next,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(3),
                                  ],
                                  decoration: InputDecoration(
                                    labelText: tr(ref, 'Age', 'อายุ'),
                                    prefixIcon: const Icon(Icons.cake_outlined),
                                  ),
                                  validator: (v) =>
                                      (int.tryParse(v ?? '') ?? 0) < 18
                                          ? tr(ref, 'Must be at least 18',
                                              'ต้องมีอายุอย่างน้อย 18 ปี')
                                          : null),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: gender,
                                decoration: InputDecoration(
                                  labelText: tr(ref, 'Gender', 'เพศ'),
                                  prefixIcon: const Icon(Icons.wc_outlined),
                                ),
                                items: const ['Female', 'Male', 'Other']
                                    .map((value) => DropdownMenuItem(
                                        value: value,
                                        child: Text(genderLabel(ref, value))))
                                    .toList(),
                                onChanged: (value) =>
                                    setState(() => gender = value ?? gender),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                            controller: address,
                            minLines: 2,
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText:
                                  tr(ref, 'Delivery address', 'ที่อยู่จัดส่ง'),
                              prefixIcon:
                                  const Icon(Icons.location_on_outlined),
                            ),
                            validator: (value) => _requiredField(
                                value, tr(ref, 'Required', 'จำเป็นต้องกรอก'))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  AppInfoPanel(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionTitle(
                          icon: Icons.lock_outline_rounded,
                          title:
                              tr(ref, 'Sign-in details', 'ข้อมูลเข้าสู่ระบบ'),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                            controller: email,
                            textInputAction: TextInputAction.next,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: tr(ref, 'Email', 'อีเมล'),
                              prefixIcon:
                                  const Icon(Icons.mail_outline_rounded),
                            ),
                            validator: (v) => (v ?? '').contains('@')
                                ? null
                                : tr(ref, 'Valid email required',
                                    'กรุณากรอกอีเมลให้ถูกต้อง')),
                        const SizedBox(height: 12),
                        TextFormField(
                            controller: password,
                            textInputAction: TextInputAction.next,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: tr(ref, 'Password', 'รหัสผ่าน'),
                              helperText: tr(
                                  ref,
                                  'Lowercase letters and numbers only, min 8 characters',
                                  'ใช้ตัวพิมพ์เล็กและตัวเลขเท่านั้น อย่างน้อย 8 ตัว'),
                              prefixIcon: const Icon(Icons.password_rounded),
                            ),
                            validator: (v) => passwordRegex.hasMatch(v ?? '')
                                ? null
                                : tr(ref, 'Invalid password',
                                    'รหัสผ่านไม่ถูกต้อง')),
                        const SizedBox(height: 12),
                        TextFormField(
                            controller: confirm,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText:
                                  tr(ref, 'Confirm Password', 'ยืนยันรหัสผ่าน'),
                              prefixIcon:
                                  const Icon(Icons.verified_user_outlined),
                            ),
                            validator: (v) => v == password.text
                                ? null
                                : tr(ref, 'Passwords must match',
                                    'รหัสผ่านต้องตรงกัน')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: loading ? null : submit,
                    icon: loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_forward_rounded),
                    label: Text(loading
                        ? tr(ref, 'Creating...', 'กำลังสร้างบัญชี...')
                        : tr(ref, 'Create account', 'สร้างบัญชี')),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                      onPressed: () => context.go('/login'),
                      child: Text(tr(ref, 'Already have an account? Login',
                          'มีบัญชีอยู่แล้ว? เข้าสู่ระบบ'))),
                ],
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
      await ref.read(authProvider.notifier).register({
        'name': name.text.trim(),
        'lastname': lastname.text.trim(),
        'age': int.parse(age.text),
        'gender': gender,
        'address': address.text.trim(),
        'profile_image': profileImage,
        'email': email.text.trim(),
        'password': password.text,
        'confirm_password': confirm.text,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr(ref, 'Account created. You are signed in.',
                'สร้างบัญชีแล้ว เข้าสู่ระบบเรียบร้อย'))));
        final next = GoRouterState.of(context).uri.queryParameters['next'];
        context.go(postLoginLocation(next));
      }
    } on DioException catch (e) {
      if (mounted) {
        _showError(
            context,
            e.response?.data['error']?.toString() ??
                tr(ref, 'Registration failed', 'สมัครสมาชิกไม่สำเร็จ'));
      }
    }
  }

  Future<void> pickProfileImage(ImageSource source) async {
    if (!await ensureImagePermission(context, source)) return;
    final picked =
        await picker.pickImage(source: source, imageQuality: 78, maxWidth: 800);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      profileImage = profileImageDataUri(bytes);
    });
  }
}

String profileImageDataUri(List<int> bytes) {
  return 'data:image/jpeg;base64,${base64Encode(bytes)}';
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 19, color: AppTheme.primaryDark),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

String? _requiredField(String? value, [String message = 'Required']) {
  return value == null || value.trim().isEmpty ? message : null;
}

void _showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
