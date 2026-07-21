import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/settings/app_settings.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/widget/app_ui.dart';
import '../../product/provider/product_provider.dart';
import '../provider/seller_provider.dart';

class SellerDashboardScreen extends ConsumerWidget {
  const SellerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(sellerStatsProvider);
    final products = ref.watch(sellerProductsProvider);
    final orders = ref.watch(sellerOrdersProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(),
          title: Text(tr(ref, 'Seller Dashboard', 'แดชบอร์ดผู้ขาย')),
          bottom: AppSegmentedTabBar(
            tabs: [
              Tab(
                child: _TabLabel(
                    icon: Icons.inventory_2_outlined,
                    label: tr(ref, 'Products', 'สินค้า')),
              ),
              Tab(
                child: _TabLabel(
                    icon: Icons.receipt_long_outlined,
                    label: tr(ref, 'Orders', 'คำสั่งซื้อ')),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push('/seller/product'),
          icon: const Icon(Icons.add),
          label: Text(tr(ref, 'Product', 'สินค้า')),
        ),
        body: Column(
          children: [
            stats.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(AppSpace.md),
                child: AppErrorState(
                    message: friendlyError(e),
                    onRetry: () => ref.invalidate(sellerStatsProvider)),
              ),
              data: (s) => Padding(
                padding: const EdgeInsets.all(AppSpace.md),
                child: Row(
                  children: [
                    _StatCard(
                        label: tr(ref, 'Products', 'สินค้า'),
                        value: '${s['total_products'] ?? 0}'),
                    _StatCard(
                        label: tr(ref, 'Orders', 'คำสั่งซื้อ'),
                        value: '${s['total_orders'] ?? 0}'),
                    _StatCard(
                        label: tr(ref, 'Revenue', 'รายได้'),
                        value: NumberFormat.currency(
                                locale: moneyLocale(ref), symbol: '\u0E3F')
                            .format(s['total_revenue'] ?? 0)),
                  ],
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  products.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => AppErrorState(
                        message: friendlyError(e),
                        onRetry: () => ref.invalidate(sellerProductsProvider)),
                    data: (items) {
                      if (items.isEmpty) {
                        return AppEmptyState(
                          icon: Icons.add_business_outlined,
                          title: tr(ref, 'No products yet', 'ยังไม่มีสินค้า'),
                          message: tr(
                              ref,
                              'Create your first product to start selling.',
                              'สร้างสินค้าชิ้นแรกเพื่อเริ่มขาย'),
                          action: FilledButton.icon(
                              onPressed: () => context.push('/seller/product'),
                              icon: const Icon(Icons.add),
                              label: Text(
                                  tr(ref, 'Create product', 'สร้างสินค้า'))),
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => AppSpace.gapSm,
                        itemBuilder: (_, i) => Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(10),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: AppProductImage(
                                  image: items[i].mainImage,
                                  width: 60,
                                  height: 60),
                            ),
                            title: Text(items[i].name,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                                '${NumberFormat.currency(locale: moneyLocale(ref), symbol: '\u0E3F').format(items[i].price)} - ${tr(ref, 'Stock', 'คงเหลือ')} ${items[i].stock}'),
                            trailing: Wrap(
                              children: [
                                IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () => context.push(
                                        '/seller/product?id=${items[i].id}')),
                                IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => _confirmDelete(
                                        context, ref, items[i].id)),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  orders.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => AppErrorState(
                        message: friendlyError(e),
                        onRetry: () => ref.invalidate(sellerOrdersProvider)),
                    data: (items) {
                      if (items.isEmpty) {
                        return AppEmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: tr(ref, 'No orders yet', 'ยังไม่มีคำสั่งซื้อ'),
                          message: tr(
                              ref,
                              'Orders from customers will appear here.',
                              'คำสั่งซื้อจากลูกค้าจะแสดงที่นี่'),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.all(AppSpace.md),
                        itemCount: items.length,
                        itemBuilder: (_, i) {
                          final order = items[i];
                          final list = order['items'] as List? ?? const [];
                          return Card(
                            child: ListTile(
                              title: Text(order['customer_name']?.toString() ??
                                  tr(ref, 'Customer', 'ลูกค้า')),
                              subtitle: Text(
                                  '${list.length} ${tr(ref, 'items', 'รายการ')} - ${NumberFormat.currency(locale: moneyLocale(ref), symbol: '\u0E3F').format(order['total'] ?? 0)}'),
                              trailing: Chip(
                                  label: Text(sellerStatusLabel(
                                      ref,
                                      order['status']?.toString() ??
                                          'pending'))),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr(ref, 'Delete product?', 'ลบสินค้า?')),
        content: Text(tr(ref, 'This product will be removed from your shop.',
            'สินค้านี้จะถูกลบออกจากร้านของคุณ')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr(ref, 'Cancel', 'ยกเลิก'))),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(tr(ref, 'Delete', 'ลบ'))),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(productRepositoryProvider).delete(id);
      refreshSeller(ref);
    }
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18),
        AppSpace.gapSm,
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
          child: Column(
            children: [
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              AppSpace.gapXs,
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
