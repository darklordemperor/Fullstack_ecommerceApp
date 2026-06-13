import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/widget/app_ui.dart';
import '../provider/admin_provider.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(adminStatsProvider);
    final users = ref.watch(adminUsersProvider);
    final products = ref.watch(adminProductsProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Admin Dashboard'),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Color(0xFFFFE1D7),
            indicatorColor: Colors.white,
            tabs: [Tab(text: 'Users'), Tab(text: 'Products')],
          ),
        ),
        body: Column(
          children: [
            stats.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => AppErrorState(
                  message: friendlyError(e),
                  onRetry: () => ref.invalidate(adminStatsProvider)),
              data: (s) => Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Stat(label: 'Users', value: '${s['total_users'] ?? 0}'),
                    _Stat(
                        label: 'Products',
                        value: '${s['total_products'] ?? 0}'),
                    _Stat(label: 'Orders', value: '${s['total_orders'] ?? 0}'),
                    _Stat(
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
                  users.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => AppErrorState(
                        message: friendlyError(e),
                        onRetry: () => ref.invalidate(adminUsersProvider)),
                    data: (items) => ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (_, i) {
                        final user = items[i];
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              child: ClipOval(
                                child: user.profileImage?.isNotEmpty == true
                                    ? AppProductImage(
                                        image: user.profileImage!,
                                        width: 40,
                                        height: 40)
                                    : Text(user.initials),
                              ),
                            ),
                            subtitle:
                                Text('${user.email} - ${user.role.join(', ')}'),
                            trailing: user.isAdmin
                                ? const Chip(label: Text('Admin'))
                                : FilledButton.tonalIcon(
                                    icon: Icon(user.banned
                                        ? Icons.lock_open
                                        : Icons.block),
                                    label: Text(user.banned
                                        ? 'Unban user'
                                        : 'Ban user'),
                                    onPressed: () =>
                                        _setBanned(ref, user.id, !user.banned),
                                  ),
                            isThreeLine: true,
                            dense: false,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            title: Row(
                              children: [
                                Expanded(child: Text(user.fullName)),
                                const SizedBox(width: 8),
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  label:
                                      Text(user.banned ? 'Banned' : 'Active'),
                                  backgroundColor: user.banned
                                      ? Colors.red.shade100
                                      : Colors.green.shade100,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  products.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => AppErrorState(
                        message: friendlyError(e),
                        onRetry: () => ref.invalidate(adminProductsProvider)),
                    data: (items) => ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (_, i) {
                        final product = items[i];
                        return Card(
                          child: ListTile(
                            leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: AppProductImage(
                                    image: product.mainImage,
                                    width: 56,
                                    height: 56)),
                            title: Text(product.name,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                                '${product.sellerName} - ${NumberFormat.currency(locale: 'th_TH', symbol: '\u0E3F').format(product.price)}'),
                            trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () =>
                                    _deleteProduct(ref, product.id)),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setBanned(WidgetRef ref, String userId, bool banned) async {
    await ref.read(adminRepositoryProvider).setBanned(userId, banned);
    refreshAdmin(ref);
  }

  Future<void> _deleteProduct(WidgetRef ref, String productId) async {
    await ref.read(adminRepositoryProvider).deleteProduct(productId);
    refreshAdmin(ref);
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}
