import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/provider/auth_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool editing = false;
  final name = TextEditingController();
  final lastname = TextEditingController();
  final age = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    name.text = editing && name.text.isNotEmpty ? name.text : user.name;
    lastname.text = editing && lastname.text.isNotEmpty ? lastname.text : user.lastname;
    age.text = editing && age.text.isNotEmpty ? age.text : '${user.age}';
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        CircleAvatar(radius: 44, child: Text(user.initials, style: const TextStyle(fontSize: 28))),
        const SizedBox(height: 12),
        Center(child: Text(user.fullName, style: Theme.of(context).textTheme.titleLarge)),
        Center(child: Text(user.email)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, alignment: WrapAlignment.center, children: user.role.map((r) => Chip(label: Text(r))).toList()),
        if (editing) ...[
          const SizedBox(height: 16),
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 8),
          TextField(controller: lastname, decoration: const InputDecoration(labelText: 'Lastname')),
          const SizedBox(height: 8),
          TextField(controller: age, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Age')),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: () async { await ref.read(authRepositoryProvider).updateProfile(name.text, lastname.text, int.parse(age.text)); await ref.read(authProvider.notifier).refreshMe(); setState(() => editing = false); }, child: const Text('Save Profile')),
        ] else ...[
          const SizedBox(height: 16),
          ElevatedButton(onPressed: () => setState(() => editing = true), child: const Text('Edit Profile')),
        ],
        if (user.role.length == 1 && user.sellerStatus != 'pending') TextButton(onPressed: () => context.go('/seller-apply'), child: const Text('Apply as Seller')),
        if (user.sellerStatus == 'pending') const Center(child: Chip(label: Text('Seller application pending'))),
        const SizedBox(height: 24),
        OutlinedButton(onPressed: () async { await ref.read(authProvider.notifier).logout(); if (context.mounted) context.go('/login'); }, child: const Text('Logout')),
      ]),
    );
  }
}
