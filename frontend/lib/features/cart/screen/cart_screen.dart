import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/responsive.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/widget/app_ui.dart';
import '../model/cart_model.dart';
import '../provider/cart_provider.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  final selectedProductIds = <String>{};

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final value = cart.valueOrNull;
    final selectedIds = value == null
        ? selectedProductIds
        : selectedProductIds
            .intersection(value.items.map((item) => item.productId).toSet());
    final selectedTotal = value?.selectedTotal(selectedIds) ?? 0;
    final selectedCount = value?.selectedCount(selectedIds) ?? 0;

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(tr(ref, 'My Cart', 'ตะกร้าของฉัน')),
      ),
      bottomNavigationBar: value == null
          ? null
          : _CartFooter(
              allSelected:
                  value.items.isNotEmpty && selectedCount == value.items.length,
              selectedCount: selectedCount,
              selectedTotal: selectedTotal,
              onSelectAll: (checked) {
                setState(() {
                  selectedProductIds
                    ..clear()
                    ..addAll(checked
                        ? value.items.map((item) => item.productId)
                        : const <String>[]);
                });
              },
              onCheckout: selectedCount == 0
                  ? null
                  : () {
                      final uri = Uri(
                        path: '/checkout',
                        queryParameters: {
                          'cartProductIds': selectedIds.join(','),
                        },
                      );
                      context.push(uri.toString());
                    },
            ),
      body: ResponsiveCenter(
        child: cart.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => AppErrorState(
              message: friendlyError(e),
              onRetry: () => ref.invalidate(cartProvider)),
          data: (value) {
            if (value.items.isEmpty) {
              return AppEmptyState(
                icon: Icons.shopping_cart_outlined,
                title: tr(ref, 'Your cart is empty', 'ตะกร้าของคุณว่าง'),
                message: tr(
                    ref,
                    'Add products from the home screen when you are ready.',
                    'เลือกสินค้าเพิ่มจากหน้าแรกเมื่อพร้อม'),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
              itemCount: value.shopGroups.length,
              itemBuilder: (_, i) {
                final group = value.shopGroups[i];
                return _CartShopSection(
                  group: group,
                  selectedProductIds: selectedIds,
                  onShopSelected: (checked) => setState(() {
                    if (checked) {
                      selectedProductIds.addAll(group.productIds);
                    } else {
                      selectedProductIds.removeAll(group.productIds);
                    }
                  }),
                  onItemSelected: (item, checked) => setState(() {
                    if (checked) {
                      selectedProductIds.add(item.productId);
                    } else {
                      selectedProductIds.remove(item.productId);
                    }
                  }),
                  onDecrease: (item) =>
                      _updateQuantity(item, item.quantity - 1),
                  onIncrease: (item) =>
                      _updateQuantity(item, item.quantity + 1),
                  onRemove: (item) => _removeItem(item),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _updateQuantity(CartItemModel item, int quantity) async {
    try {
      await ref
          .read(cartProvider.notifier)
          .updateQuantity(item.productId, quantity);
    } on DioException catch (error) {
      _showActionError(error);
    }
  }

  Future<void> _removeItem(CartItemModel item) async {
    selectedProductIds.remove(item.productId);
    try {
      await ref.read(cartProvider.notifier).remove(item.productId);
    } on DioException catch (error) {
      _showActionError(error);
    }
  }

  void _showActionError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(friendlyError(error))));
  }
}

class _CartShopSection extends ConsumerWidget {
  const _CartShopSection({
    required this.group,
    required this.selectedProductIds,
    required this.onShopSelected,
    required this.onItemSelected,
    required this.onDecrease,
    required this.onIncrease,
    required this.onRemove,
  });

  final CartShopGroup group;
  final Set<String> selectedProductIds;
  final ValueChanged<bool> onShopSelected;
  final void Function(CartItemModel item, bool checked) onItemSelected;
  final ValueChanged<CartItemModel> onDecrease;
  final ValueChanged<CartItemModel> onIncrease;
  final ValueChanged<CartItemModel> onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedInShop = group.items
        .where((item) => selectedProductIds.contains(item.productId));
    final shopSelected =
        group.items.isNotEmpty && selectedInShop.length == group.items.length;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 8, 12, 6),
            child: Row(
              children: [
                Checkbox(
                  value: shopSelected,
                  onChanged: (value) => onShopSelected(value ?? false),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    'Mall',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    group.sellerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
          const Divider(height: 1),
          for (final item in group.items)
            Dismissible(
              key: ValueKey(item.productId),
              onDismissed: (_) => onRemove(item),
              child: _CartItemCard(
                item: item,
                selected: selectedProductIds.contains(item.productId),
                onSelected: (checked) => onItemSelected(item, checked),
                onDecrease: item.quantity > 1 ? () => onDecrease(item) : null,
                onIncrease: () => onIncrease(item),
                onRemove: () => onRemove(item),
              ),
            ),
        ],
      ),
    );
  }
}

class _CartItemCard extends ConsumerWidget {
  const _CartItemCard({
    required this.item,
    required this.selected,
    required this.onSelected,
    required this.onDecrease,
    required this.onIncrease,
    required this.onRemove,
  });

  final CartItemModel item;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final VoidCallback? onDecrease;
  final VoidCallback onIncrease;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final money =
        NumberFormat.currency(locale: moneyLocale(ref), symbol: '\u0E3F');
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 12, 10, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: selected,
            onChanged: (value) => onSelected(value ?? false),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: AppProductImage(image: item.image, width: 84, height: 84),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  money.format(item.price),
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 17),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _QuantityButton(
                      icon: Icons.remove_rounded,
                      onPressed: onDecrease,
                    ),
                    Container(
                      width: 38,
                      height: 32,
                      alignment: Alignment.center,
                      color: colors.surfaceContainerHighest,
                      child: Text('${item.quantity}',
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                    _QuantityButton(
                      icon: Icons.add_rounded,
                      onPressed: onIncrease,
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: tr(ref, 'Remove', 'ลบ'),
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: onRemove,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 32,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 18,
        icon: Icon(icon),
        onPressed: onPressed,
      ),
    );
  }
}

class _CartFooter extends ConsumerWidget {
  const _CartFooter({
    required this.allSelected,
    required this.selectedCount,
    required this.selectedTotal,
    required this.onSelectAll,
    required this.onCheckout,
  });

  final bool allSelected;
  final int selectedCount;
  final double selectedTotal;
  final ValueChanged<bool> onSelectAll;
  final VoidCallback? onCheckout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final money =
        NumberFormat.currency(locale: moneyLocale(ref), symbol: '\u0E3F');
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 14, 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
              top: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant)),
          boxShadow: const [
            BoxShadow(color: Color(0x12000000), blurRadius: 12)
          ],
        ),
        child: Row(
          children: [
            Checkbox(
              value: allSelected,
              onChanged: (value) => onSelectAll(value ?? false),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5)),
            ),
            Text(tr(ref, 'All', 'ทั้งหมด'),
                style: const TextStyle(fontWeight: FontWeight.w800)),
            const Spacer(),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(tr(ref, 'Total', 'รวมทั้งหมด'),
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
                Text(
                  money.format(selectedTotal),
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: onCheckout,
              child:
                  Text('${tr(ref, 'Checkout', 'ชำระเงิน')} ($selectedCount)'),
            ),
          ],
        ),
      ),
    );
  }
}
