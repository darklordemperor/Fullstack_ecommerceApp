import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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
        appBar: AppBar(title: const Text('Seller Dashboard'), bottom: const TabBar(tabs: [Tab(text: 'My Products'), Tab(text: 'Orders')])),
        floatingActionButton: FloatingActionButton(onPressed: () => context.go('/seller/product'), child: const Icon(Icons.add)),
        body: Column(children: [
          stats.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Padding(padding: const EdgeInsets.all(12), child: Text(e.toString())),
            data: (s) => Padding(
              padding: const EdgeInsets.all(8),
              child: Row(children: [
                _StatCard(label: 'Total Products', value: '${s['total_products'] ?? 0}'),
                _StatCard(label: 'Total Orders', value: '${s['total_orders'] ?? 0}'),
                _StatCard(label: 'Total Revenue', value: NumberFormat.currency(locale: 'th_TH', symbol: '฿').format(s['total_revenue'] ?? 0)),
              ]),
            ),
          ),
          Expanded(
            child: TabBarView(children: [
              products.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text(e.toString())),
                data: (items) => ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (_, i) => Card(
                    child: ListTile(
                      leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: CachedNetworkImage(imageUrl: items[i].mainImage, width: 60, height: 60, fit: BoxFit.cover)),
                      title: Text(items[i].name),
                      subtitle: Text('${NumberFormat.currency(locale: 'th_TH', symbol: '฿').format(items[i].price)} • Stock ${items[i].stock}'),
                      trailing: Wrap(children: [
                        IconButton(icon: const Icon(Icons.edit), onPressed: () => context.go('/seller/product?id=${items[i].id}')),
                        IconButton(icon: const Icon(Icons.delete), onPressed: () => _confirmDelete(context, ref, items[i].id)),
                      ]),
                    ),
                  ),
                ),
              ),
              orders.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text(e.toString())),
                data: (items) => ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final order = items[i];
                    final list = order['items'] as List? ?? const [];
                    return Card(
                      child: ListTile(
                        title: Text(order['customer_name']?.toString() ?? 'Customer'),
                        subtitle: Text('${list.length} items • ${NumberFormat.currency(locale: 'th_TH', symbol: '฿').format(order['total'] ?? 0)}'),
                        trailing: Chip(label: Text(order['status']?.toString() ?? 'pending')),
                      ),
                    );
                  },
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete product?'),
        content: const Text('This product will be removed from your shop.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete'))],
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
          padding: const EdgeInsets.all(12),
          child: Column(children: [Text(value, style: const TextStyle(fontWeight: FontWeight.bold)), Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))]),
        ),
      ),
    );
  }
}
