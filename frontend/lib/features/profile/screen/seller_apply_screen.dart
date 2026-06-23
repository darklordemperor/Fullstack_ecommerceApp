import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/settings/app_settings.dart';
import '../../../core/widget/app_ui.dart';
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
      appBar: AppBar(
          leading: const AppBackButton(fallback: '/profile'),
          title: Text(tr(ref, 'Apply as Seller', 'สมัครเป็นผู้ขาย'))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(
            controller: shop,
            decoration:
                InputDecoration(labelText: tr(ref, 'Shop Name', 'ชื่อร้าน'))),
        const SizedBox(height: 12),
        TextField(
            controller: location,
            decoration: InputDecoration(
                labelText: tr(ref, 'Shop Location', 'ที่ตั้งร้าน'))),
        const SizedBox(height: 12),
        TextField(
            controller: tax,
            decoration: InputDecoration(
                labelText:
                    tr(ref, 'Tax Payer Number', 'เลขประจำตัวผู้เสียภาษี'))),
        const SizedBox(height: 12),
        Text(tr(
            ref,
            'Your application will be reviewed. This is for verification purposes.',
            'ใบสมัครของคุณจะถูกตรวจสอบเพื่อยืนยันข้อมูลผู้ขาย')),
        const SizedBox(height: 20),
        ElevatedButton(
            onPressed: () async {
              await ref
                  .read(authRepositoryProvider)
                  .applySeller(shop.text, location.text, tax.text);
              await ref.read(authProvider.notifier).refreshMe();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                        tr(ref, 'Application submitted', 'ส่งใบสมัครแล้ว'))));
                context.go('/home');
              }
            },
            child: Text(tr(ref, 'Submit', 'ส่งข้อมูล'))),
      ]),
    );
  }
}
