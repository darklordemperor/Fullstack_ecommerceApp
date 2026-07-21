import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/settings/app_settings.dart';
import '../../../core/theme/app_dimens.dart';
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
          title: Text(tr(ref, 'Admin Dashboard', 'แดชบอร์ดแอดมิน')),
          bottom: AppSegmentedTabBar(
            tabs: [
              Tab(
                child: _TabLabel(
                    icon: Icons.group_outlined,
                    label: tr(ref, 'Users', 'ผู้ใช้')),
              ),
              Tab(
                child: _TabLabel(
                    icon: Icons.inventory_2_outlined,
                    label: tr(ref, 'Products', 'สินค้า')),
              ),
            ],
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
                padding: const EdgeInsets.all(AppSpace.md),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Stat(
                        label: tr(ref, 'Users', 'ผู้ใช้'),
                        value: '${s['total_users'] ?? 0}'),
                    _Stat(
                        label: tr(ref, 'Products', 'สินค้า'),
                        value: '${s['total_products'] ?? 0}'),
                    _Stat(
                        label: tr(ref, 'Orders', 'คำสั่งซื้อ'),
                        value: '${s['total_orders'] ?? 0}'),
                    _Stat(
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
                            subtitle: Text(
                                '${user.email} - ${user.role.map((role) => roleLabel(ref, role)).join(', ')}'),
                            trailing: user.isAdmin
                                ? Chip(label: Text(roleLabel(ref, 'admin')))
                                : FilledButton.tonalIcon(
                                    icon: Icon(user.banned
                                        ? Icons.lock_open
                                        : Icons.block),
                                    label: Text(user.banned
                                        ? tr(ref, 'Unban user', 'ปลดแบนผู้ใช้')
                                        : tr(ref, 'Ban user', 'แบนผู้ใช้')),
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
                                AppSpace.gapSm,
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  label: Text(user.banned
                                      ? tr(ref, 'Banned', 'ถูกแบน')
                                      : tr(ref, 'Active', 'ใช้งานอยู่')),
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
                                '${product.sellerName} - ${NumberFormat.currency(locale: moneyLocale(ref), symbol: '\u0E3F').format(product.price)}'),
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
          padding: const EdgeInsets.all(AppSpace.md),
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
