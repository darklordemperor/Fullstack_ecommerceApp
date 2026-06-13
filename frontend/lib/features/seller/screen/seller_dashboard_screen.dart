import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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
          title: const Text('Seller Dashboard'),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Color(0xFFFFE1D7),
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            tabs: [Tab(text: 'My Products'), Tab(text: 'Orders')],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push('/seller/product'),
          icon: const Icon(Icons.add),
          label: const Text('Product'),
        ),
        body: Column(
          children: [
            stats.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(12),
                child: AppErrorState(
                    message: friendlyError(e),
                    onRetry: () => ref.invalidate(sellerStatsProvider)),
              ),
              data: (s) => Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    _StatCard(
                        label: 'Products',
                        value: '${s['total_products'] ?? 0}'),
                    _StatCard(
                        label: 'Orders', value: '${s['total_orders'] ?? 0}'),
                    _StatCard(
                        label: 'Revenue',
                        value: NumberFormat.currency(
                                locale: 'th_TH', symbol: '\u0E3F')
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
                          title: 'No products yet',
                          message:
                              'Create your first product to start selling.',
                          action: FilledButton.icon(
                              onPressed: () => context.push('/seller/product'),
                              icon: const Icon(Icons.add),
                              label: const Text('Create product')),
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
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
                                '${NumberFormat.currency(locale: 'th_TH', symbol: '\u0E3F').format(items[i].price)} - Stock ${items[i].stock}'),
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
                        return const AppEmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: 'No orders yet',
                          message: 'Orders from customers will appear here.',
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: items.length,
                        itemBuilder: (_, i) {
                          final order = items[i];
                          final list = order['items'] as List? ?? const [];
                          return Card(
                            child: ListTile(
                              title: Text(order['customer_name']?.toString() ??
                                  'Customer'),
                              subtitle: Text(
                                  '${list.length} items - ${NumberFormat.currency(locale: 'th_TH', symbol: '\u0E3F').format(order['total'] ?? 0)}'),
                              trailing: Chip(
                                  label: Text(order['status']?.toString() ??
                                      'pending')),
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
        title: const Text('Delete product?'),
        content: const Text('This product will be removed from your shop.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(productRepositoryProvider).delete(id);
      await refreshSeller(ref);
    }
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
              const SizedBox(height: 4),
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
