import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/settings/app_settings.dart';
import '../../../core/widget/app_ui.dart';
import '../../auth/provider/auth_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final picker = ImagePicker();
  bool editing = false;
  final name = TextEditingController();
  final lastname = TextEditingController();
  final age = TextEditingController();
  final address = TextEditingController();
  String gender = 'Other';
  String profileImage = '';

  @override
  void dispose() {
    name.dispose();
    lastname.dispose();
    age.dispose();
    address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!editing) {
      name.text = user.name;
      lastname.text = user.lastname;
      age.text = '${user.age}';
      address.text = user.address ?? '';
      gender = user.gender.isEmpty ? 'Other' : user.gender;
      profileImage = user.profileImage ?? '';
    }

    return Scaffold(
      appBar: AppBar(
          leading: const AppBackButton(),
          title: Text(tr(ref, 'Profile', 'โปรไฟล์'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 48,
                  child: ClipOval(
                    child: profileImage.isEmpty
                        ? Center(
                            child: Text(user.initials,
                                style: const TextStyle(fontSize: 28)))
                        : AppProductImage(
                            image: profileImage, width: 96, height: 96),
                  ),
                ),
                if (editing)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: IconButton.filled(
                      icon: const Icon(Icons.photo_camera_outlined),
                      onPressed: pickProfileImage,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Center(
              child: Text(user.fullName,
                  style: Theme.of(context).textTheme.titleLarge)),
          Center(child: Text(user.email)),
          const SizedBox(height: 12),
          Wrap(
              spacing: 8,
              alignment: WrapAlignment.center,
              children: user.role
                  .map((r) => Chip(label: Text(roleLabel(ref, r))))
                  .toList()),
          if (editing) ...[
            const SizedBox(height: 16),
            TextField(
                controller: name,
                decoration:
                    InputDecoration(labelText: tr(ref, 'Name', 'ชื่อ'))),
            const SizedBox(height: 8),
            TextField(
                controller: lastname,
                decoration:
                    InputDecoration(labelText: tr(ref, 'Lastname', 'นามสกุล'))),
            const SizedBox(height: 8),
            TextField(
              controller: age,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(labelText: tr(ref, 'Age', 'อายุ')),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: gender,
              decoration: InputDecoration(labelText: tr(ref, 'Gender', 'เพศ')),
              items: const ['Female', 'Male', 'Other']
                  .map((value) => DropdownMenuItem(
                      value: value, child: Text(genderLabel(ref, value))))
                  .toList(),
              onChanged: (value) => setState(() => gender = value ?? gender),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: address,
              minLines: 2,
              maxLines: 3,
              decoration: InputDecoration(
                  labelText: tr(ref, 'Delivery address', 'ที่อยู่จัดส่ง')),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
                onPressed: saveProfile,
                child: Text(tr(ref, 'Save Profile', 'บันทึกโปรไฟล์'))),
          ] else ...[
            const SizedBox(height: 16),
            _InfoTile(
                icon: Icons.cake_outlined,
                label: tr(ref, 'Age', 'อายุ'),
                value: '${user.age}'),
            _InfoTile(
                icon: Icons.person_outline,
                label: tr(ref, 'Gender', 'เพศ'),
                value: user.gender.isEmpty
                    ? tr(ref, 'Not set', 'ยังไม่ได้ตั้งค่า')
                    : genderLabel(ref, user.gender)),
            _InfoTile(
                icon: Icons.location_on_outlined,
                label: tr(ref, 'Address', 'ที่อยู่'),
                value: user.address?.isNotEmpty == true
                    ? user.address!
                    : tr(ref, 'Not set', 'ยังไม่ได้ตั้งค่า')),
            const SizedBox(height: 16),
            ElevatedButton(
                onPressed: () => setState(() => editing = true),
                child: Text(tr(ref, 'Edit Profile', 'แก้ไขโปรไฟล์'))),
          ],
          if (user.role.length == 1 && user.sellerStatus != 'pending')
            TextButton(
                onPressed: () => context.push('/seller-apply'),
                child: Text(tr(ref, 'Apply as Seller', 'สมัครเป็นผู้ขาย'))),
          if (user.sellerStatus == 'pending')
            Center(
                child: Chip(
                    label: Text(tr(ref, 'Seller application pending',
                        'ใบสมัครผู้ขายรอตรวจสอบ')))),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
            child: Text(tr(ref, 'Logout', 'ออกจากระบบ')),
          ),
        ],
      ),
    );
  }

  Future<void> pickProfileImage() async {
    if (!await ensureImagePermission(context, ImageSource.gallery)) return;
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 78, maxWidth: 800);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      profileImage = 'data:image/jpeg;base64,${base64Encode(bytes)}';
    });
  }

  Future<void> saveProfile() async {
    final parsedAge = int.tryParse(age.text);
    if (name.text.trim().isEmpty ||
        lastname.text.trim().isEmpty ||
        parsedAge == null ||
        parsedAge < 18 ||
        address.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr(
              ref,
              'Please complete name, age, gender, and address.',
              'กรุณากรอกชื่อ อายุ เพศ และที่อยู่ให้ครบถ้วน'))));
      return;
    }
    await ref.read(authProvider.notifier).updateProfile({
      'name': name.text.trim(),
      'lastname': lastname.text.trim(),
      'age': parsedAge,
      'gender': gender,
      'address': address.text.trim(),
      'profile_image': profileImage,
    });
    if (mounted) setState(() => editing = false);
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile(
      {required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(value),
    );
  }
}
