import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/provider/auth_provider.dart';

class SellerApplyScreen extends ConsumerStatefulWidget {
  const SellerApplyScreen({super.key});

  @override
  ConsumerState<SellerApplyScreen> createState() => _SellerApplyScreenState();
}

class _SellerApplyScreenState extends ConsumerState<SellerApplyScreen> {
  final shop = TextEditingController();
  final location = TextEditingController();
  final tax = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Apply as Seller')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(controller: shop, decoration: const InputDecoration(labelText: 'Shop Name')),
        const SizedBox(height: 12),
        TextField(controller: location, decoration: const InputDecoration(labelText: 'Shop Location')),
        const SizedBox(height: 12),
        TextField(controller: tax, decoration: const InputDecoration(labelText: 'Tax Payer Number')),
        const SizedBox(height: 12),
        const Text('Your application will be reviewed. This is for verification purposes.'),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: () async { await ref.read(authRepositoryProvider).applySeller(shop.text, location.text, tax.text); await ref.read(authProvider.notifier).refreshMe(); if (context.mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Application submitted'))); context.go('/profile'); } }, child: const Text('Submit')),
      ]),
    );
  }
}
