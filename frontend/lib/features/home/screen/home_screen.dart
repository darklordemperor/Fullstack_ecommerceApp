import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/settings/app_settings.dart';
import '../../../core/widget/app_ui.dart';
import '../../auth/provider/auth_provider.dart';
import '../../cart/provider/cart_provider.dart';
import '../../product/provider/product_provider.dart';
import '../../product/widget/product_card.dart';
import '../../../core/theme/app_theme.dart';

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
          IconButton(
            tooltip: tr(ref, 'Profile', 'โปรไฟล์'),
            icon: const Icon(Icons.person_outline_rounded),
            onPressed: () => context.push('/profile'),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                tooltip: tr(ref, 'Cart', 'ตะกร้า'),
                icon: const Icon(Icons.shopping_bag_outlined),
                onPressed: () => context.push('/cart'),
              ),
              Positioned(
                right: 6,
                top: 6,
                child: CircleAvatar(
                  radius: 10,
                  backgroundColor: AppTheme.primary,
                  child: Text(
                    '${cart.valueOrNull?.count ?? 0}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
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
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(ref, 'Discover products', 'เลือกซื้อสินค้า'),
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tr(ref, 'Curated picks from trusted sellers.',
                          'สินค้าคัดสรรจากผู้ขายที่เชื่อถือได้'),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search_rounded),
                        hintText: tr(ref, 'Search products', 'ค้นหาสินค้า'),
                        filled: true,
                      ),
                      textInputAction: TextInputAction.search,
                      onSubmitted: (value) =>
                          ref.read(searchProvider.notifier).state = value,
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Container(
                height: 52,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) => ChoiceChip(
                    label: Text(categoryLabel(ref, categories[i])),
                    selected: selected == categories[i],
                    showCheckmark: false,
                    avatar: selected == categories[i]
                        ? const Icon(Icons.check_rounded, size: 16)
                        : null,
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
                      title: tr(ref, 'No products yet', 'ยังไม่มีสินค้า'),
                      message: tr(
                          ref,
                          'Products will appear here after sellers add them.',
                          'สินค้าจะแสดงที่นี่เมื่อผู้ขายเพิ่มสินค้า'),
                      action: OutlinedButton.icon(
                        onPressed: () => ref.invalidate(productsProvider),
                        icon: const Icon(Icons.refresh),
                        label: Text(tr(ref, 'Refresh', 'รีเฟรช')),
                      ),
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: .64,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
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
    final settings = ref.watch(appSettingsProvider);
    final colors = Theme.of(context).colorScheme;
    return Drawer(
      width: 320,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 54, 20, 24),
            decoration: const BoxDecoration(
              color: AppTheme.text,
              borderRadius: BorderRadius.only(topRight: Radius.circular(28)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: Colors.white,
                  child: ClipOval(
                    child: user?.profileImage?.isNotEmpty == true
                        ? AppProductImage(
                            image: user!.profileImage!, width: 68, height: 68)
                        : Text(user?.initials ?? 'U',
                            style: const TextStyle(
                                color: AppTheme.text,
                                fontWeight: FontWeight.w900,
                                fontSize: 20)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.fullName ?? tr(ref, 'Customer', 'ลูกค้า'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text(user?.email ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: .78),
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              children: [
                _DrawerTile(
                  icon: Icons.home_rounded,
                  label: tr(ref, 'Home', 'หน้าแรก'),
                  selected: true,
                  onTap: () => context.go('/home'),
                ),
                _DrawerTile(
                  icon: Icons.shopping_cart_rounded,
                  label: tr(ref, 'Cart', 'ตะกร้า'),
                  onTap: () => context.push('/cart'),
                ),
                _DrawerTile(
                  icon: Icons.person_rounded,
                  label: tr(ref, 'Profile', 'โปรไฟล์'),
                  onTap: () => context.push('/profile'),
                ),
                if (user?.isApprovedSeller ?? false)
                  _DrawerTile(
                    icon: Icons.storefront_rounded,
                    label: tr(ref, 'Seller Dashboard', 'แดชบอร์ดผู้ขาย'),
                    onTap: () => context.push('/seller'),
                  ),
                if (user?.isAdmin ?? false)
                  _DrawerTile(
                    icon: Icons.admin_panel_settings_rounded,
                    label: tr(ref, 'Admin Dashboard', 'แดชบอร์ดแอดมิน'),
                    onTap: () => context.push('/admin'),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 18, 8, 10),
                  child: Text(
                    tr(ref, 'Preferences', 'ตั้งค่า'),
                    style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w900),
                  ),
                ),
                _SettingTile(
                  icon: settings.themeMode == ThemeMode.dark
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                  title: tr(ref, 'Theme', 'ธีม'),
                  subtitle: settings.themeMode == ThemeMode.dark
                      ? tr(ref, 'Dark', 'มืด')
                      : tr(ref, 'Light', 'สว่าง'),
                  onTap: () =>
                      ref.read(appSettingsProvider.notifier).toggleTheme(),
                ),
                _SettingTile(
                  icon: Icons.language_rounded,
                  title: tr(ref, 'Language', 'ภาษา'),
                  subtitle: settings.languageCode == 'en' ? 'English' : 'ไทย',
                  trailing: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _LanguagePill(
                            label: 'EN',
                            selected: settings.languageCode == 'en'),
                        _LanguagePill(
                            label: 'TH',
                            selected: settings.languageCode == 'th'),
                      ],
                    ),
                  ),
                  onTap: () =>
                      ref.read(appSettingsProvider.notifier).toggleLanguage(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
            child: _DrawerTile(
              icon: Icons.logout_rounded,
              label: tr(ref, 'Logout', 'ออกจากระบบ'),
              danger: true,
              onTap: () async {
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) {
                  context.go('/login');
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = danger
        ? AppTheme.primaryDark
        : selected
            ? Colors.white
            : colors.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: selected
            ? AppTheme.text
            : danger
                ? AppTheme.primary.withValues(alpha: .08)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Icon(icon, color: foreground),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: foreground,
                          fontWeight: FontWeight.w900,
                          fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Icon(icon, color: colors.onSurfaceVariant),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: colors.onSurface)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguagePill extends StatelessWidget {
  const _LanguagePill({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: selected ? colors.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        boxShadow: selected
            ? const [
                BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 8,
                    offset: Offset(0, 3))
              ]
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? AppTheme.primaryDark : colors.onSurfaceVariant,
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
      ),
    );
  }
}
