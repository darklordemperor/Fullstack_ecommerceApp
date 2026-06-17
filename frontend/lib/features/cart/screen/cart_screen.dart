import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/widget/app_ui.dart';
import '../../../core/theme/app_theme.dart';
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
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: const Border(top: BorderSide(color: AppTheme.line)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(color: AppTheme.subtext)),
                          Text(
                            NumberFormat.currency(
                                    locale: 'th_TH', symbol: '\u0E3F')
                                .format(cart.value!.total),
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ],
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
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
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: AppProductImage(
                              image: item.image, width: 82, height: 82),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(height: 6),
                              Text(
                                  NumberFormat.currency(
                                          locale: 'th_TH', symbol: '\u0E3F')
                                      .format(item.price),
                                  style: const TextStyle(
                                      color: AppTheme.primaryDark,
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(height: 8),
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      constraints: const BoxConstraints(
                                          minWidth: 34, minHeight: 34),
                                      iconSize: 18,
                                      icon: const Icon(Icons.remove_rounded),
                                      onPressed: item.quantity > 1
                                          ? () async {
                                              await ref
                                                  .read(cartRepositoryProvider)
                                                  .update(item.productId,
                                                      item.quantity - 1);
                                              ref.invalidate(cartProvider);
                                            }
                                          : null,
                                    ),
                                    Text('${item.quantity}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800)),
                                    IconButton(
                                      constraints: const BoxConstraints(
                                          minWidth: 34, minHeight: 34),
                                      iconSize: 18,
                                      icon: const Icon(Icons.add_rounded),
                                      onPressed: () async {
                                        await ref
                                            .read(cartRepositoryProvider)
                                            .update(item.productId,
                                                item.quantity + 1);
                                        ref.invalidate(cartProvider);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded),
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
