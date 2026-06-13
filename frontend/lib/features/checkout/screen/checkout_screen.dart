import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widget/app_ui.dart';
import '../../auth/provider/auth_provider.dart';
import '../../cart/model/cart_model.dart';
import '../../cart/provider/cart_provider.dart';
import '../../product/model/product_model.dart';
import '../../product/provider/product_provider.dart';
import '../../seller/provider/seller_provider.dart';

class CheckoutScreen extends ConsumerWidget {
  const CheckoutScreen({super.key, this.productId, this.quantity});

  final String? productId;
  final int? quantity;

  bool get isBuyNow => productId != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final directProduct =
        productId == null ? null : ref.watch(productDetailProvider(productId!));
    final cart = ref.watch(cartProvider);

    return Scaffold(
      appBar: AppBar(
          leading: const AppBackButton(fallback: '/home'),
          title: const Text('Checkout')),
      bottomNavigationBar: _CheckoutFooter(
        total: isBuyNow
            ? (directProduct?.valueOrNull?.price ?? 0) * (quantity ?? 1)
            : (cart.valueOrNull?.total ?? 0),
        onPlaceOrder: () => _placeOrder(context, ref),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _Section(
            child: ListTile(
              leading: const Icon(Icons.location_on, color: AppTheme.primary),
              title: Text(user?.fullName ?? 'Customer'),
              subtitle: Text(user?.address?.isNotEmpty == true
                  ? user!.address!
                  : 'Add your delivery address in Profile.'),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
          const SizedBox(height: 10),
          if (isBuyNow)
            directProduct!.when(
              loading: () => const Center(
                  child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator())),
              error: (e, _) => AppErrorState(
                  message: friendlyError(e),
                  onRetry: () =>
                      ref.invalidate(productDetailProvider(productId!))),
              data: (product) => _ProductSection(
                  items: [_CheckoutItem.fromProduct(product, quantity ?? 1)]),
            )
          else
            cart.when(
              loading: () => const Center(
                  child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator())),
              error: (e, _) => AppErrorState(
                  message: friendlyError(e),
                  onRetry: () => ref.invalidate(cartProvider)),
              data: (value) => _ProductSection(
                  items: value.items.map(_CheckoutItem.fromCart).toList()),
            ),
          const SizedBox(height: 10),
          const _Section(
            child: Column(
              children: [
                ListTile(
                    leading: Icon(Icons.local_shipping_outlined),
                    title: Text('Standard Delivery'),
                    subtitle: Text('Domestic shipping'),
                    trailing: Text('Free')),
                Divider(height: 1),
                ListTile(
                    leading: Icon(Icons.payments_outlined),
                    title: Text('Payment'),
                    subtitle: Text('Cashless demo payment'),
                    trailing:
                        Icon(Icons.check_circle, color: AppTheme.primary)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _Summary(
              total: isBuyNow
                  ? (directProduct?.valueOrNull?.price ?? 0) * (quantity ?? 1)
                  : (cart.valueOrNull?.total ?? 0)),
        ],
      ),
    );
  }

  Future<void> _placeOrder(BuildContext context, WidgetRef ref) async {
    final user = ref.read(authProvider).user;
    if (user?.address?.isNotEmpty != true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Please add your delivery address in Profile before checkout.')));
      return;
    }
    if (isBuyNow) {
      await ref.read(cartRepositoryProvider).buyNow(productId!, quantity ?? 1);
    } else {
      await ref.read(cartRepositoryProvider).checkout();
      ref.invalidate(cartProvider);
    }
    await refreshSeller(ref);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order placed successfully!')));
      goBack(context, fallback: '/home');
    }
  }
}

class _CheckoutItem {
  const _CheckoutItem(
      {required this.name,
      required this.image,
      required this.price,
      required this.quantity,
      required this.sellerName});

  final String name;
  final String image;
  final double price;
  final int quantity;
  final String sellerName;

  factory _CheckoutItem.fromCart(CartItemModel item) {
    return _CheckoutItem(
        name: item.name,
        image: item.image,
        price: item.price,
        quantity: item.quantity,
        sellerName: 'Seller');
  }

  factory _CheckoutItem.fromProduct(ProductModel product, int quantity) {
    return _CheckoutItem(
        name: product.name,
        image: product.mainImage,
        price: product.price,
        quantity: quantity,
        sellerName: product.sellerName);
  }
}

class _ProductSection extends StatelessWidget {
  const _ProductSection({required this.items});

  final List<_CheckoutItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const AppEmptyState(
          icon: Icons.shopping_bag_outlined,
          title: 'Nothing to checkout',
          message: 'Add a product before placing an order.');
    }
    return _Section(
      child: Column(
        children: [
          for (final item in items)
            ListTile(
              leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AppProductImage(
                      image: item.image, width: 64, height: 64)),
              title:
                  Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text(item.sellerName),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                      NumberFormat.currency(locale: 'th_TH', symbol: '\u0E3F')
                          .format(item.price),
                      overflow: TextOverflow.ellipsis),
                  Text('x${item.quantity}'),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.total});

  final double total;

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(locale: 'th_TH', symbol: '\u0E3F');
    return _Section(
      child: Column(
        children: [
          ListTile(
              title: const Text('Subtotal'),
              trailing: Text(money.format(total))),
          const ListTile(title: Text('Shipping'), trailing: Text('Free')),
          const Divider(height: 1),
          ListTile(
              title: const Text('Total'),
              trailing: Text(money.format(total),
                  style: const TextStyle(
                      color: AppTheme.primary, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
}

class _CheckoutFooter extends StatelessWidget {
  const _CheckoutFooter({required this.total, required this.onPlaceOrder});

  final double total;
  final VoidCallback onPlaceOrder;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: const [
              BoxShadow(color: Color(0x22000000), blurRadius: 10)
            ]),
        child: Row(
          children: [
            Expanded(
                child: Text(
                    'Total ${NumberFormat.currency(locale: 'th_TH', symbol: '\u0E3F').format(total)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold))),
            const SizedBox(width: 12),
            FilledButton(
                onPressed: total <= 0 ? null : onPlaceOrder,
                child: const Text('Place Order')),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(child: child);
  }
}
