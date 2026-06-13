import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/settings/app_settings.dart';
import '../../../core/widget/app_ui.dart';
import '../../auth/provider/auth_provider.dart';
import '../../cart/provider/cart_provider.dart';
import '../../product/provider/product_provider.dart';
import '../../product/widget/product_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});
  static const categories = [
    'All',
    'Electronics',
    'Fashion',
    'Food',
    'Sports',
    'Beauty',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final products = ref.watch(productsProvider);
    final selected = ref.watch(categoryProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('ShopApp'),
        actions: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: () => context.push('/cart'),
              ),
              Positioned(
                right: 6,
                top: 6,
                child: CircleAvatar(
                  radius: 9,
                  child: Text(
                    '${cart.valueOrNull?.count ?? 0}',
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      drawer: const ShopDrawer(),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(productsProvider);
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search products',
                    filled: true,
                  ),
                  onSubmitted: (value) =>
                      ref.read(searchProvider.notifier).state = value,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 48,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => ChoiceChip(
                    label: Text(categories[i]),
                    selected: selected == categories[i],
                    onSelected: (_) {
                      ref.read(categoryProvider.notifier).state = categories[i];
                    },
                  ),
                ),
              ),
            ),
            products.when(
              data: (items) {
                if (items.isEmpty) {
                  return SliverFillRemaining(
                    child: AppEmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'No products yet',
                      message:
                          'Products will appear here after sellers add them.',
                      action: OutlinedButton.icon(
                        onPressed: () => ref.invalidate(productsProvider),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh'),
                      ),
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.all(8),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: .68,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => ProductCard(
                        product: items[i],
                        onTap: () => context.push('/products/${items[i].id}'),
                      ),
                      childCount: items.length,
                    ),
                  ),
                );
              },
              loading: () => const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator())),
              error: (e, _) => SliverFillRemaining(
                child: AppErrorState(
                  message: friendlyError(e),
                  onRetry: () => ref.invalidate(productsProvider),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ShopDrawer extends ConsumerWidget {
  const ShopDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            currentAccountPicture: CircleAvatar(
              child: ClipOval(
                child: user?.profileImage?.isNotEmpty == true
                    ? AppProductImage(
                        image: user!.profileImage!, width: 72, height: 72)
                    : Text(user?.initials ?? 'U'),
              ),
            ),
            accountName: Text(user?.fullName ?? 'Customer'),
            accountEmail: Text(user?.email ?? ''),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Home'),
            onTap: () => context.go('/home'),
          ),
          ListTile(
            leading: const Icon(Icons.shopping_cart),
            title: const Text('Cart'),
            onTap: () => context.push('/cart'),
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Profile'),
            onTap: () => context.push('/profile'),
          ),
          if (user?.isApprovedSeller ?? false)
            ListTile(
              leading: const Icon(Icons.store),
              title: const Text('Seller Dashboard'),
              onTap: () => context.push('/seller'),
            ),
          if (user?.isAdmin ?? false)
            ListTile(
              leading: const Icon(Icons.admin_panel_settings_outlined),
              title: const Text('Admin Dashboard'),
              onTap: () => context.push('/admin'),
            ),
          const Divider(),
          ListTile(
            leading: Icon(
                ref.watch(appSettingsProvider).themeMode == ThemeMode.dark
                    ? Icons.dark_mode
                    : Icons.light_mode),
            title: Text(tr(ref, 'Theme', 'ธีม')),
            subtitle: Text(
                ref.watch(appSettingsProvider).themeMode == ThemeMode.dark
                    ? tr(ref, 'Dark', 'มืด')
                    : tr(ref, 'Light', 'สว่าง')),
            onTap: () => ref.read(appSettingsProvider.notifier).toggleTheme(),
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(tr(ref, 'Language', 'ภาษา')),
            subtitle: Text(ref.watch(appSettingsProvider).languageCode == 'en'
                ? 'English'
                : 'ไทย'),
            onTap: () =>
                ref.read(appSettingsProvider.notifier).toggleLanguage(),
          ),
          const Spacer(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
        ],
      ),
    );
  }
}
