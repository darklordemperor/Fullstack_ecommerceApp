import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/widget/app_ui.dart';
import '../provider/cart_provider.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    return Scaffold(
      appBar:
          AppBar(leading: const AppBackButton(), title: const Text('My Cart')),
      bottomNavigationBar: cart.valueOrNull == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Total: ${NumberFormat.currency(locale: 'th_TH', symbol: '\u0E3F').format(cart.value!.total)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    FilledButton(
                      onPressed: cart.value!.items.isEmpty
                          ? null
                          : () async {
                              context.push('/checkout');
                            },
                      child: const Text('Checkout'),
                    ),
                  ],
                ),
              ),
            ),
      body: cart.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorState(
            message: friendlyError(e),
            onRetry: () => ref.invalidate(cartProvider)),
        data: (value) {
          if (value.items.isEmpty) {
            return const AppEmptyState(
              icon: Icons.shopping_cart_outlined,
              title: 'Your cart is empty',
              message: 'Add products from the home screen when you are ready.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: value.items.length,
            itemBuilder: (_, i) {
              final item = value.items[i];
              return Dismissible(
                key: ValueKey(item.productId),
                onDismissed: (_) async {
                  await ref.read(cartRepositoryProvider).remove(item.productId);
                  ref.invalidate(cartProvider);
                },
                child: Card(
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: AppProductImage(
                          image: item.image, width: 80, height: 80),
                    ),
                    title: Text(item.name),
                    subtitle: Text(
                        '${NumberFormat.currency(locale: 'th_TH', symbol: '\u0E3F').format(item.price)} x ${item.quantity}'),
                    trailing: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: item.quantity > 1
                              ? () async {
                                  await ref.read(cartRepositoryProvider).update(
                                      item.productId, item.quantity - 1);
                                  ref.invalidate(cartProvider);
                                }
                              : null,
                        ),
                        Text('${item.quantity}'),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () async {
                            await ref
                                .read(cartRepositoryProvider)
                                .update(item.productId, item.quantity + 1);
                            ref.invalidate(cartProvider);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            await ref
                                .read(cartRepositoryProvider)
                                .remove(item.productId);
                            ref.invalidate(cartProvider);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
