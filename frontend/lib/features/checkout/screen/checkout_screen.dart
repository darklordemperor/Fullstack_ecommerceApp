import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/settings/app_settings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widget/app_ui.dart';
import '../../auth/provider/auth_provider.dart';
import '../../cart/model/cart_model.dart';
import '../../cart/provider/cart_provider.dart';
import '../../product/model/product_model.dart';
import '../../product/provider/product_provider.dart';
import '../../seller/provider/seller_provider.dart';

class CheckoutScreen extends ConsumerWidget {
  const CheckoutScreen(
      {super.key,
      this.productId,
      this.quantity,
      this.selectedProductIds = const []});

  final String? productId;
  final int? quantity;
  final List<String> selectedProductIds;

  bool get isBuyNow => productId != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final directProduct =
        productId == null ? null : ref.watch(productDetailProvider(productId!));
    final cart = ref.watch(cartProvider);
    final selectedIds = selectedProductIds.toSet();
    final selectedCartItems = cart.valueOrNull == null
        ? const <CartItemModel>[]
        : selectedIds.isEmpty
            ? cart.valueOrNull!.items
            : cart.valueOrNull!.selectedItems(selectedIds);
    final cartTotal =
        selectedCartItems.fold<double>(0, (sum, item) => sum + item.subtotal);

    return Scaffold(
      appBar: AppBar(
          leading: const AppBackButton(fallback: '/home'),
          title: Text(tr(ref, 'Checkout', 'ชำระเงิน'))),
      bottomNavigationBar: _CheckoutFooter(
        total: isBuyNow
            ? (directProduct?.valueOrNull?.price ?? 0) * (quantity ?? 1)
            : cartTotal,
        onPlaceOrder: () => _placeOrder(context, ref),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _Section(
            child: ListTile(
              leading: const Icon(Icons.location_on, color: AppTheme.primary),
              title: Text(user?.fullName ?? tr(ref, 'Customer', 'ลูกค้า')),
              subtitle: Text(user?.address?.isNotEmpty == true
                  ? user!.address!
                  : tr(ref, 'Add your delivery address in Profile.',
                      'เพิ่มที่อยู่จัดส่งในหน้าโปรไฟล์')),
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
                  items: (selectedIds.isEmpty
                          ? value.items
                          : value.selectedItems(selectedIds))
                      .map(_CheckoutItem.fromCart)
                      .toList()),
            ),
          const SizedBox(height: 10),
          _Section(
            child: Column(
              children: [
                ListTile(
                    leading: const Icon(Icons.local_shipping_outlined),
                    title: Text(tr(ref, 'Standard Delivery', 'จัดส่งมาตรฐาน')),
                    subtitle:
                        Text(tr(ref, 'Domestic shipping', 'จัดส่งภายในประเทศ')),
                    trailing: Text(tr(ref, 'Free', 'ฟรี'))),
                const Divider(height: 1),
                ListTile(
                    leading: const Icon(Icons.payments_outlined),
                    title: Text(tr(ref, 'Payment', 'การชำระเงิน')),
                    subtitle: Text(tr(ref, 'Cashless demo payment',
                        'การชำระเงินตัวอย่างแบบไม่ใช้เงินสด')),
                    trailing: const Icon(Icons.check_circle,
                        color: AppTheme.primary)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _Summary(
              total: isBuyNow
                  ? (directProduct?.valueOrNull?.price ?? 0) * (quantity ?? 1)
                  : cartTotal),
        ],
      ),
    );
  }

  Future<void> _placeOrder(BuildContext context, WidgetRef ref) async {
    final user = ref.read(authProvider).user;
    if (user?.address?.isNotEmpty != true) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr(
              ref,
              'Please add your delivery address in Profile before checkout.',
              'กรุณาเพิ่มที่อยู่จัดส่งในโปรไฟล์ก่อนชำระเงิน'))));
      return;
    }
    if (isBuyNow) {
      await ref.read(cartProvider.notifier).buyNow(productId!, quantity ?? 1);
    } else {
      await ref.read(cartProvider.notifier).checkout(selectedProductIds);
    }
    refreshSeller(ref);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(tr(ref, 'Order placed successfully!', 'สั่งซื้อสำเร็จ'))));
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
        sellerName: '');
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

class _ProductSection extends ConsumerWidget {
  const _ProductSection({required this.items});

  final List<_CheckoutItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return AppEmptyState(
          icon: Icons.shopping_bag_outlined,
          title: tr(ref, 'Nothing to checkout', 'ไม่มีสินค้าให้ชำระเงิน'),
          message: tr(ref, 'Add a product before placing an order.',
              'เพิ่มสินค้าก่อนทำรายการสั่งซื้อ'));
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
              subtitle: Text(item.sellerName.isEmpty
                  ? tr(ref, 'Seller', 'ผู้ขาย')
                  : item.sellerName),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                      NumberFormat.currency(
                              locale: moneyLocale(ref), symbol: '\u0E3F')
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

class _Summary extends ConsumerWidget {
  const _Summary({required this.total});

  final double total;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final money =
        NumberFormat.currency(locale: moneyLocale(ref), symbol: '\u0E3F');
    return _Section(
      child: Column(
        children: [
          ListTile(
              title: Text(tr(ref, 'Subtotal', 'ยอดสินค้า')),
              trailing: Text(money.format(total))),
          ListTile(
              title: Text(tr(ref, 'Shipping', 'ค่าจัดส่ง')),
              trailing: Text(tr(ref, 'Free', 'ฟรี'))),
          const Divider(height: 1),
          ListTile(
              title: Text(tr(ref, 'Total', 'รวมทั้งหมด')),
              trailing: Text(money.format(total),
                  style: const TextStyle(
                      color: AppTheme.primary, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
}

class _CheckoutFooter extends ConsumerWidget {
  const _CheckoutFooter({required this.total, required this.onPlaceOrder});

  final double total;
  final VoidCallback onPlaceOrder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                    '${tr(ref, 'Total', 'รวมทั้งหมด')} ${NumberFormat.currency(locale: moneyLocale(ref), symbol: '\u0E3F').format(total)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold))),
            const SizedBox(width: 12),
            FilledButton(
                onPressed: total <= 0 ? null : onPlaceOrder,
                child: Text(tr(ref, 'Place Order', 'สั่งซื้อ'))),
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
